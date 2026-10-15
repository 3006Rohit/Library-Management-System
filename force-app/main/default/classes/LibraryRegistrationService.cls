public with sharing class LibraryRegistrationService {
  @TestVisible
  private static Boolean testLibrarianAuthorized = false;
  @TestVisible
  private static Boolean testAuthorizationOverrideEnabled = false;
  public class RegistrationException extends Exception {
  }
  public static final String DUPLICATE_MESSAGE = 'An application for this email address is already awaiting review.';
  private static final String ACCOUNT_FALLBACK = 'Library Community Members';
  private static final String PROFILE_FALLBACK = 'Customer Community User';
  private static final String PERMISSION_SET_FALLBACK = 'Library_Member';

  public static String normalizeEmail(String value) {
    return value == null ? null : value.trim().toLowerCase();
  }

  public static void requireLibrarian() {
    Boolean authorized = testAuthorizationOverrideEnabled
      ? testLibrarianAuthorized
      : FeatureManagement.checkPermission('Manage_Library_Registrations');
    if (!authorized) {
      throw new AuraHandledException(
        'You are not authorized to manage library registrations.'
      );
    }
    LibrarySecurityService.requireRegistrationAccess();
  }

  public static String submit(
    LibraryRegistrationController.RegistrationInput input
  ) {
    return submitInternal(input, true);
  }

  public static String submitGuest(
    LibraryRegistrationController.RegistrationInput input
  ) {
    return submitInternal(input, false);
  }

  private static String submitInternal(
    LibraryRegistrationController.RegistrationInput input,
    Boolean checkActiveMember
  ) {
    if (input == null)
      throw new AuraHandledException('Please complete the registration form.');
    String email = normalizeEmail(input.email);
    validateInput(input, email);
    List<Membership_Plan__c> plans = [
      SELECT Id
      FROM Membership_Plan__c
      WHERE Id = :input.requestedPlanId AND Active__c = TRUE
      LIMIT 1
    ];
    if (plans.isEmpty())
      throw new AuraHandledException(
        'The selected membership plan is not active or could not be found.'
      );
    Membership_Plan__c plan = plans[0];
    String normalizedEmail = email;
    List<Library_Registration__c> pending = [
      SELECT Id, Normalized_Email__c
      FROM Library_Registration__c
      WHERE
        Status__c = 'Pending'
        AND Normalized_Email__c = :normalizedEmail
    ];
    for (Library_Registration__c existing : pending) {
      if (existing.Normalized_Email__c == email)
        throw new AuraHandledException(DUPLICATE_MESSAGE);
    }
    DateTime rateWindow = System.now().addHours(-1);
    if (
      [
        SELECT COUNT()
        FROM Library_Registration__c
        WHERE
          Normalized_Email__c = :normalizedEmail
          AND CreatedDate >= :rateWindow
      ] >= 3
    )
      throw new AuraHandledException(
        'Registration attempts for this email are temporarily limited. Please try again later.'
      );
    if (checkActiveMember) {
      List<Member__c> activeMembers = [
        SELECT Id, Email__c
        FROM Member__c
        WHERE Status__c = 'Active' AND Normalized_Email__c = :normalizedEmail
      ];
      for (Member__c member : activeMembers) {
        if (normalizeEmail(member.Email__c) == email) {
          throw new AuraHandledException(
            'An active library membership already exists for this email address.'
          );
        }
      }
    }
    Library_Registration__c registration = new Library_Registration__c(
      First_Name__c = input.firstName.trim(),
      Last_Name__c = input.lastName.trim(),
      Email__c = email,
      Phone__c = input.phone == null ? null : input.phone.trim(),
      Date_of_Birth__c = input.dateOfBirth,
      Address__c = input.address,
      Interests__c = cleanInterests(input.interests),
      Requested_Plan__c = plan.Id,
      Registration_Date__c = System.now(),
      Status__c = 'Pending',
      Normalized_Email__c = email,
      Provisioning_Status__c = 'Not Started'
    );
    try {
      insert registration;
    } catch (DmlException e) {
      if (
        e.getMessage() != null && e.getMessage().contains('DUPLICATE_VALUE')
      ) {
        throw new AuraHandledException(DUPLICATE_MESSAGE);
      }
      throw e;
    }
    return registration.Id;
  }

  private static void validateInput(
    LibraryRegistrationController.RegistrationInput input,
    String email
  ) {
    if (
      String.isBlank(input.firstName) ||
      String.isBlank(input.lastName) ||
      String.isBlank(email) ||
      input.requestedPlanId == null
    ) {
      throw new AuraHandledException(
        'First name, last name, email, and membership plan are required.'
      );
    }
    if (!Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', email))
      throw new AuraHandledException('Enter a valid email address.');
    if (email.length() > 80)
      throw new AuraHandledException('Enter a shorter email address.');
    if (
      !String.isBlank(input.phone) &&
      !Pattern.matches('^[+0-9() .-]{7,25}$', input.phone.trim())
    )
      throw new AuraHandledException('Enter a valid phone number.');
    if (input.dateOfBirth != null && input.dateOfBirth > Date.today())
      throw new AuraHandledException('Date of birth cannot be in the future.');
    if (
      input.firstName.trim().length() > 80 ||
      input.lastName.trim().length() > 80
    )
      throw new AuraHandledException('Names must be 80 characters or fewer.');
    if (
      !String.isBlank(input.interests) && input.interests.trim().length() > 255
    )
      throw new AuraHandledException(
        'Interests must be 255 characters or fewer.'
      );
  }
  private static String cleanInterests(String value) {
    return String.isBlank(value) ? null : value.trim();
  }

  public static void approve(Id registrationId) {
    requireLibrarian();
    List<Library_Registration__c> rows = [
      SELECT Id, Status__c, Provisioning_Status__c, Email__c, First_Name__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The registration could not be found.');
    Library_Registration__c r = rows[0];
    if (r.Status__c != 'Pending')
      throw new AuraHandledException(
        'Only Pending registrations can be approved.'
      );
    r.Provisioning_Status__c = 'Queued';
    r.Provisioning_Error__c = null;
    r.Approved_By__c = UserInfo.getUserId();
    r.Approved_Date__c = System.now();
    update r;
    System.enqueueJob(new LibraryRegistrationProvisioningQueueable(r.Id));
  }

  public static void reject(Id registrationId, String reason) {
    requireLibrarian();
    if (String.isBlank(reason))
      throw new AuraHandledException('A rejection reason is required.');
    List<Library_Registration__c> rows = [
      SELECT
        Id,
        Status__c,
        Provisioning_Status__c,
        Created_Contact__c,
        Created_Member__c,
        Email__c,
        First_Name__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The registration could not be found.');
    Library_Registration__c r = rows[0];
    if (r.Status__c != 'Pending')
      throw new AuraHandledException(
        'Only Pending registrations can be rejected.'
      );
    if (r.Provisioning_Status__c != 'Not Started')
      throw new AuraHandledException(
        'This registration is already in provisioning and cannot be rejected.'
      );
    if (r.Created_Contact__c != null || r.Created_Member__c != null)
      throw new AuraHandledException(
        'This registration has already started provisioning and cannot be rejected.'
      );
    r.Status__c = 'Rejected';
    r.Rejection_Reason__c = reason.trim();
    r.Approved_By__c = UserInfo.getUserId();
    r.Approved_Date__c = System.now();
    update r;
    sendApplicantEmail(
      r.Email__c,
      'Library application update',
      'Hello ' +
        r.First_Name__c +
        ',\n\nYour library membership application was not approved. Reason: ' +
        r.Rejection_Reason__c
    );
  }

  public static void retry(Id registrationId) {
    requireLibrarian();
    List<Library_Registration__c> rows = [
      SELECT Id, Status__c, Provisioning_Status__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The registration could not be found.');
    Library_Registration__c r = rows[0];
    if (r.Provisioning_Status__c != 'Failed')
      throw new AuraHandledException(
        'Only failed provisioning can be retried.'
      );
    r.Provisioning_Status__c = 'Queued';
    r.Provisioning_Error__c = null;
    update r;
    System.enqueueJob(new LibraryRegistrationProvisioningQueueable(r.Id));
  }

  public static String accountName() {
    Library_Experience_Config__mdt c = Library_Experience_Config__mdt.getInstance(
      'Default'
    );
    return c == null || String.isBlank(c.Community_Account_Name__c)
      ? ACCOUNT_FALLBACK
      : c.Community_Account_Name__c;
  }
  public static String profileName() {
    Library_Experience_Config__mdt c = Library_Experience_Config__mdt.getInstance(
      'Default'
    );
    return c == null || String.isBlank(c.External_Profile_Name__c)
      ? PROFILE_FALLBACK
      : c.External_Profile_Name__c;
  }
  public static String permissionSetName() {
    Library_Experience_Config__mdt c = Library_Experience_Config__mdt.getInstance(
      'Default'
    );
    return c == null || String.isBlank(c.Member_Permission_Set_Name__c)
      ? PERMISSION_SET_FALLBACK
      : c.Member_Permission_Set_Name__c;
  }
  private static void sendApplicantEmail(
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
    if (!result.isSuccess()) {
      for (Messaging.SendEmailError errorValue : result.getErrors()) {
        System.debug(
          LoggingLevel.ERROR,
          'Library applicant email failed: ' +
            errorValue.getStatusCode() +
            ' ' +
            errorValue.getMessage()
        );
      }
    }
  }
}
