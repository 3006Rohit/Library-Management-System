/**
 * @deprecated Legacy User/Contact identity resolver. Custom member sessions
 * resolve identity through LibraryMemberSessionService. Retained for legacy
 * controller compatibility and controlled rollback.
 */
public without sharing class LibraryMemberIdentityService {
  @TestVisible
  private static String lastFailureCode;

  public static Member__c resolve() {
    return resolveForUser(
      Test.isRunningTest() && testUserId != null
        ? testUserId
        : UserInfo.getUserId()
    );
  }

  public static Member__c resolve(Id authenticatedUserId) {
    return resolveForUser(authenticatedUserId);
  }

  @TestVisible
  private static Id testUserId;
  @TestVisible
  private static Id testContactId;

  @TestVisible
  private static Member__c resolveForUser(Id userId) {
    User currentUser = [
      SELECT Id, ContactId
      FROM User
      WHERE Id = :userId
      LIMIT 1
    ];
    Id authenticatedContactId = Test.isRunningTest() && testContactId != null
      ? testContactId
      : currentUser.ContactId;
    // Experience Cloud sharing is Contact-based. Resolve through the
    // authenticated user's ContactId so the resolver follows the same
    // canonical relationship exposed to the external runtime.
    Map<String, Object> identityBinds = new Map<String, Object>{
      'userId' => userId,
      'contactId' => authenticatedContactId
    };
    // Existing portal users are often provisioned with the direct Member.User__c
    // link. Prefer that canonical link, then fall back to ContactId for older
    // records that predate direct user mapping.
    List<Member__c> mappings = (List<Member__c>) Database.queryWithBinds(
      'SELECT Id, User__c, Contact__c, Status__c, Account_Status__c FROM Member__c WHERE User__c = :userId LIMIT 2',
      identityBinds,
      AccessLevel.SYSTEM_MODE
    );
    if (mappings.isEmpty() && authenticatedContactId != null) {
      mappings = (List<Member__c>) Database.queryWithBinds(
        'SELECT Id, User__c, Contact__c, Status__c, Account_Status__c FROM Member__c WHERE Contact__c = :contactId LIMIT 2',
        identityBinds,
        AccessLevel.SYSTEM_MODE
      );
    }
    String code = mappingCode(mappings, authenticatedContactId);
    if (code != null)
      throw failure(code);

    Map<String, Object> memberBinds = new Map<String, Object>{
      'memberId' => mappings[0].Id
    };
    List<Member__c> memberRows = (List<Member__c>) Database.queryWithBinds(
      'SELECT Id,Name,User__c,Contact__c,First_Name__c,Last_Name__c,Email__c,Phone__c,Address__c,Interests__c,Status__c,Account_Status__c,Registration_Date__c,Membership_Start_Date__c,Membership_End_Date__c,Membership_Plan__c,Membership_Plan__r.Name,Membership_Plan__r.Duration_Days__c,Membership_Plan__r.Borrow_Limit__c,Membership_Plan__r.Loan_Duration_Days__c,Membership_Plan__r.Reservation_Limit__c,Membership_Plan__r.Renewal_Limit__c,Membership_Plan__r.Fine_Per_Day__c FROM Member__c WHERE Id = :memberId LIMIT 1',
      memberBinds,
      AccessLevel.SYSTEM_MODE
    );
    if (memberRows.isEmpty())
      throw failure('MEMBER_RECORD_NOT_FOUND');
    Member__c member = memberRows[0];
    SObjectAccessDecision readable = Security.stripInaccessible(
      AccessType.READABLE,
      new List<Member__c>{ member }
    );
    if (readable.getRecords().isEmpty())
      throw failure('MEMBER_FIELD_ACCESS_DENIED');
    System.debug(
      LoggingLevel.INFO,
      'Library member identity resolved: userId=' +
        userId +
        ', contactId=' +
        authenticatedContactId +
        ', memberCount=' +
        mappings.size() +
        ', memberId=' +
        member.Id
    );
    return (Member__c) readable.getRecords()[0];
  }

  @TestVisible
  private static String mappingCode(
    List<Member__c> mappings,
    Id userContactId
  ) {
    if (mappings == null || mappings.isEmpty())
      return 'MEMBER_MAPPING_NOT_FOUND';
    if (mappings.size() > 1)
      return 'MEMBER_MAPPING_DUPLICATE';
    if (
      mappings[0].Contact__c != null &&
      userContactId != null &&
      mappings[0].Contact__c != userContactId
    )
      return 'CONTACT_MAPPING_MISMATCH';
    if (mappings[0].Account_Status__c == 'Pending')
      return 'MEMBER_PENDING_APPROVAL';
    if (mappings[0].Account_Status__c == 'Rejected')
      return 'MEMBER_REJECTED';
    if (
      mappings[0].Account_Status__c == 'Suspended' ||
      mappings[0].Account_Status__c == 'Inactive'
    )
      return 'MEMBER_SUSPENDED';
    if (mappings[0].Status__c != 'Active')
      return 'MEMBER_INACTIVE';
    return null;
  }

  @TestVisible
  private static AuraHandledException failure(String code) {
    lastFailureCode = code;
    System.debug(
      LoggingLevel.ERROR,
      'Library member identity resolution failed: ' + code
    );
    String detail = code == 'MEMBER_MAPPING_NOT_FOUND'
      ? 'No active Member record is linked to the authenticated Contact.'
      : code == 'MEMBER_MAPPING_DUPLICATE'
          ? 'More than one Member record is linked to the authenticated Contact.'
          : code == 'CONTACT_MAPPING_MISMATCH'
              ? 'The Member Contact does not match the authenticated user Contact.'
              : code == 'MEMBER_PENDING_APPROVAL'
                  ? 'The membership registration is awaiting librarian approval.'
                  : code == 'MEMBER_REJECTED'
                      ? 'The membership registration was rejected.'
                      : code == 'MEMBER_SUSPENDED'
                          ? 'The member portal account is suspended.'
                          : code == 'MEMBER_INACTIVE'
                              ? 'The linked Member record is not Active.'
                              : code == 'MEMBER_RECORD_NOT_FOUND'
                                  ? 'The Member mapping was found, but the full Member record could not be loaded.'
                                  : 'The linked Member record is not readable by the portal.';
    return new AuraHandledException(
      'MEMBER_PORTAL_ERROR [' + code + ']: ' + detail
    );
  }
}
