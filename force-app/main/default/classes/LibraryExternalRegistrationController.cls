public with sharing class LibraryExternalRegistrationController {
  @AuraEnabled
  public static void approveRegistration(Id registrationId) {
    LibraryRegistrationService.requireLibrarian();
    List<Library_Registration__c> rows = [
      SELECT
        Id,
        Status__c,
        External_Auth_Id__c,
        Created_Member__c,
        Email__c,
        First_Name__c,
        Requested_Plan__r.Duration_Days__c,
        Requested_Plan__r.Borrow_Limit__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The registration could not be found.');
    Library_Registration__c registration = rows[0];
    if (String.isBlank(registration.External_Auth_Id__c)) {
      LibraryRegistrationService.approve(registrationId);
      return;
    }
    if (registration.Status__c != 'Pending')
      throw new AuraHandledException(
        'Only Pending registrations can be approved.'
      );
    if (registration.Created_Member__c == null)
      throw new AuraHandledException(
        'The external member record could not be found.'
      );
    Date startDate = Date.today();
    update new Member__c(
      Id = registration.Created_Member__c,
      Account_Status__c = 'Active',
      Status__c = 'Active',
      Membership_Start_Date__c = startDate,
      Membership_End_Date__c = startDate.addDays(
        Integer.valueOf(registration.Requested_Plan__r.Duration_Days__c)
      ),
      Max_Borrow_Limit__c = registration.Requested_Plan__r.Borrow_Limit__c
    );
    registration.Status__c = 'Approved';
    registration.Provisioning_Status__c = 'Completed';
    registration.Provisioning_Status__c = 'Completed';
    registration.Approved_By__c = UserInfo.getUserId();
    registration.Approved_Date__c = System.now();
    registration.Provisioning_Error__c = null;
    Database.update(registration, AccessLevel.SYSTEM_MODE);
    notifyApplicant(
      registration.Email__c,
      'Library application approved',
      'Hello ' +
        registration.First_Name__c +
        ',\n\nYour library membership is active. You can now sign in to the member portal.'
    );
  }
  @AuraEnabled
  public static void rejectRegistration(Id registrationId, String reason) {
    LibraryRegistrationService.requireLibrarian();
    if (String.isBlank(reason))
      throw new AuraHandledException('A rejection reason is required.');
    List<Library_Registration__c> rows = [
      SELECT
        Id,
        Status__c,
        External_Auth_Id__c,
        Created_Member__c,
        Email__c,
        First_Name__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The registration could not be found.');
    Library_Registration__c registration = rows[0];
    if (String.isBlank(registration.External_Auth_Id__c)) {
      LibraryRegistrationService.reject(registrationId, reason);
      return;
    }
    if (registration.Status__c != 'Pending')
      throw new AuraHandledException(
        'Only Pending registrations can be rejected.'
      );
    if (registration.Created_Member__c != null)
      update new Member__c(
        Id = registration.Created_Member__c,
        Account_Status__c = 'Rejected',
        Status__c = 'Closed'
      );
    registration.Status__c = 'Rejected';
    registration.Rejection_Reason__c = reason.trim();
    registration.Approved_By__c = UserInfo.getUserId();
    registration.Approved_Date__c = System.now();
    Database.update(registration, AccessLevel.SYSTEM_MODE);
    notifyApplicant(
      registration.Email__c,
      'Library application update',
      'Hello ' +
        registration.First_Name__c +
        ',\n\nYour library membership application was not approved. Reason: ' +
        registration.Rejection_Reason__c
    );
  }
  @AuraEnabled
  public static void retryProvisioning(Id registrationId) {
    LibraryRegistrationService.retry(registrationId);
  }
  @AuraEnabled(cacheable=true)
  public static Library_Registration__c getRegistrationForReview(
    Id registrationId
  ) {
    LibraryRegistrationService.requireLibrarian();
    return [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Phone__c,
        Date_of_Birth__c,
        Address__c,
        Requested_Plan__c,
        Requested_Plan__r.Name,
        Registration_Date__c,
        Status__c,
        Approved_By__c,
        Approved_By__r.Name,
        Approved_Date__c,
        Rejection_Reason__c,
        Created_Contact__c,
        Created_Contact__r.Name,
        Created_Member__c,
        Created_Member__r.Name,
        Normalized_Email__c,
        Provisioning_Status__c,
        Provisioning_Error__c,
        Provisioned_User__c,
        External_Auth_Id__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      LIMIT 1
    ];
  }
  private static void notifyApplicant(
    String address,
    String subject,
    String body
  ) {
    if (String.isBlank(address))
      return;
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ address });
    email.setSenderDisplayName('Library Management System');
    email.setReplyTo(UserInfo.getUserEmail());
    email.setUseSignature(false);
    email.setSaveAsActivity(false);
    email.setSubject(subject);
    email.setPlainTextBody(body);
    Messaging.SendEmailResult result = Messaging.sendEmail(
      new List<Messaging.SingleEmailMessage>{ email },
      false
    )[0];
    if (!result.isSuccess())
      for (Messaging.SendEmailError errorValue : result.getErrors())
        System.debug(
          LoggingLevel.ERROR,
          'Library applicant email failed: ' +
            errorValue.getStatusCode() +
            ' ' +
            errorValue.getMessage()
        );
  }
}
