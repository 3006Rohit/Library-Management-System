public without sharing class LibraryMemberSessionService {
  private static final Integer SESSION_HOURS = 4;
  public static Member__c getCurrentMember(String rawToken) {
    if (String.isBlank(rawToken))
      throw new AuraHandledException('MEMBER_SESSION_INVALID');
    String digest = LibraryMemberPasswordService.tokenHash(rawToken);
    List<Member_Session__c> sessions = [
      SELECT
        Id,
        Member__c,
        Member__r.Id,
        Member__r.Name,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Member__r.Email__c,
        Member__r.Status__c,
        Member__r.Account_Status__c,
        Member__r.Membership_Plan__c,
        Member__r.Membership_Plan__r.Name,
        Member__r.Membership_Plan__r.Reservation_Limit__c,
        Member__r.Registration_Status__c,
        Member__r.Phone__c,
        Member__r.Address__c,
        Member__r.Interests__c,
        Member__r.Preferred_Language__c,
        Member__r.Timezone__c,
        Member__r.High_Contrast__c,
        Member__r.Large_Text__c,
        Member__r.Reduced_Motion__c,
        Member__r.Screen_Reader__c,
        Member__r.Membership_Start_Date__c,
        Member__r.Membership_End_Date__c,
        Expires_At__c,
        Revoked__c
      FROM Member_Session__c
      WHERE Token_Hash__c = :digest
      LIMIT 1
    ];
    if (
      sessions.isEmpty() ||
      sessions[0].Revoked__c == true ||
      sessions[0].Expires_At__c == null ||
      sessions[0].Expires_At__c <= System.now()
    )
      throw new AuraHandledException('MEMBER_SESSION_INVALID');
    Member__c member = sessions[0].Member__r;
    if (
      member.Status__c != 'Active' ||
      member.Account_Status__c == 'Suspended' ||
      member.Account_Status__c == 'Inactive'
    )
      throw new AuraHandledException('MEMBER_SESSION_INVALID');
    // This method is called by cacheable portal read methods. Do not perform
    // session-touch DML here; Salesforce rejects DML in a cacheable action.
    // Token validity, expiry, revocation, and member status are still checked
    // above on every request.
    return member;
  }
  public static Member__c browserMember(Member__c source) {
    if (source == null)
      return null;
    Member__c safe = source.clone(true, true, false, false);
    safe.Password_Hash__c = null;
    safe.Password_Salt__c = null;
    safe.Activation_Token_Hash__c = null;
    safe.Activation_Token_Expires_At__c = null;
    safe.Reset_Token_Hash__c = null;
    safe.Reset_Token_Expires_At__c = null;
    safe.Failed_Login_Count__c = null;
    safe.Last_Failed_Login__c = null;
    safe.Locked_Until__c = null;
    safe.User__c = null;
    safe.Contact__c = null;
    // Authentication runs as a public guest before a Salesforce member session
    // exists. The guest profile intentionally has no Member__c CRUD/FLS. The
    // fields exposed here are therefore allow-listed by the explicit clearing
    // above; stripInaccessible would reject the whole DTO with
    // "No access to entity: Member__c" in the guest context.
    return safe;
  }
  public static String create(
    Member__c member,
    String ipAddress,
    String userAgent
  ) {
    String raw = LibraryMemberPasswordService.token();
    insert new Member_Session__c(
      Member__c = member.Id,
      Token_Hash__c = LibraryMemberPasswordService.tokenHash(raw),
      Created_At__c = System.now(),
      Expires_At__c = System.now().addHours(SESSION_HOURS),
      Last_Used_At__c = System.now(),
      IPAddress__c = ipAddress,
      User_Agent__c = userAgent
    );
    return raw;
  }
  public static void revoke(String rawToken) {
    if (String.isBlank(rawToken))
      return;
    List<Member_Session__c> rows = [
      SELECT Id, Revoked__c
      FROM Member_Session__c
      WHERE Token_Hash__c = :LibraryMemberPasswordService.tokenHash(rawToken)
      LIMIT 1
    ];
    if (!rows.isEmpty()) {
      rows[0].Revoked__c = true;
      update rows[0];
    }
  }
  public static void revokeAll(Id memberId) {
    List<Member_Session__c> rows = [
      SELECT Id, Revoked__c
      FROM Member_Session__c
      WHERE Member__c = :memberId AND Revoked__c = FALSE
    ];
    for (Member_Session__c row : rows)
      row.Revoked__c = true;
    if (!rows.isEmpty())
      update rows;
  }
}
