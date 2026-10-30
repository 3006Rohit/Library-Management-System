public without sharing class LibraryPrivacyService {
  private static final String OPERATION = 'Privacy Request';
  private static final Integer EXPORT_HOURS = 24;

  public class RequestDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public String requestType;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String decisionReason;
    @AuraEnabled
    public Datetime submittedAt;
    @AuraEnabled
    public Datetime expiresAt;
    @AuraEnabled
    public String downloadUrl;
  }

  public static RequestDTO requestExport(
    String sessionToken,
    String currentPassword
  ) {
    Member__c member = reauthenticate(sessionToken, currentPassword);
    String key =
      'PRIVACY:EXPORT:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(Date.today());
    List<Library_Scan_Transaction__c> existing = findByKey(key, member.Id);
    if (!existing.isEmpty())
      return toDto(existing[0], member);
    Datetime expiresAt = System.now().addHours(EXPORT_HOURS);
    ContentVersion file = new ContentVersion(
      Title = 'library-export-' + String.valueOf(Date.today()),
      PathOnClient = 'library-export-' + String.valueOf(Date.today()) + '.json',
      VersionData = Blob.valueOf(JSON.serialize(buildExport(member.Id))),
      IsMajorVersion = true
    );
    Database.insert(file, AccessLevel.SYSTEM_MODE);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Member__c = member.Id,
      Status__c = 'Completed',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            't' => 'Export',
            'cv' => String.valueOf(file.Id),
            'x' => String.valueOf(expiresAt),
            'r' => 'Allowlisted profile, circulation, financial, engagement, event, room, and notification data.'
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Privacy Export',
      'Member Re-authenticated',
      member.Id,
      key,
      'Member requested an allowlisted export.',
      'Completed',
      null,
      new Map<String, Object>{ 'requestId' => row.Id, 'expiresAt' => expiresAt }
    );
    return toDto(row, member);
  }

  public static RequestDTO requestCorrection(
    String sessionToken,
    String currentPassword,
    String firstName,
    String lastName,
    String phone,
    String address,
    String reason
  ) {
    Member__c member = reauthenticate(sessionToken, currentPassword);
    validateReason(reason);
    if (String.isBlank(firstName) || String.isBlank(lastName))
      throw new AuraHandledException(
        'First and last name are required for a correction.'
      );
    String key =
      'PRIVACY:CORRECTION:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(Date.today());
    List<Library_Scan_Transaction__c> existing = findByKey(key, member.Id);
    if (!existing.isEmpty())
      return toDto(existing[0], member);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Member__c = member.Id,
      Status__c = 'Pending',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            't' => 'Correction',
            'f' => firstName.trim().left(60),
            'l' => lastName.trim().left(60),
            'p' => String.isBlank(phone) ? null : phone.trim().left(40),
            'a' => String.isBlank(address) ? null : address.trim().left(120),
            'r' => reason.trim().left(80)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Privacy Correction Request',
      'Member Re-authenticated',
      member.Id,
      key,
      reason,
      'Pending',
      null,
      new Map<String, Object>{
        'requestId' => row.Id,
        'fields' => 'profile allowlist'
      }
    );
    return toDto(row, member);
  }

  public static RequestDTO requestDeletion(
    String sessionToken,
    String currentPassword,
    String reason
  ) {
    Member__c member = reauthenticate(sessionToken, currentPassword);
    validateReason(reason);
    String key = 'PRIVACY:DELETION:' + String.valueOf(member.Id);
    List<Library_Scan_Transaction__c> existing = findByKey(key, member.Id);
    if (!existing.isEmpty())
      return toDto(existing[0], member);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Member__c = member.Id,
      Status__c = 'Pending',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            't' => 'Deletion',
            'r' => reason.trim().left(120)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Privacy Deletion Request',
      'Member Re-authenticated',
      member.Id,
      key,
      reason,
      'Pending',
      null,
      new Map<String, Object>{
        'requestId' => row.Id,
        'retention' => 'financial,audit,safety'
      }
    );
    return toDto(row, member);
  }

  public static List<RequestDTO> getMine(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<RequestDTO> result = new List<RequestDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :OPERATION
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 200
    ])
      result.add(toDto(row, member));
    return result;
  }

  public static void cancel(String sessionToken, Id requestId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :requestId
        AND Member__c = :member.Id
        AND Operation__c = :OPERATION
      WITH SYSTEM_MODE
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty() || rows[0].Status__c != 'Pending')
      throw new AuraHandledException(
        'Only pending privacy requests can be cancelled.'
      );
    rows[0].Status__c = 'Cancelled';
    Database.update(rows[0], AccessLevel.SYSTEM_MODE);
  }

  public static List<RequestDTO> getAll() {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Map<Id, Member__c> members = new Map<Id, Member__c>(
      [
        SELECT Id, Name
        FROM Member__c
        WITH SYSTEM_MODE
        LIMIT 5000
      ]
    );
    List<RequestDTO> result = new List<RequestDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 1000
    ])
      if (members.containsKey(row.Member__c))
        result.add(toDto(row, members.get(row.Member__c)));
    return result;
  }

  public static void decide(
    Id requestId,
    String status,
    String decisionReason
  ) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    if (
      !new Set<String>{ 'Approved', 'Rejected' }.contains(status) ||
      String.isBlank(decisionReason)
    )
      throw new AuraHandledException(
        'Choose Approved or Rejected and provide a decision reason.'
      );
    Library_Scan_Transaction__c row = [
      SELECT Id, Member__c, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :requestId AND Operation__c = :OPERATION
      WITH SYSTEM_MODE
      LIMIT 1
      FOR UPDATE
    ];
    if (row.Status__c != 'Pending')
      throw new AuraHandledException(
        'This privacy request is not pending review.'
      );
    Map<String, Object> payload = parse(row.Result_Message__c);
    String type = stringValue(payload.get('t'));
    if (status == 'Approved' && type == 'Correction')
      applyCorrection(row.Member__c, payload);
    if (status == 'Approved' && type == 'Deletion')
      anonymizeMember(row.Member__c);
    payload.put('d', decisionReason.trim().left(100));
    if (type == 'Deletion')
      payload.put(
        'retention',
        'Loans, fines, payments, audit, and safety records retained under legal policy; profile identifiers anonymized.'
      );
    row.Result_Message__c = JSON.serialize(payload).left(255);
    row.Status__c = status;
    Database.update(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Privacy Request Decision',
      'Manage_Library_Registrations',
      row.Member__c,
      String.valueOf(row.Id),
      decisionReason,
      status,
      new Map<String, Object>{ 'status' => 'Pending', 'type' => type },
      new Map<String, Object>{ 'status' => status, 'type' => type }
    );
  }

  private static Member__c reauthenticate(
    String sessionToken,
    String currentPassword
  ) {
    Member__c sessionMember = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Member__c member = [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Password_Hash__c,
        Password_Salt__c
      FROM Member__c
      WHERE Id = :sessionMember.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (!LibraryMemberPasswordService.matches(member, currentPassword))
      throw new AuraHandledException(
        'Re-authentication failed. Enter your current password.'
      );
    return member;
  }

  private static Map<String, Object> buildExport(Id memberId) {
    Map<String, Object> data = new Map<String, Object>();
    Member__c member = [
      SELECT
        Id,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Phone__c,
        Address__c,
        Interests__c,
        Status__c,
        Account_Status__c,
        Membership_Start_Date__c,
        Membership_End_Date__c,
        Membership_Plan__r.Name
      FROM Member__c
      WHERE Id = :memberId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    data.put(
      'profile',
      new Map<String, Object>{
        'id' => String.valueOf(member.Id),
        'firstName' => member.First_Name__c,
        'lastName' => member.Last_Name__c,
        'email' => member.Email__c,
        'phone' => member.Phone__c,
        'address' => member.Address__c,
        'interests' => member.Interests__c,
        'status' => member.Status__c,
        'accountStatus' => member.Account_Status__c,
        'membershipStart' => member.Membership_Start_Date__c,
        'membershipEnd' => member.Membership_End_Date__c,
        'membershipPlan' => member.Membership_Plan__r == null
          ? null
          : member.Membership_Plan__r.Name
      }
    );
    data.put(
      'loans',
      [
        SELECT
          Id,
          Name,
          Borrow_Date__c,
          Due_Date__c,
          Return_Date__c,
          Status__c,
          Renewal_Count__c
        FROM Borrow_Record__c
        WHERE Member__c = :memberId
        WITH SYSTEM_MODE
        LIMIT 500
      ]
    );
    data.put(
      'reservations',
      [
        SELECT
          Id,
          Name,
          Reservation_Date__c,
          Status__c,
          Queue_Position__c,
          Ready_Date__c,
          Expiry_Date__c
        FROM Reservation__c
        WHERE Member__c = :memberId
        WITH SYSTEM_MODE
        LIMIT 500
      ]
    );
    data.put(
      'fines',
      [
        SELECT
          Id,
          Name,
          Fine_Type__c,
          Amount__c,
          Paid_Amount__c,
          Balance__c,
          Status__c,
          Generated_Date__c,
          Paid_Date__c
        FROM Fine__c
        WHERE Member__c = :memberId
        WITH SYSTEM_MODE
        LIMIT 500
      ]
    );
    data.put(
      'payments',
      [
        SELECT
          Id,
          Name,
          Amount__c,
          Status__c,
          Payment_Method__c,
          Payment_Date__c
        FROM Membership_Payment__c
        WHERE Member__c = :memberId
        WITH SYSTEM_MODE
        LIMIT 200
      ]
    );
    data.put(
      'notifications',
      [
        SELECT Id, Type__c, Subject__c, Message__c, Status__c, CreatedDate
        FROM Member_Notification__c
        WHERE Member__c = :memberId
        WITH SYSTEM_MODE
        LIMIT 500
      ]
    );
    List<Map<String, Object>> activity = new List<Map<String, Object>>();
    for (Library_Scan_Transaction__c row : [
      SELECT Operation__c, Status__c, Created_At__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :memberId AND Operation__c NOT IN ('Privacy Request')
      WITH SYSTEM_MODE
      LIMIT 1000
    ]) {
      Map<String, Object> safePayload = parse(row.Result_Message__c);
      safePayload.remove('h');
      safePayload.remove('x');
      safePayload.remove('cv');
      activity.add(
        new Map<String, Object>{
          'operation' => row.Operation__c,
          'status' => row.Status__c,
          'createdAt' => row.Created_At__c,
          'details' => safePayload
        }
      );
    }
    data.put('activity', activity);
    data.put('generatedAt', System.now());
    data.put(
      'excluded',
      new List<String>{
        'password hashes and salts',
        'session and confirmation tokens',
        'internal risk signals',
        'unrelated staff notes'
      }
    );
    return data;
  }

  private static void applyCorrection(
    Id memberId,
    Map<String, Object> payload
  ) {
    update new Member__c(
      Id = memberId,
      First_Name__c = stringValue(payload.get('f')),
      Last_Name__c = stringValue(payload.get('l')),
      Phone__c = stringValue(payload.get('p')),
      Address__c = stringValue(payload.get('a'))
    );
  }
  private static void anonymizeMember(Id memberId) {
    String alias =
      'deleted+' +
      String.valueOf(memberId).left(15) +
      '@privacy.invalid';
    update new Member__c(
      Id = memberId,
      First_Name__c = 'Deleted',
      Last_Name__c = 'Member',
      Email__c = alias,
      Normalized_Email__c = alias,
      Phone__c = null,
      Address__c = null,
      Interests__c = null,
      Account_Status__c = 'Inactive',
      Status__c = 'Inactive'
    );
    LibraryMemberSessionService.revokeAll(memberId);
  }

  private static List<Library_Scan_Transaction__c> findByKey(
    String key,
    Id memberId
  ) {
    return [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :key
        AND Member__c = :memberId
        AND Operation__c = :OPERATION
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }
  private static RequestDTO toDto(
    Library_Scan_Transaction__c row,
    Member__c member
  ) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    RequestDTO dto = new RequestDTO();
    dto.id = row.Id;
    dto.memberId = row.Member__c;
    dto.memberName = member.Name;
    dto.requestType = stringValue(payload.get('t'));
    dto.status = row.Status__c;
    dto.reason = stringValue(payload.get('r'));
    dto.decisionReason = stringValue(payload.get('d'));
    dto.submittedAt = row.Created_At__c;
    String expiry = stringValue(payload.get('x'));
    dto.expiresAt = parseDatetime(expiry);
    String versionId = stringValue(payload.get('cv'));
    if (
      !String.isBlank(versionId) &&
      (dto.expiresAt == null ||
      dto.expiresAt > System.now())
    )
      dto.downloadUrl = '/sfc/servlet.shepherd/version/download/' + versionId;
    return dto;
  }
  private static void validateReason(String reason) {
    if (String.isBlank(reason) || reason.trim().length() < 10)
      throw new AuraHandledException(
        'Provide at least 10 characters explaining this privacy request.'
      );
  }
  private static Map<String, Object> parse(String raw) {
    if (String.isBlank(raw))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }
  private static Datetime parseDatetime(String raw) {
    if (String.isBlank(raw))
      return null;
    try {
      return Datetime.valueOf(raw.replace('T', ' ').left(19));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
