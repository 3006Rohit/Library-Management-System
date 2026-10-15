public without sharing class LibraryRegistrationProvisioningQueueable implements Queueable {
  @TestVisible
  private static String testLastError;
  private Id registrationId;
  public LibraryRegistrationProvisioningQueueable(Id registrationId) {
    this.registrationId = registrationId;
  }
  public void execute(QueueableContext context) {
    List<Library_Registration__c> rows = [
      SELECT
        Id,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Normalized_Email__c,
        Phone__c,
        Date_of_Birth__c,
        Address__c,
        Interests__c,
        Requested_Plan__c,
        Requested_Plan__r.Duration_Days__c,
        Requested_Plan__r.Borrow_Limit__c,
        Status__c,
        Provisioning_Status__c,
        Created_Member__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (rows.isEmpty() || rows[0].Status__c != 'Pending')
      return;
    Library_Registration__c registration = rows[0];
    try {
      registration.Provisioning_Status__c = 'Processing';
      registration.Provisioning_Error__c = null;
      update registration;
      List<Member__c> existing = [
        SELECT Id, Status__c, Account_Status__c
        FROM Member__c
        WHERE
          Normalized_Email__c = :registration.Normalized_Email__c
          OR Email__c = :registration.Normalized_Email__c
        LIMIT 2
      ];
      if (existing.size() > 1)
        throw new AuraHandledException(
          'A member with this email already exists.'
        );
      Member__c member;
      if (existing.isEmpty()) {
        Membership_Plan__c plan = registration.Requested_Plan__r;
        Date startDate = Date.today();
        member = new Member__c(
          First_Name__c = registration.First_Name__c,
          Last_Name__c = registration.Last_Name__c,
          Email__c = registration.Email__c,
          Normalized_Email__c = registration.Normalized_Email__c,
          Phone__c = registration.Phone__c,
          Date_of_Birth__c = registration.Date_of_Birth__c,
          Address__c = registration.Address__c,
          Interests__c = registration.Interests__c,
          Membership_Plan__c = registration.Requested_Plan__c,
          Registration_Date__c = startDate,
          Membership_Start_Date__c = startDate,
          Membership_End_Date__c = startDate.addDays(
            Integer.valueOf(plan.Duration_Days__c)
          ),
          Max_Borrow_Limit__c = plan.Borrow_Limit__c,
          Status__c = 'Suspended',
          Account_Status__c = 'Active',
          Member_Type__c = 'Production'
        );
        insert member;
      } else {
        member = existing[0];
      }
      Database.update(
        new Member__c(Id = member.Id, Registration_Status__c = 'Approved'),
        AccessLevel.SYSTEM_MODE
      );
      if (!existing.isEmpty())
        Database.update(
          new Member__c(Id = member.Id, Status__c = 'Suspended'),
          AccessLevel.SYSTEM_MODE
        );
      String activationToken = LibraryMemberAuthController.issueActivation(
        member
      );
      registration.Created_Member__c = member.Id;
      registration.Status__c = 'Approved';
      registration.Provisioning_Status__c = 'Completed';
      registration.Provisioning_Error__c = null;
      update registration;
      sendActivation(registration, activationToken);
    } catch (Exception e) {
      if (Test.isRunningTest()) {
        testLastError = e.getTypeName() + ': ' + e.getMessage();
        if (e instanceof DmlException)
          testLastError += ' fields=' + ((DmlException) e).getDmlFields(0);
      }
      LibraryRegistrationFailureQueueable.recordNow(
        registration.Id,
        safeMessage(e)
      );
    }
  }
  private static void sendActivation(Library_Registration__c r, String token) {
    if (String.isBlank(r.Email__c))
      return;
    Messaging.SingleEmailMessage e = new Messaging.SingleEmailMessage();
    e.setToAddresses(new List<String>{ r.Email__c });
    e.setSenderDisplayName('Library Management System');
    e.setReplyTo(UserInfo.getUserEmail());
    e.setSubject('Activate your library membership');
    e.setPlainTextBody(
      'Hello ' +
        r.First_Name__c +
        ',\n\nYour library membership was approved. Open the library activation page and enter this one-time activation token: ' +
        token +
        '\n\nThis token expires in 48 hours.'
    );
    e.setSaveAsActivity(false);
    Messaging.SendEmailResult result = Messaging.sendEmail(
      new List<Messaging.SingleEmailMessage>{ e },
      false
    )[0];
    if (!result.isSuccess()) {
      List<String> errors = new List<String>();
      for (Messaging.SendEmailError errorValue : result.getErrors())
        errors.add(
          String.valueOf(errorValue.getStatusCode()) +
            ': ' +
            errorValue.getMessage()
        );
      Database.update(
        new Library_Registration__c(
          Id = r.Id,
          Provisioning_Error__c = 'Membership approved, but the activation email could not be sent: ' +
            String.join(errors, '; ')
        ),
        AccessLevel.SYSTEM_MODE
      );
    }
  }
  private static String safeMessage(Exception e) {
    String value = e.getTypeName() + ': ' + e.getMessage();
    return value.length() > 255 ? value.left(255) : value;
  }
}
