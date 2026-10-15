public without sharing class LibraryRegistrationFailureQueueable implements Queueable {
  private Id registrationId;
  private String errorMessage;
  private LibraryRegistrationFailureQueueable(
    Id registrationId,
    String errorMessage
  ) {
    this.registrationId = registrationId;
    this.errorMessage = errorMessage;
  }
  public static void record(Id registrationId, String errorMessage) {
    System.enqueueJob(
      new LibraryRegistrationFailureQueueable(registrationId, errorMessage)
    );
  }
  public static void recordNow(Id registrationId, String errorMessage) {
    List<Library_Registration__c> rows = [
      SELECT Id, Status__c, Provisioning_Status__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      LIMIT 1
    ];
    if (rows.isEmpty())
      return;
    Library_Registration__c r = rows[0];
    if (r.Status__c == 'Pending' && r.Provisioning_Status__c != 'Completed') {
      r.Provisioning_Status__c = 'Failed';
      r.Provisioning_Error__c = errorMessage != null &&
        errorMessage.contains('LICENSE_LIMIT_EXCEEDED')
        ? 'No Customer Community licenses are available. Free a license or contact the Salesforce administrator, then retry provisioning.'
        : 'Provisioning could not be completed. Contact library administration.';
      update r;
    }
  }
  public void execute(QueueableContext context) {
    recordNow(registrationId, errorMessage);
  }
}
