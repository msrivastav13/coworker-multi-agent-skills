/**
 * Single source of truth for renewal risk: one query path and one scoring rubric.
 *
 * The ListUpcomingRenewals and GetAccountRenewalRisk invocable actions are thin wrappers
 * over this class. Agentforce Coworker calls them as tools from the "Renewal Risk Review" skill.
 * The skill's playbook says what to DO for each band; the weights live only here.
 */
public with sharing class RenewalRiskService {
    // Renewals are open opportunities of this Type (the org has no "Renewal" value).
    public static final String RENEWAL_TYPE = 'Existing Business';

    // Scoring rubric, in points. Change weights here only.
    @TestVisible static final Integer PTS_SEATS_UNDER_50 = 35;
    @TestVisible static final Integer PTS_SEATS_UNDER_75 = 20;
    @TestVisible static final Integer PTS_PER_HIGH_CASE = 10;
    @TestVisible static final Integer MAX_HIGH_CASE_PTS = 30;
    @TestVisible static final Integer PTS_ESCALATION = 15;
    @TestVisible static final Integer PTS_QBR_OVERDUE = 15;
    @TestVisible static final Integer QBR_OVERDUE_DAYS = 120;
    @TestVisible static final Integer PTS_RENEWAL_IMMINENT = 10;
    @TestVisible static final Integer IMMINENT_DAYS = 30;
    @TestVisible static final Integer HIGH_BAND = 50;
    @TestVisible static final Integer MEDIUM_BAND = 25;

    public class RenewalRiskException extends Exception {}

    public class RiskFactor {
        public String factor;
        public Integer points;
        RiskFactor(String factor, Integer points) {
            this.factor = factor;
            this.points = points;
        }
    }

    public class AccountRisk implements Comparable {
        public Id accountId;
        public String accountName;
        public Id renewalOpportunityId;
        public String renewalName;
        public String renewalStage;
        public Decimal renewalAmount;
        public Date renewalCloseDate;
        public Integer daysToRenewal;
        public Decimal seatUtilizationPct;
        public Integer openHighPriorityCases = 0;
        public Integer escalatedCases = 0;
        public Integer daysSinceLastQbr;
        public Integer score = 0;
        public String band;
        public List<RiskFactor> factors = new List<RiskFactor>();

        // Highest score first; ties go to the renewal that closes sooner.
        public Integer compareTo(Object other) {
            AccountRisk that = (AccountRisk) other;
            if (score != that.score) {
                return score > that.score ? -1 : 1;
            }
            Integer mine = daysToRenewal == null ? 9999 : daysToRenewal;
            Integer theirs = that.daysToRenewal == null ? 9999 : that.daysToRenewal;
            return mine == theirs ? 0 : (mine < theirs ? -1 : 1);
        }

        void add(String factor, Integer points) {
            factors.add(new RiskFactor(factor, points));
            score += points;
        }
    }

    /** Open renewals closing in the next daysAhead days, riskiest first. */
    public static List<AccountRisk> upcomingRenewals(Integer daysAhead) {
        if (daysAhead == null || daysAhead < 1 || daysAhead > 365) {
            throw new RenewalRiskException('daysAhead must be between 1 and 365.');
        }
        Date horizon = Date.today().addDays(daysAhead);
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity o : [
            SELECT AccountId FROM Opportunity
            WHERE Type = :RENEWAL_TYPE AND IsClosed = FALSE AND AccountId != NULL
              AND CloseDate >= TODAY AND CloseDate <= :horizon
        ]) {
            accountIds.add(o.AccountId);
        }
        List<AccountRisk> risks = assess(accountIds);
        risks.sort();
        return risks;
    }

    /** Risk for one account, found by Id or by name. Ambiguous or unknown names throw. */
    public static AccountRisk forAccount(String accountNameOrId) {
        return assess(new Set<Id>{ AccountResolver.resolve(accountNameOrId) })[0];
    }

    // The one query behind every tool.
    static List<AccountRisk> assess(Set<Id> accountIds) {
        List<AccountRisk> results = new List<AccountRisk>();
        if (accountIds.isEmpty()) {
            return results;
        }
        for (Account a : [
            SELECT Id, Name, Licensed_Seats__c, Active_Users_30d__c, Last_QBR_Date__c,
                (SELECT Id, Name, StageName, Amount, CloseDate FROM Opportunities
                 WHERE Type = :RENEWAL_TYPE AND IsClosed = FALSE ORDER BY CloseDate ASC LIMIT 1),
                (SELECT Id, Priority, Status, IsEscalated FROM Cases WHERE IsClosed = FALSE)
            FROM Account WHERE Id IN :accountIds
        ]) {
            results.add(score(a));
        }
        return results;
    }

    @TestVisible
    static AccountRisk score(Account a) {
        AccountRisk r = new AccountRisk();
        r.accountId = a.Id;
        r.accountName = a.Name;

        if (a.Opportunities.isEmpty()) {
            r.add('No open renewal opportunity', 0);
        } else {
            Opportunity renewal = a.Opportunities[0];
            r.renewalOpportunityId = renewal.Id;
            r.renewalName = renewal.Name;
            r.renewalStage = renewal.StageName;
            r.renewalAmount = renewal.Amount;
            r.renewalCloseDate = renewal.CloseDate;
            r.daysToRenewal = Date.today().daysBetween(renewal.CloseDate);
            if (r.daysToRenewal <= IMMINENT_DAYS && renewal.StageName != 'Negotiation') {
                r.add('Renews in ' + r.daysToRenewal + ' days and is not in Negotiation', PTS_RENEWAL_IMMINENT);
            }
        }

        if (a.Licensed_Seats__c == null || a.Licensed_Seats__c == 0 || a.Active_Users_30d__c == null) {
            r.add('Seat usage data missing', 0);
        } else {
            r.seatUtilizationPct = (100 * a.Active_Users_30d__c / a.Licensed_Seats__c).setScale(0);
            if (r.seatUtilizationPct < 50) {
                r.add('Seat utilization ' + r.seatUtilizationPct + '% (under 50%)', PTS_SEATS_UNDER_50);
            } else if (r.seatUtilizationPct < 75) {
                r.add('Seat utilization ' + r.seatUtilizationPct + '% (under 75%)', PTS_SEATS_UNDER_75);
            }
        }

        for (Case c : a.Cases) {
            if (c.Priority == 'High') {
                r.openHighPriorityCases++;
            }
            if (c.IsEscalated || c.Status == 'Escalated') {
                r.escalatedCases++;
            }
        }
        if (r.openHighPriorityCases > 0) {
            r.add(
                r.openHighPriorityCases + ' open high-priority case(s)',
                Math.min(r.openHighPriorityCases * PTS_PER_HIGH_CASE, MAX_HIGH_CASE_PTS)
            );
        }
        if (r.escalatedCases > 0) {
            r.add(r.escalatedCases + ' escalated case(s)', PTS_ESCALATION);
        }

        if (a.Last_QBR_Date__c == null) {
            r.add('No QBR on record', PTS_QBR_OVERDUE);
        } else {
            r.daysSinceLastQbr = a.Last_QBR_Date__c.daysBetween(Date.today());
            if (r.daysSinceLastQbr > QBR_OVERDUE_DAYS) {
                r.add('Last QBR ' + r.daysSinceLastQbr + ' days ago', PTS_QBR_OVERDUE);
            }
        }

        r.band = r.score >= HIGH_BAND ? 'High' : (r.score >= MEDIUM_BAND ? 'Medium' : 'Low');
        return r;
    }
}
