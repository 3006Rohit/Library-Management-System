List<String> emails = new List<String>();
for (Integer i = 1; i <= 20; i++) emails.add('uat-member-' + String.valueOf(i).leftPad(2, '0') + '@example.com');
if ([SELECT COUNT() FROM Member__c WHERE Normalized_Email__c IN :emails] == 0) {
    Map<String, Membership_Plan__c> plans = new Map<String, Membership_Plan__c>();
    for (Membership_Plan__c p : [SELECT Id, Name, Borrow_Limit__c FROM Membership_Plan__c WHERE Active__c = true AND Name IN ('Basic','Standard','Premium')]) plans.put(p.Name, p);
    System.assert(plans.size() == 3, 'Basic, Standard, and Premium plans must exist.');
    List<Member__c> rows = new List<Member__c>();
    Date today = Date.today();
    for (Integer i = 1; i <= 20; i++) {
        String email = emails[i - 1];
        String planName = i <= 7 ? 'Basic' : (i <= 14 ? 'Standard' : 'Premium');
        String status = i == 5 || i == 6 ? 'Suspended' : (i == 7 ? 'Expired' : 'Active');
        String accountStatus = i == 6 ? 'Suspended' : (i == 7 ? 'Inactive' : 'Active');
        rows.add(new Member__c(
            First_Name__c = 'UAT', Last_Name__c = 'Member ' + String.valueOf(i).leftPad(2, '0'),
            Email__c = email, Normalized_Email__c = email, Phone__c = '+91 91111 ' + String.valueOf(10000 + i),
            Membership_Plan__c = plans.get(planName).Id, Registration_Date__c = today.addDays(-i),
            Membership_Start_Date__c = today.addDays(-30), Membership_End_Date__c = i == 7 ? today.addDays(-1) : today.addDays(335),
            Status__c = status, Account_Status__c = accountStatus,
            Member_Type__c = 'UAT',
            Max_Borrow_Limit__c = plans.get(planName).Borrow_Limit__c,
            Interests__c = i == 1 ? 'No borrowing history' : (i == 2 ? 'Active loan' : (i == 3 ? 'Multiple active loans' : (i == 4 ? 'Overdue loan' : null)))
        ));
    }
    insert rows;
    System.debug(LoggingLevel.INFO, 'Created 20 auth UAT Member__c records and no User records.');
} else {
    System.debug(LoggingLevel.WARN, 'UAT member cohort already exists; no records inserted.');
}
