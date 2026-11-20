@IsTest
private class GetAccountEscalationsTest {
    @IsTest
    static void listsEscalationsAndCountsMissingOwners() {
        Account a = new Account(Name = 'Escalation Test Co');
        insert a;
        insert new List<Case>{
            new Case(AccountId = a.Id, Subject = 'Outage', Priority = 'High', Status = 'Escalated'),
            new Case(AccountId = a.Id, Subject = 'Owned', Priority = 'High', Status = 'New', IsEscalated = true,
                Executive_Owner__c = UserInfo.getUserId(), Target_Resolution_Date__c = Date.today().addDays(3)),
            new Case(AccountId = a.Id, Subject = 'Question', Priority = 'Low', Status = 'New')
        };
        GetAccountEscalations.Request req = new GetAccountEscalations.Request();
        req.accountNameOrId = 'Escalation Test Co';

        GetAccountEscalations.Result res = GetAccountEscalations.run(new List<GetAccountEscalations.Request>{ req })[0];

        Assert.areEqual(2, res.summary.split('\n').size(), res.summary);
        Assert.areEqual(1, res.missingOwnerOrDate);
        Assert.isFalse(res.summary.contains('Question'));
    }

    @IsTest
    static void reportsNoEscalations() {
        insert new Account(Name = 'Calm Test Co');
        GetAccountEscalations.Request req = new GetAccountEscalations.Request();
        req.accountNameOrId = 'Calm Test Co';

        GetAccountEscalations.Result res = GetAccountEscalations.run(new List<GetAccountEscalations.Request>{ req })[0];

        Assert.areEqual('No open escalated or high-priority cases.', res.summary);
        Assert.areEqual(0, res.missingOwnerOrDate);
    }
}
