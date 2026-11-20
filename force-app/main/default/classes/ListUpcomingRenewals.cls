/**
 * Coworker tool: list open renewals closing soon, riskiest first.
 * Thin wrapper over RenewalRiskService.
 */
public with sharing class ListUpcomingRenewals {
    public class Request {
        @InvocableVariable(
            label='Days Ahead'
            description='How many days ahead to look for renewals, from 1 to 365. Use 90 if the user does not say.'
            required=true
        )
        public Integer daysAhead;
    }

    public class Result {
        @InvocableVariable(label='Summary' description='One line per renewal: account, risk band, score, days to renewal, amount.')
        public String summary;

        @InvocableVariable(label='Renewals JSON' description='Full risk detail per account, including the factors behind each score.')
        public String renewalsJson;
    }

    @InvocableMethod(
        label='List Upcoming Renewals'
        description='Lists open renewal opportunities closing in the next N days, ranked by renewal risk score.'
        category='Renewal Risk'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        // Coworker sends one request per call.
        for (Request req : requests) {
            List<RenewalRiskService.AccountRisk> risks = RenewalRiskService.upcomingRenewals(req.daysAhead);
            List<String> lines = new List<String>();
            for (RenewalRiskService.AccountRisk r : risks) {
                lines.add(
                    r.accountName + ' | ' + r.band + ' (' + r.score + ') | renews in ' + r.daysToRenewal +
                    ' days | ' + (r.renewalAmount == null ? 'no amount' : r.renewalAmount.format())
                );
            }
            Result res = new Result();
            res.summary = lines.isEmpty()
                ? 'No open renewals close in the next ' + req.daysAhead + ' days.'
                : String.join(lines, '\n');
            res.renewalsJson = JSON.serialize(risks);
            results.add(res);
        }
        return results;
    }
}