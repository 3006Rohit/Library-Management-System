public without sharing class LibraryRegistrationFinalizeQueueable implements Queueable {
    private Id registrationId; private Id memberId; private Id userId;
    public LibraryRegistrationFinalizeQueueable(Id registrationId, Id memberId, Id userId) { this.registrationId=registrationId; this.memberId=memberId; this.userId=userId; }
    public void execute(QueueableContext context) {
        Library_Registration__c r=[SELECT Id, Status__c, Provisioning_State__c, Approved_By__c, Approved_Date__c FROM Library_Registration__c WHERE Id=:registrationId FOR UPDATE];
        Member__c m=[SELECT Id, User__c FROM Member__c WHERE Id=:memberId FOR UPDATE];
        if (m.User__c == null) { m.User__c=userId; update m; }
        r.Status__c='Approved'; r.Provisioning_State__c='Completed'; r.External_User__c=userId; r.Provisioning_Message__c=null;
        if (r.Approved_By__c == null) r.Approved_By__c = UserInfo.getUserId();
        if (r.Approved_Date__c == null) r.Approved_Date__c = System.now();
        update r;
    }
}
