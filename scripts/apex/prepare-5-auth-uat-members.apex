List<String> emails = new List<String>{
    'uat-member-01@example.com',
    'uat-member-02@example.com',
    'uat-member-03@example.com',
    'uat-member-04@example.com',
    'uat-member-05@example.com'
};
// Supply a one-time password only in the anonymous Apex execution context.
// Never commit a real UAT password to source control.
String password = 'REPLACE_WITH_ONE_TIME_UAT_PASSWORD';
if (password == 'REPLACE_WITH_ONE_TIME_UAT_PASSWORD') {
    throw new IllegalArgumentException('Set a one-time UAT password in the execution window; do not commit it to this file.');
}
List<Member__c> members = [SELECT Id, Email__c FROM Member__c WHERE Email__c IN :emails];
for (Member__c member : members) {
    String activationToken = LibraryMemberAuthController.issueActivation(member);
    LibraryMemberAuthController.activateAccount(activationToken, password, password);
    System.debug('UAT_AUTH_READY|' + member.Email__c + '|USER_CREATED=0');
}
System.debug('UAT_AUTH_READY_COUNT|' + members.size());
