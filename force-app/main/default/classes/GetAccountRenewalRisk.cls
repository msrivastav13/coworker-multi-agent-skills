/**
 * Coworker tool: renewal risk score and the factors behind it for one account.
 * Thin wrapper over RenewalRiskService.
 */
public with sharing class GetAccountRenewalRisk {
    public class Request {
        @InvocableVariable(
            label='Account Name or Id'
            description='The account name as the user said it, or its Salesforce Id.'
            required=true
        )
        public String accountNameOrId;
    }

    public class Result {
        @InvocableVariable(label='Risk Band' description='High, Medium, or Low.')
        public String band;

        @InvocableVariable(label='Risk Score' description='Total points; 50 or more is High, 25 to 49 is Medium.')
        public Integer score;

        @InvocableVariable(label='Renewal Opportunity Id' description='Id of the open renewal opportunity, or empty if there is none.')
        public String renewalOpportunityId;

        @InvocableVariable(label='Risk JSON' description='Full detail: renewal, seat utilization, cases, QBR, and each scoring factor with its points.')
        public String riskJson;
    }

    @InvocableMethod(
        label='Get Account Renewal Risk'
        description='Scores renewal risk for one account and explains the factors (seat utilization, high-priority and escalated cases, QBR recency, renewal timing).'
        category='Renewal Risk'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        // Coworker sends one request per call.
        for (Request req : requests) {
            RenewalRiskService.AccountRisk r = RenewalRiskService.forAccount(req.accountNameOrId);
            Result res = new Result();
            res.band = r.band;
            res.score = r.score;
            res.renewalOpportunityId = r.renewalOpportunityId;
            res.riskJson = JSON.serialize(r);
            results.add(res);
        }
        return results;
    }
}