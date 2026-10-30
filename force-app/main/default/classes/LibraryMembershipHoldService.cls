public without sharing class LibraryMembershipHoldService {
  private static final String OPERATION = 'Membership Hold';
  private static final Integer MAX_DAYS = 90;
  private static final Integer GRACE_DAYS = 7;
  private static final String POLICY_VERSION = 'membership-hold-v1';

  public class HoldDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public Date originalEndDate;
    @AuraEnabled
    public Date adjustedEndDate;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String decisionReason;
    @AuraEnabled
    public String policyVersion;
    @AuraEnabled
    public Datetime submittedAt;
  }

  public class MembershipStatusDTO {
    @AuraEnabled
    public Date membershipEndDate;
    @AuraEnabled
    public Date gracePeriodEndsOn;
    @AuraEnabled
    public Boolean graceActive;
    @AuraEnabled
    public Boolean borrowingAllowed;
  }

  public static HoldDTO submit(
    String sessionToken,
    Date startDate,
    Date endDate,
    String reason
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    validateDates(startDate, endDate, reason);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :key(member.Id, startDate, endDate)
        AND Member__c = :member.Id WITH SYSTEM_MODE LIMIT 1
    ];
    if (!existing.isEmpty())
      return toDto(existing[0], member);
    ensureNoOverlap(member.Id, startDate, endDate, null);
    Map<String, Object> payload = new Map<String, Object>{
      's' => String.valueOf(startDate),
      'e' => String.valueOf(endDate),
      'r' => reason.trim().left(120),
      'o' => member.Membership_End_Date__c == null
        ? null
        : String.valueOf(member.Membership_End_Date__c),
      'p' => POLICY_VERSION
    };
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key(member.Id, startDate, endDate),
      Operation__c = OPERATION,
      Member__c = member.Id,
      Status__c = 'Pending',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(payload).left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return toDto(row, member);
  }

  public static List<HoldDTO> getMine(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    return getForMember(member.Id);
  }

  public static MembershipStatusDTO getStatus(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    MembershipStatusDTO result = new MembershipStatusDTO();
    result.membershipEndDate = member.Membership_End_Date__c;
    result.gracePeriodEndsOn = member.Membership_End_Date__c == null
      ? null
      : member.Membership_End_Date__c.addDays(GRACE_DAYS);
    result.graceActive =
      member.Membership_End_Date__c != null &&
      Date.today() > member.Membership_End_Date__c &&
      Date.today() <= result.gracePeriodEndsOn;
    result.borrowingAllowed =
      member.Membership_End_Date__c != null &&
      Date.today() <= member.Membership_End_Date__c;
    return result;
  }

  public static void cancel(String sessionToken, Id holdId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :holdId
        AND Member__c = :member.Id
        AND Operation__c = :OPERATION WITH SYSTEM_MODE LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty() || rows[0].Status__c != 'Pending')
      throw new AuraHandledException(
        'Only pending membership holds can be cancelled.'
      );
    rows[0].Status__c = 'Cancelled';
    Database.update(rows[0], AccessLevel.SYSTEM_MODE);
  }

  public static List<HoldDTO> getAll() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Map<Id, Member__c> members = new Map<Id, Member__c>(
      [
        SELECT Id, Name, Membership_End_Date__c
        FROM Member__c WITH SYSTEM_MODE LIMIT 5000
      ]
    );
    List<HoldDTO> result = new List<HoldDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION WITH SYSTEM_MODE ORDER BY Created_At__c DESC
      LIMIT 1000
    ]) {
      if (members.containsKey(row.Member__c))
        result.add(toDto(row, members.get(row.Member__c)));
    }
    return result;
  }

  public static void decide(Id holdId, String status, String decisionReason) {
    LibraryPolicyService.require('Manage_Library_Circulation');
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
      WHERE Id = :holdId AND Operation__c = :OPERATION WITH SYSTEM_MODE LIMIT 1
      FOR UPDATE
    ];
    if (row.Status__c != 'Pending')
      throw new AuraHandledException(
        'This membership hold is not pending review.'
      );
    Map<String, Object> payload = parse(row.Result_Message__c);
    Date startDate = parseDate(payload.get('s'));
    Date endDate = parseDate(payload.get('e'));
    Member__c member = [
      SELECT Id, Name, Membership_End_Date__c
      FROM Member__c
      WHERE Id = :row.Member__c WITH SYSTEM_MODE LIMIT 1
      FOR UPDATE
    ];
    Date beforeMembershipEndDate = member.Membership_End_Date__c;
    if (status == 'Approved') {
      ensureNoOverlap(member.Id, startDate, endDate, row.Id);
      if (member.Membership_End_Date__c == null)
        throw new AuraHandledException(
          'The member has no membership end date to extend.'
        );
      Integer duration = startDate.daysBetween(endDate) + 1;
      Date adjusted = member.Membership_End_Date__c.addDays(duration);
      payload.put('o', String.valueOf(member.Membership_End_Date__c));
      payload.put('a', String.valueOf(adjusted));
      member.Membership_End_Date__c = adjusted;
      Database.update(member, AccessLevel.SYSTEM_MODE);
    }
    payload.put('d', decisionReason.trim().left(120));
    row.Result_Message__c = JSON.serialize(payload).left(255);
    row.Status__c = status;
    Database.update(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Membership Hold Decision',
      'Manage_Library_Circulation',
      row.Member__c,
      String.valueOf(row.Id),
      decisionReason,
      status,
      new Map<String, Object>{
        'status' => 'Pending',
        'membershipEndDate' => beforeMembershipEndDate
      },
      new Map<String, Object>{
        'status' => status,
        'membershipEndDate' => member.Membership_End_Date__c,
        'adjustedEndDate' => payload.get('a')
      }
    );
  }

  private static List<HoldDTO> getForMember(Id memberId) {
    Member__c member = [
      SELECT Id, Name, Membership_End_Date__c
      FROM Member__c
      WHERE Id = :memberId WITH SYSTEM_MODE LIMIT 1
    ];
    List<HoldDTO> result = new List<HoldDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :memberId AND Operation__c = :OPERATION WITH SYSTEM_MODE ORDER BY Created_At__c DESC
      LIMIT 200
    ])
      result.add(toDto(row, member));
    return result;
  }

  private static HoldDTO toDto(
    Library_Scan_Transaction__c row,
    Member__c member
  ) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    HoldDTO dto = new HoldDTO();
    dto.id = row.Id;
    dto.memberId = row.Member__c;
    dto.memberName = member.Name;
    dto.startDate = parseDate(payload.get('s'));
    dto.endDate = parseDate(payload.get('e'));
    dto.originalEndDate = parseDate(payload.get('o'));
    dto.adjustedEndDate = parseDate(payload.get('a'));
    dto.reason = stringValue(payload.get('r'));
    dto.decisionReason = stringValue(payload.get('d'));
    dto.policyVersion = stringValue(payload.get('p'));
    dto.status = row.Status__c;
    dto.submittedAt = row.Created_At__c;
    return dto;
  }

  private static void validateDates(
    Date startDate,
    Date endDate,
    String reason
  ) {
    if (
      startDate == null ||
      endDate == null ||
      startDate < Date.today() ||
      endDate < startDate
    )
      throw new AuraHandledException(
        'Choose a future start date and an end date after it.'
      );
    if (startDate.daysBetween(endDate) + 1 > MAX_DAYS)
      throw new AuraHandledException(
        'A membership hold can be at most 90 days.'
      );
    if (String.isBlank(reason) || reason.trim().length() < 10)
      throw new AuraHandledException(
        'Provide at least 10 characters explaining the hold.'
      );
  }

  private static void ensureNoOverlap(
    Id memberId,
    Date startDate,
    Date endDate,
    Id excludedId
  ) {
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Member__c = :memberId
        AND Operation__c = :OPERATION
        AND Status__c IN ('Pending', 'Approved') WITH SYSTEM_MODE LIMIT 500
    ]) {
      if (excludedId != null && row.Id == excludedId)
        continue;
      Map<String, Object> p = parse(row.Result_Message__c);
      Date existingStart = parseDate(p.get('s'));
      Date existingEnd = parseDate(p.get('e'));
      if (
        existingStart != null &&
        existingEnd != null &&
        existingStart <= endDate &&
        startDate <= existingEnd
      )
        throw new AuraHandledException(
          'This date range overlaps another open membership hold.'
        );
    }
  }

  private static String key(Id memberId, Date startDate, Date endDate) {
    return 'MEMBER_HOLD:' +
      String.valueOf(memberId) +
      ':' +
      String.valueOf(startDate) +
      ':' +
      String.valueOf(endDate);
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
  private static Date parseDate(Object value) {
    try {
      return value == null ? null : Date.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
