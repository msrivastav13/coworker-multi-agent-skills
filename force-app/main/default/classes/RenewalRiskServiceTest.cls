@IsTest
private class RenewalRiskServiceTest {
    @TestSetup
    static void setup() {
        Account risky = new Account(
            Name = 'Risky Test Co', Licensed_Seats__c = 100, Active_Users_30d__c = 40,
            Last_QBR_Date__c = Date.today().addDays(-200)
        );
        Account healthy = new Account(
            Name = 'Healthy Test Co', Licensed_Seats__c = 100, Active_Users_30d__c = 95,
            Last_QBR_Date__c = Date.today().addDays(-30)
        );
        Account twin = new Account(Name = 'Healthy Test Co East');
        insert new List<Account>{ risky, healthy, twin };

        insert new List<Opportunity>{
            new Opportunity(Name = 'Risky renewal', AccountId = risky.Id, Type = RenewalRiskService.RENEWAL_TYPE,
                StageName = 'Discovery', CloseDate = Date.today().addDays(20), Amount = 100000),
            new Opportunity(Name = 'Healthy renewal', AccountId = healthy.Id, Type = RenewalRiskService.RENEWAL_TYPE,
                StageName = 'Negotiation', CloseDate = Date.today().addDays(60), Amount = 50000)
        };
        insert new List<Case>{
            new Case(AccountId = risky.Id, Subject = 'Outage', Priority = 'High', Status = 'New'),
            new Case(AccountId = risky.Id, Subject = 'Data loss', Priority = 'High', Status = 'Escalated')
        };
    }

    @IsTest
    static void scoresRiskyAccountHigh() {
        RenewalRiskService.AccountRisk r = RenewalRiskService.forAccount('Risky Test Co');
        Integer expected = RenewalRiskService.PTS_RENEWAL_IMMINENT + RenewalRiskService.PTS_SEATS_UNDER_50 +
            2 * RenewalRiskService.PTS_PER_HIGH_CASE + RenewalRiskService.PTS_ESCALATION + RenewalRiskService.PTS_QBR_OVERDUE;
        Assert.areEqual(expected, r.score);
        Assert.areEqual('High', r.band);
        Assert.areEqual(40, r.seatUtilizationPct.intValue());
        Assert.areEqual(2, r.openHighPriorityCases);
        Assert.areEqual(1, r.escalatedCases);
        Assert.areEqual(5, r.factors.size());
    }

    @IsTest
    static void exactNameWinsOverPartialMatches() {
        RenewalRiskService.AccountRisk r = RenewalRiskService.forAccount('healthy test co');
        Assert.areEqual('Healthy Test Co', r.accountName);
        Assert.areEqual('Low', r.band);
        Assert.areEqual(0, r.score);
    }

    @IsTest
    static void ambiguousNameThrows() {
        try {
            RenewalRiskService.forAccount('Test Co');
            Assert.fail('Expected an ambiguity error');
        } catch (AccountResolver.AccountResolverException e) {
            Assert.isTrue(e.getMessage().contains('More than one account'), e.getMessage());
        }
    }

    @IsTest
    static void unknownNameThrows() {
        try {
            RenewalRiskService.forAccount('Nobody Inc');
            Assert.fail('Expected a not-found error');
        } catch (AccountResolver.AccountResolverException e) {
            Assert.isTrue(e.getMessage().contains('No account matches'), e.getMessage());
        }
    }

    @IsTest
    static void resolvesById() {
        Id twinId = [SELECT Id FROM Account WHERE Name = 'Healthy Test Co East'].Id;
        RenewalRiskService.AccountRisk r = RenewalRiskService.forAccount(twinId);
        Assert.areEqual('Seat usage data missing', r.factors[1].factor);
        Assert.areEqual('No open renewal opportunity', r.factors[0].factor);
    }

    @IsTest
    static void listActionRanksRiskiestFirst() {
        ListUpcomingRenewals.Request req = new ListUpcomingRenewals.Request();
        req.daysAhead = 90;
        ListUpcomingRenewals.Result res = ListUpcomingRenewals.run(new List<ListUpcomingRenewals.Request>{ req })[0];
        List<String> lines = res.summary.split('\n');
        Assert.areEqual(2, lines.size());
        Assert.isTrue(lines[0].startsWith('Risky Test Co | High'), lines[0]);
    }

    @IsTest
    static void listActionRejectsBadHorizon() {
        try {
            RenewalRiskService.upcomingRenewals(0);
            Assert.fail('Expected a range error');
        } catch (RenewalRiskService.RenewalRiskException e) {
            Assert.isTrue(e.getMessage().contains('between 1 and 365'));
        }
    }

    @IsTest
    static void getActionReturnsBandAndOpportunity() {
        GetAccountRenewalRisk.Request req = new GetAccountRenewalRisk.Request();
        req.accountNameOrId = 'Risky Test Co';
        GetAccountRenewalRisk.Result res = GetAccountRenewalRisk.run(new List<GetAccountRenewalRisk.Request>{ req })[0];
        Assert.areEqual('High', res.band);
        Assert.isNotNull(res.renewalOpportunityId);
        Assert.isTrue(res.riskJson.contains('"factors"'));
    }
}
