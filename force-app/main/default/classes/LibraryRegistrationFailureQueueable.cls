public without sharing class LibraryRegistrationFailureQueueable implements Queueable {
    private Id registrationId; private String errorMessage;
    private LibraryRegistrationFailureQueueable(Id registrationId, String errorMessage) { this.registrationId=registrationId; this.errorMessage=errorMessage; }
    public static void record(Id registrationId, String errorMessage) { System.enqueueJob(new LibraryRegistrationFailureQueueable(registrationId, errorMessage)); }
    public static void recordNow(Id registrationId, String errorMessage) {
        Library_Registration__c r=[SELECT Id, Status__c, Provisioning_State__c FROM Library_Registration__c WHERE Id=:registrationId LIMIT 1];
        if (r.Status__c == 'Pending' && r.Provisioning_State__c != 'Completed') {
            r.Provisioning_State__c = 'Failed';
            r.Provisioning_Message__c = 'Provisioning could not be completed. Contact library administration.';
            update r;
        }
    }
    public void execute(QueueableContext context) {
        recordNow(registrationId, errorMessage);
    }
}
