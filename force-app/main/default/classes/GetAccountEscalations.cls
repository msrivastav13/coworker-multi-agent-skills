/**
 * Escalation Desk tool: open escalated and high-priority cases for one account,
 * with the fields the Escalation Management Standard requires before a sponsor call.
 */
public with sharing class GetAccountEscalations {
    public class Request {
        @InvocableVariable(
            label='Account Name or Id'
            description='The account name exactly as the user said it, or its Salesforce Id.'
            required=true
        )
        public String accountNameOrId;
    }

    public class Result {
        @InvocableVariable(label='Summary' description='One line per case: number, subject, priority, status, days open, executive owner, target date.')
        public String summary;

        @InvocableVariable(label='Missing Owner or Date' description='How many escalated cases have no executive owner or no target resolution date.')
        public Integer missingOwnerOrDate;

        @InvocableVariable(label='Cases JSON' description='Full detail per case, including caseId for Assign Escalation Owner.')
        public String casesJson;
    }

    public class EscalatedCase {
        public Id caseId;
        public String caseNumber;
        public String subject;
        public String priority;
        public String status;
        public Boolean escalated;
        public Integer daysOpen;
        public String executiveOwner;
        public Date targetResolutionDate;
    }

    @InvocableMethod(
        label='Get Account Escalations'
        description='Lists open escalated and high-priority cases for one account with status, age, executive owner, and target resolution date.'
        category='Escalations'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        // Coworker sends one request per call.
        for (Request req : requests) {
            Id accountId = AccountResolver.resolve(req.accountNameOrId);
            Result res = new Result();
            res.missingOwnerOrDate = 0;
            List<EscalatedCase> cases = new List<EscalatedCase>();
            List<String> lines = new List<String>();
            for (Case c : [
                SELECT Id, CaseNumber, Subject, Priority, Status, IsEscalated, CreatedDate,
                    Executive_Owner__r.Name, Target_Resolution_Date__c
                FROM Case
                WHERE AccountId = :accountId AND IsClosed = FALSE
                  AND (Priority = 'High' OR IsEscalated = TRUE OR Status = 'Escalated')
                ORDER BY IsEscalated DESC, CreatedDate ASC
            ]) {
                EscalatedCase e = new EscalatedCase();
                e.caseId = c.Id;
                e.caseNumber = c.CaseNumber;
                e.subject = c.Subject;
                e.priority = c.Priority;
                e.status = c.Status;
                e.escalated = c.IsEscalated || c.Status == 'Escalated';
                e.daysOpen = c.CreatedDate.date().daysBetween(Date.today());
                e.executiveOwner = c.Executive_Owner__r?.Name;
                e.targetResolutionDate = c.Target_Resolution_Date__c;
                if (e.escalated && (e.executiveOwner == null || e.targetResolutionDate == null)) {
                    res.missingOwnerOrDate++;
                }
                cases.add(e);
                lines.add(
                    e.caseNumber + ' | ' + e.subject + ' | ' + e.priority + ' | ' + (e.escalated ? 'Escalated' : e.status) +
                    ' | open ' + e.daysOpen + ' days | exec owner: ' + (e.executiveOwner == null ? 'none' : e.executiveOwner) +
                    ' | target: ' + (e.targetResolutionDate == null ? 'none' : String.valueOf(e.targetResolutionDate))
                );
            }
            res.summary = lines.isEmpty() ? 'No open escalated or high-priority cases.' : String.join(lines, '\n');
            res.casesJson = JSON.serialize(cases);
            results.add(res);
        }
        return results;
    }
}