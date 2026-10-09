public without sharing class LibraryRegistrationProvisioningQueueable implements Queueable {
    private Id registrationId;
    public LibraryRegistrationProvisioningQueueable(Id registrationId) { this.registrationId = registrationId; }
    public void execute(QueueableContext context) {
        Library_Registration__c r = [SELECT Id, First_Name__c, Last_Name__c, Email__c, Registration_Email_Key__c, Phone__c, Date_of_Birth__c, Address__c, Requested_Plan__c,
            Requested_Plan__r.Duration_Days__c, Requested_Plan__r.Borrow_Limit__c, Status__c, Provisioning_State__c, Created_Contact__c, Created_Member__c
            FROM Library_Registration__c WHERE Id = :registrationId FOR UPDATE];
        if (r.Status__c != 'Pending' || r.Provisioning_State__c == 'Completed') return;
        try {
            r.Provisioning_State__c = 'Processing'; r.Provisioning_Message__c = null; update r;
            Account account = [SELECT Id FROM Account WHERE Name = :LibraryRegistrationService.accountName() LIMIT 1];
            Contact contact = r.Created_Contact__c == null ? findOrCreateContact(r, account.Id) : [SELECT Id, AccountId, FirstName, LastName, Email, Phone FROM Contact WHERE Id = :r.Created_Contact__c LIMIT 1];
            Member__c member = r.Created_Member__c == null ? findOrCreateMember(r, contact.Id) : [SELECT Id, User__c FROM Member__c WHERE Id = :r.Created_Member__c LIMIT 1];
            r.Created_Contact__c = contact.Id; r.Created_Member__c = member.Id; update r;
            System.enqueueJob(new LibraryRegistrationUserQueueable(r.Id, contact.Id, member.Id));
        } catch (Exception e) { LibraryRegistrationFailureQueueable.recordNow(r.Id, safeMessage(e)); }
    }
    private static Contact findOrCreateContact(Library_Registration__c r, Id accountId) {
        for (Contact c : [SELECT Id, AccountId, FirstName, LastName, Email, Phone FROM Contact WHERE AccountId = :accountId AND Email = :r.Email__c LIMIT 10]) {
            if (LibraryRegistrationService.normalizeEmail(c.Email) == r.Registration_Email_Key__c) return c;
        }
        Contact c = new Contact(FirstName=r.First_Name__c, LastName=r.Last_Name__c, Email=r.Email__c, Phone=r.Phone__c, AccountId=accountId);
        insert c; return c;
    }
    private static Member__c findOrCreateMember(Library_Registration__c r, Id contactId) {
        List<Member__c> existing = [SELECT Id, User__c FROM Member__c WHERE Email__c = :r.Email__c LIMIT 10];
        for (Member__c m : existing) if (m.User__c == null) return updateMember(m, r, contactId);
        Membership_Plan__c plan = r.Requested_Plan__r;
        Date startDate = Date.today();
        Member__c m = new Member__c(First_Name__c=r.First_Name__c, Last_Name__c=r.Last_Name__c, Email__c=r.Email__c,
            Phone__c=r.Phone__c, Date_of_Birth__c=r.Date_of_Birth__c, Address__c=r.Address__c, Membership_Plan__c=r.Requested_Plan__c, Contact__c=contactId,
            Registration_Date__c=Date.today(), Membership_Start_Date__c=startDate, Membership_End_Date__c=startDate.addDays(Integer.valueOf(plan.Duration_Days__c)),
            Max_Borrow_Limit__c=plan.Borrow_Limit__c, Status__c='Active');
        insert m; return m;
    }
    private static Member__c updateMember(Member__c m, Library_Registration__c r, Id contactId) { m.Contact__c=contactId; update m; return m; }
    private static String safeMessage(Exception e) { return 'Provisioning could not be completed. Contact library administration.'; }
}
