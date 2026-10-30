public without sharing class LibraryMemberAuthController {
  public class AuthResult {
    @AuraEnabled
    public String sessionToken;
    @AuraEnabled
    public Member__c member;
  }
  @AuraEnabled
  public static String register(
    LibraryRegistrationController.RegistrationInput input
  ) {
    return LibraryRegistrationService.submit(input);
  }
  @AuraEnabled
  public static AuthResult login(String email, String password) {
    String normalized = normalize(email);
    List<Member__c> rows = [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Password_Hash__c,
        Password_Salt__c,
        Status__c,
        Account_Status__c,
        Registration_Status__c,
        Failed_Login_Count__c,
        Locked_Until__c,
        Membership_Plan__c,
        Membership_Plan__r.Name
      FROM Member__c
      WHERE Normalized_Email__c = :normalized WITH SYSTEM_MODE LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('Invalid email or password.');
    Member__c member = rows[0];
    if (member.Locked_Until__c != null && member.Locked_Until__c > System.now())
      throw new AuraHandledException('Invalid email or password.');
    if (!LibraryMemberPasswordService.matches(member, password)) {
      recordFailure(member);
      throw new AuraHandledException('Invalid email or password.');
    }
    if (
      member.Status__c != 'Active' ||
      member.Account_Status__c != 'Active' ||
      String.isBlank(member.Password_Hash__c)
    )
      throw new AuraHandledException('Invalid email or password.');
    member.Failed_Login_Count__c = 0;
    member.Last_Failed_Login__c = null;
    member.Locked_Until__c = null;
    member.Last_Login__c = System.now();
    update member;
    AuthResult result = new AuthResult();
    result.sessionToken = LibraryMemberSessionService.create(
      member,
      null,
      null
    );
    result.member = safeMember(member);
    return result;
  }
  @AuraEnabled
  public static Member__c validateSession(String sessionToken) {
    return LibraryMemberSessionService.browserMember(
      LibraryMemberSessionService.getCurrentMember(sessionToken)
    );
  }
  @AuraEnabled
  public static Member__c getCurrentMemberContext(String sessionToken) {
    return validateSession(sessionToken);
  }
  @AuraEnabled
  public static void logout(String sessionToken) {
    LibraryMemberSessionService.revoke(sessionToken);
  }
  @AuraEnabled
  public static void activateAccount(
    String token,
    String password,
    String confirmation
  ) {
    if (String.isBlank(token))
      throw new AuraHandledException(
        'This activation link is invalid or expired.'
      );
    LibraryMemberPasswordService.validate(password, confirmation);
    String digest = LibraryMemberPasswordService.tokenHash(token);
    List<Member__c> rows = [
      SELECT
        Id,
        Status__c,
        Account_Status__c,
        Registration_Status__c,
        Activation_Token_Hash__c,
        Activation_Token_Expires_At__c
      FROM Member__c
      WHERE Activation_Token_Hash__c = :digest WITH SYSTEM_MODE LIMIT 1
      FOR UPDATE
    ];
    if (
      rows.isEmpty() || rows[0].Activation_Token_Expires_At__c <= System.now()
    )
      throw new AuraHandledException(
        'This activation link is invalid or expired.'
      );
    Member__c m = rows[0];
    String salt = LibraryMemberPasswordService.newSalt();
    m.Password_Salt__c = salt;
    m.Password_Hash__c = LibraryMemberPasswordService.hash(salt, password);
    m.Email_Verified__c = true;
    m.Registration_Status__c = 'Approved';
    m.Status__c = 'Active';
    m.Account_Status__c = 'Active';
    m.Activation_Token_Hash__c = null;
    m.Activation_Token_Expires_At__c = null;
    update m;
  }
  @AuraEnabled
  public static void forgotPassword(String email) {
    String normalized = normalize(email);
    List<Member__c> rows = [
      SELECT Id, Email__c, First_Name__c, Status__c
      FROM Member__c
      WHERE Normalized_Email__c = :normalized AND Status__c = 'Active' WITH SYSTEM_MODE LIMIT 1
    ];
    if (!rows.isEmpty()) {
      String raw = LibraryMemberPasswordService.token();
      Member__c m = rows[0];
      m.Reset_Token_Hash__c = LibraryMemberPasswordService.tokenHash(raw);
      m.Reset_Token_Expires_At__c = System.now().addHours(1);
      update m;
      sendEmail(
        m.Email__c,
        'Library password reset',
        'Use this one-time reset token on the library reset page: ' + raw
      );
    }
  }
  @AuraEnabled
  public static void resetPassword(
    String token,
    String password,
    String confirmation
  ) {
    if (String.isBlank(token))
      throw new AuraHandledException('This reset link is invalid or expired.');
    LibraryMemberPasswordService.validate(password, confirmation);
    String digest = LibraryMemberPasswordService.tokenHash(token);
    List<Member__c> rows = [
      SELECT Id, Reset_Token_Hash__c, Reset_Token_Expires_At__c
      FROM Member__c
      WHERE Reset_Token_Hash__c = :digest WITH SYSTEM_MODE LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty() || rows[0].Reset_Token_Expires_At__c <= System.now())
      throw new AuraHandledException('This reset link is invalid or expired.');
    Member__c m = rows[0];
    String salt = LibraryMemberPasswordService.newSalt();
    m.Password_Salt__c = salt;
    m.Password_Hash__c = LibraryMemberPasswordService.hash(salt, password);
    m.Reset_Token_Hash__c = null;
    m.Reset_Token_Expires_At__c = null;
    update m;
    LibraryMemberSessionService.revokeAll(m.Id);
  }
  @AuraEnabled
  public static void changePassword(
    String sessionToken,
    String currentPassword,
    String password,
    String confirmation
  ) {
    Member__c sessionMember = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Member__c m = [
      SELECT Id, Password_Hash__c, Password_Salt__c
      FROM Member__c
      WHERE Id = :sessionMember.Id WITH SYSTEM_MODE LIMIT 1
    ];
    if (!LibraryMemberPasswordService.matches(m, currentPassword))
      throw new AuraHandledException('The current password is incorrect.');
    LibraryMemberPasswordService.validate(password, confirmation);
    String salt = LibraryMemberPasswordService.newSalt();
    m.Password_Salt__c = salt;
    m.Password_Hash__c = LibraryMemberPasswordService.hash(salt, password);
    update m;
    LibraryMemberSessionService.revokeAll(m.Id);
  }
  public static String issueActivation(Member__c member) {
    String raw = LibraryMemberPasswordService.token();
    update new Member__c(
      Id = member.Id,
      Activation_Token_Hash__c = LibraryMemberPasswordService.tokenHash(raw),
      Activation_Token_Expires_At__c = System.now().addDays(2)
    );
    return raw;
  }
  private static void recordFailure(Member__c member) {
    Integer count = member.Failed_Login_Count__c == null
      ? 0
      : Integer.valueOf(member.Failed_Login_Count__c);
    count++;
    member.Failed_Login_Count__c = count;
    member.Last_Failed_Login__c = System.now();
    if (count >= 5) {
      member.Locked_Until__c = System.now().addMinutes(15);
      member.Failed_Login_Count__c = 0;
    }
    update member;
  }
  private static String normalize(String email) {
    if (
      String.isBlank(email) ||
      !Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$', email.trim())
    )
      throw new AuraHandledException('Invalid email or password.');
    return email.trim().toLowerCase();
  }
  private static Member__c safeMember(Member__c m) {
    return LibraryMemberSessionService.browserMember(m);
  }
  private static void sendEmail(String address, String subject, String body) {
    Messaging.SingleEmailMessage e = new Messaging.SingleEmailMessage();
    e.setToAddresses(new List<String>{ address });
    e.setSenderDisplayName('Library Management System');
    e.setReplyTo(UserInfo.getUserEmail());
    e.setSubject(subject);
    e.setPlainTextBody(body);
    e.setSaveAsActivity(false);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ e }, false);
  }
}
