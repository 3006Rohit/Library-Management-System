List<Member__c> members = [SELECT Email__c,Status__c,Account_Status__c,User__c FROM Member__c WHERE Email__c LIKE 'uat-member-%@example.com' ORDER BY Email__c];
for (Member__c member : members) {
    Boolean loginReady = false;
    try {
        LibraryMemberAuthController.AuthResult result = LibraryMemberAuthController.login(member.Email__c, 'UatMember!2026');
        loginReady = result != null && result.member != null;
        if (loginReady) LibraryMemberAuthController.logout(result.sessionToken);
    } catch (Exception error) {
        loginReady = false;
    }
    System.debug('UAT_STATE|' + member.Email__c + '|ACTIVE=' + (member.Status__c == 'Active' && member.Account_Status__c == 'Active') + '|LOGIN_READY=' + loginReady + '|USER=' + String.valueOf(member.User__c));
}
System.debug('UAT_USER_COUNT|' + [SELECT COUNT() FROM User]);
System.debug('UAT_CONTACT_COUNT|' + [SELECT COUNT() FROM Contact WHERE Email LIKE 'uat-member-%@example.com']);
