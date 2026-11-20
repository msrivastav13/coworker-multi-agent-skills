// Seed data for the Agentforce Coworker "Renewal Risk Review" skill demo.
// Dates are relative to today, so re-seed on recording day: run cleanup.apex, then this.
// Every seeded Account has AccountNumber 'CSD-*'; cleanup.apex keys off that marker.
if (![SELECT Id FROM Account WHERE AccountNumber LIKE 'CSD-%' LIMIT 1].isEmpty()) {
    throw new IllegalArgumentException('Demo data already exists. Run scripts/cleanup.apex first.');
}
Date t = Date.today();
// name, seats, active users, QBR days ago (-1 = never), renewal days out, stage, amount, sponsor first/last/title
List<List<Object>> rows = new List<List<Object>>{
    new List<Object>{ 'Harborview Bank',        400, 150, 210, 21,  'Discovery',      240000, 'Elena',  'Marsh',   'VP Digital Banking' },
    new List<Object>{ 'Cedar & Pine Insurance', 200,  90,  -1, 14,  'Proposal/Quote',  95000, 'Raj',    'Iyer',    'Director of Claims Ops' },
    new List<Object>{ 'Orbital Freight',        250, 160, 140, 45,  'Proposal/Quote', 180000, 'Maya',   'Chen',    'COO' },
    new List<Object>{ 'Bluepeak Health',        600, 270,  60, 75,  'Negotiation',    410000, 'Tom',    'Okafor',  'CIO' },
    new List<Object>{ 'Quillstone Media',       120, 110,  30, 28,  'Negotiation',     65000, 'Ana',    'Silva',   'Head of Content Ops' },
    new List<Object>{ 'Northwind Logistics',    300, 270,  20, 60,  'Proposal/Quote', 150000, 'Ben',    'Hartley', 'VP Operations' },
    new List<Object>{ 'Lumen Retail Group',     500, 340, 100, 110, 'Discovery',      220000, 'Priya',  'Raman',   'SVP eCommerce' },
    new List<Object>{ 'Verdant Energy Co',      150, 140,  45, 200, 'Discovery',       80000, 'Lucas',  'Moreau',  'Director of IT' }
};
List<Account> accounts = new List<Account>();
Integer n = 1;
for (List<Object> r : rows) {
    Integer qbr = (Integer) r[3];
    accounts.add(new Account(
        Name = (String) r[0], AccountNumber = 'CSD-' + String.valueOf(n++).leftPad(3, '0'),
        Industry = 'Technology', Type = 'Customer - Direct',
        Licensed_Seats__c = (Integer) r[1], Active_Users_30d__c = (Integer) r[2],
        Last_QBR_Date__c = qbr < 0 ? null : t.addDays(-qbr)
    ));
}
insert accounts;

List<Contact> contacts = new List<Contact>();
List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < rows.size(); i++) {
    List<Object> r = rows[i];
    Account a = accounts[i];
    contacts.add(new Contact(AccountId = a.Id, FirstName = (String) r[7], LastName = (String) r[8], Title = (String) r[9],
        Email = ((String) r[7]).toLowerCase() + '.' + ((String) r[8]).toLowerCase() + '@example.com'));
    opps.add(new Opportunity(AccountId = a.Id, Name = a.Name + ' - FY27 Renewal', Type = 'Existing Business',
        StageName = (String) r[5], CloseDate = t.addDays((Integer) r[4]), Amount = (Integer) r[6]));
}
insert contacts;
insert opps;

Map<String, Id> acct = new Map<String, Id>();
for (Account a : accounts) acct.put(a.Name, a.Id);
insert new List<Case>{
    new Case(AccountId = acct.get('Harborview Bank'), Subject = 'Mobile check deposit failing for business accounts', Priority = 'High', Status = 'Escalated', Origin = 'Phone'),
    new Case(AccountId = acct.get('Harborview Bank'), Subject = 'SSO login loop after IdP certificate rotation', Priority = 'High', Status = 'New', Origin = 'Email'),
    new Case(AccountId = acct.get('Harborview Bank'), Subject = 'Request: quarterly usage export', Priority = 'Low', Status = 'Closed', Origin = 'Web'),
    new Case(AccountId = acct.get('Cedar & Pine Insurance'), Subject = 'Claims sync job timing out nightly', Priority = 'High', Status = 'On Hold', Origin = 'Email', IsEscalated = true),
    new Case(AccountId = acct.get('Orbital Freight'), Subject = 'Shipment tracking webhook drops events', Priority = 'High', Status = 'New', Origin = 'Web'),
    new Case(AccountId = acct.get('Bluepeak Health'), Subject = 'Add 40 seats for new clinic rollout', Priority = 'Medium', Status = 'New', Origin = 'Email'),
    new Case(AccountId = acct.get('Northwind Logistics'), Subject = 'Dashboard filter question', Priority = 'Low', Status = 'New', Origin = 'Web')
};
System.debug('Seeded ' + accounts.size() + ' accounts, ' + opps.size() + ' renewals, 7 cases.');
