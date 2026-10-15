/**
 * @deprecated Legacy User-linked finalizer. The active provisioning path uses
 * LibraryRegistrationProvisioningQueueable and does not enqueue this class.
 * Retained for legacy registrations and rollback safety.
 */
public without sharing class LibraryRegistrationFinalizeQueueable implements Queueable {
  private Id registrationId;
  private Id memberId;
  private Id userId;
  public LibraryRegistrationFinalizeQueueable(
    Id registrationId,
    Id memberId,
    Id userId
  ) {
    this.registrationId = registrationId;
    this.memberId = memberId;
    this.userId = userId;
  }
  public void execute(QueueableContext context) {
    List<Library_Registration__c> registrations = [
      SELECT
        Id,
        Status__c,
        Provisioning_State__c,
        Approved_By__c,
        Approved_Date__c,
        Email__c,
        First_Name__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (registrations.isEmpty())
      return;
    Library_Registration__c r = registrations[0];
    List<Member__c> members = [
      SELECT Id, User__c
      FROM Member__c
      WHERE Id = :memberId
      FOR UPDATE
    ];
    if (members.isEmpty())
      throw new AuraHandledException(
        'The member could not be found during finalization.'
      );
    Member__c m = members[0];
    if (m.User__c == null)
      m.User__c = userId;
    // A completed provisioning job is an active portal account, not a
    // pending registration. Keep both status fields aligned.
    m.Status__c = 'Active';
    m.Account_Status__c = 'Active';
    update m;
    r.Status__c = 'Approved';
    r.Provisioning_State__c = 'Completed';
    r.External_User__c = userId;
    r.Provisioning_Message__c = null;
    if (r.Approved_By__c == null)
      r.Approved_By__c = UserInfo.getUserId();
    if (r.Approved_Date__c == null)
      r.Approved_Date__c = System.now();
    update r;
    sendApprovalEmail(r);
  }
  private static void sendApprovalEmail(Library_Registration__c registration) {
    if (String.isBlank(registration.Email__c))
      return;
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ registration.Email__c });
    email.setSenderDisplayName('Library Management System');
    email.setReplyTo(UserInfo.getUserEmail());
    email.setUseSignature(false);
    email.setSaveAsActivity(false);
    email.setSubject('Your library membership has been approved');
    email.setPlainTextBody(
      'Hello ' +
        registration.First_Name__c +
        ',\n\nYour library membership has been approved. You can now sign in to the library member portal using your registered email address. If you need to set or reset your password, use the Forgot Password link on the sign-in page.\n\nThank you,\nLibrary Management System'
    );
    Messaging.SendEmailResult result = Messaging.sendEmail(
      new List<Messaging.SingleEmailMessage>{ email },
      false
    )[0];
    if (!result.isSuccess()) {
      for (Messaging.SendEmailError errorValue : result.getErrors()) {
        System.debug(
          LoggingLevel.ERROR,
          'Library approval email failed: ' +
            errorValue.getStatusCode() +
            ' ' +
            errorValue.getMessage()
        );
      }
    }
  }
}
