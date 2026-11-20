// Removes everything scripts/seed.apex created (Accounts with AccountNumber 'CSD-*' and their children).
List<Account> accounts = [SELECT Id FROM Account WHERE AccountNumber LIKE 'CSD-%'];
Set<Id> ids = new Map<Id, Account>(accounts).keySet();
List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId IN :ids];
delete [SELECT Id FROM Task WHERE WhatId IN :opps OR WhatId IN :ids];
delete [SELECT Id FROM Case WHERE AccountId IN :ids];
delete opps;
delete [SELECT Id FROM Contact WHERE AccountId IN :ids];
delete accounts;
System.debug('Removed ' + accounts.size() + ' demo accounts.');
