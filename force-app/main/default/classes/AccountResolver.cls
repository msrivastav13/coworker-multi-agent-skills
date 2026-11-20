/**
 * Resolves "the account the user means" for every agent action, so name matching behaves the
 * same in Renewal Desk and Escalation Desk. Ambiguous or unknown names throw; they never guess.
 */
public with sharing class AccountResolver {
    public class AccountResolverException extends Exception {}

    public static Id resolve(String accountNameOrId) {
        if (String.isBlank(accountNameOrId)) {
            throw new AccountResolverException('Provide an account name or Id.');
        }
        String value = accountNameOrId.trim();
        if (value instanceof Id && ((Id) value).getSObjectType() == Account.SObjectType) {
            return (Id) value;
        }
        String pattern = '%' + value + '%';
        List<Account> matches = [SELECT Id, Name FROM Account WHERE Name LIKE :pattern ORDER BY Name LIMIT 6];
        if (matches.isEmpty()) {
            throw new AccountResolverException('No account matches "' + value + '".');
        }
        List<String> names = new List<String>();
        for (Account a : matches) {
            if (a.Name.equalsIgnoreCase(value)) {
                return a.Id;
            }
            names.add(a.Name);
        }
        if (matches.size() > 1) {
            throw new AccountResolverException(
                'More than one account matches "' + value + '": ' + String.join(names, ', ') + '. Ask the user which one.'
            );
        }
        return matches[0].Id;
    }
}
