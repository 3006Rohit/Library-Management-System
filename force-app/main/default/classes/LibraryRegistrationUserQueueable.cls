/**
 * @deprecated Legacy provisioning path that creates Salesforce Users. The
 * active provisioning queueable does not call this class. Retained only until
 * deployment/runtime dependency verification is complete.
 */
public without sharing class LibraryRegistrationUserQueueable implements Queueable {
  private Id registrationId;
  private Id contactId;
  private Id memberId;
  public LibraryRegistrationUserQueueable(
    Id registrationId,
    Id contactId,
    Id memberId
  ) {
    this.registrationId = registrationId;
    this.contactId = contactId;
    this.memberId = memberId;
  }
  public void execute(QueueableContext context) {
    try {
      List<Library_Registration__c> registrations = [
        SELECT Id, Email__c
        FROM Library_Registration__c
        WHERE Id = :registrationId
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (registrations.isEmpty())
        throw new AuraHandledException('The registration could not be found.');
      List<Contact> contacts = [
        SELECT Id, FirstName, LastName, Email
        FROM Contact
        WHERE Id = :contactId
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (contacts.isEmpty())
        throw new AuraHandledException('The contact could not be found.');
      Contact c = contacts[0];
      List<Member__c> members = [
        SELECT Id, User__c
        FROM Member__c
        WHERE Id = :memberId
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (members.isEmpty())
        throw new AuraHandledException('The member could not be found.');
      Member__c m = members[0];
      User u;
      Boolean newlyCreated = m.User__c == null;
      if (newlyCreated)
        u = findOrCreateUser(c);
      else {
        List<User> users = [SELECT Id FROM User WHERE Id = :m.User__c WITH SYSTEM_MODE LIMIT 1];
        if (users.isEmpty())
          throw new AuraHandledException(
            'The previously created external user could not be found.'
          );
        u = users[0];
      }
      List<PermissionSet> permissionSets = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = :LibraryRegistrationService.permissionSetName()
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (permissionSets.isEmpty())
        throw new AuraHandledException(
          'The member permission set could not be found.'
        );
      PermissionSet ps = permissionSets[0];
      if (
        [
          SELECT COUNT()
          FROM PermissionSetAssignment
          WHERE AssigneeId = :u.Id AND PermissionSetId = :ps.Id
          WITH SYSTEM_MODE
        ] == 0
      )
        insert new PermissionSetAssignment(
          AssigneeId = u.Id,
          PermissionSetId = ps.Id
        );
      // New Experience Cloud users receive the site's welcome email,
      // which includes the one-time password setup link. Existing users
      // retain the reset path for retries.
      if (!newlyCreated && !Test.isRunningTest())
        System.resetPassword(u.Id, true);
      System.enqueueJob(
        new LibraryRegistrationFinalizeQueueable(registrationId, memberId, u.Id)
      );
    } catch (Exception e) {
      LibraryRegistrationFailureQueueable.record(registrationId, message(e));
    }
  }
  private static User findOrCreateUser(Contact c) {
    List<User> existing = [SELECT Id FROM User WHERE ContactId = :c.Id WITH SYSTEM_MODE LIMIT 1];
    if (!existing.isEmpty())
      return existing[0];
    List<Profile> profiles = [
      SELECT Id
      FROM Profile
      WHERE Name = :LibraryRegistrationService.profileName()
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (profiles.isEmpty())
      throw new AuraHandledException(
        'The configured external profile could not be found.'
      );
    Profile p = profiles[0];
    String normalizedEmail = LibraryRegistrationService.normalizeEmail(c.Email);
    Integer at = normalizedEmail.indexOf('@');
    String localPart = normalizedEmail.substring(0, at);
    String domainPart = normalizedEmail.substring(at + 1);
    String tag =
      '.library.' + UserInfo.getOrganizationId().substring(0, 8).toLowerCase();
    Integer maxLocalLength = 80 - tag.length() - domainPart.length() - 1;
    if (maxLocalLength < 1)
      maxLocalLength = 1;
    String username =
      localPart.left(Math.min(maxLocalLength, localPart.length())) +
      tag +
      '@' +
      domainPart;
    if ([SELECT COUNT() FROM User WHERE Username = :username WITH SYSTEM_MODE] > 0) {
      String randomTag =
        '.' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
      Integer randomLocalLength =
        80 -
        randomTag.length() -
        domainPart.length() -
        1;
      username =
        localPart.left(Math.min(randomLocalLength, localPart.length())) +
        randomTag +
        '@' +
        domainPart;
    }
    String alias = (c.FirstName.left(Math.min(3, c.FirstName.length())) +
      c.LastName)
      .left(8);
    User u = new User(
      ContactId = c.Id,
      ProfileId = p.Id,
      FirstName = c.FirstName,
      LastName = c.LastName,
      Email = c.Email,
      Username = username,
      Alias = alias,
      CommunityNickname = (c.FirstName +
        '.' +
        c.LastName +
        '.' +
        String.valueOf(Crypto.getRandomInteger()).replace('-', ''))
        .left(40),
      TimeZoneSidKey = 'Asia/Kolkata',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    Database.DMLOptions options = new Database.DMLOptions();
    options.EmailHeader.triggerUserEmail = true;
    Database.insert(u, options);
    return u;
  }
  private static String message(Exception e) {
    String value = e.getTypeName() + ': ' + e.getMessage();
    return value.length() > 255 ? value.left(255) : value;
  }
}
