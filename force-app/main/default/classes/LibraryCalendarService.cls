public without sharing class LibraryCalendarService {
  private static final String OPERATION = 'Library Closure';
  private static final Integer MAX_LOOKAHEAD_DAYS = 370;

  public class ClosureDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id branchId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public String timezone;
    @AuraEnabled
    public Boolean emergency;
    @AuraEnabled
    public String status;
  }

  public static Id createClosure(
    String name,
    Date startDate,
    Date endDate,
    Id branchId,
    String timezone,
    Boolean emergency
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    validate(name, startDate, endDate);
    if (branchId != null)
      verifyBranch(branchId);
    String key =
      'CLOSURE:' +
      String.valueOf(branchId) +
      ':' +
      String.valueOf(startDate) +
      ':' +
      String.valueOf(endDate);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Operation__c = :OPERATION
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return existing[0].Id;
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Status__c = 'Active',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'n' => name.trim().left(80),
            's' => String.valueOf(startDate),
            'e' => String.valueOf(endDate),
            'b' => branchId == null ? null : String.valueOf(branchId),
            't' => String.isBlank(timezone) ? 'UTC' : timezone.trim().left(40),
            'x' => emergency == true
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Closure Published',
      'Manage_Library_Catalog',
      branchId,
      key,
      name,
      emergency == true ? 'Emergency' : 'Planned',
      null,
      new Map<String, Object>{
        'startDate' => startDate,
        'endDate' => endDate,
        'timezone' => timezone
      }
    );
    return row.Id;
  }

  public static List<ClosureDTO> getClosures() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    List<ClosureDTO> result = new List<ClosureDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION AND Status__c = 'Active'
      ORDER BY Created_At__c DESC
      LIMIT 500
    ])
      result.add(toDto(row));
    return result;
  }

  public static Date calculateDueDate(
    Date baseDate,
    Integer durationDays,
    Id branchId
  ) {
    if (baseDate == null || durationDays == null || durationDays < 1)
      throw new AuraHandledException(
        'A valid start date and duration are required.'
      );
    Date candidate = baseDate.addDays(durationDays);
    return nextOpenDate(candidate, branchId);
  }

  public static Datetime calculateDueDate(
    Datetime baseDate,
    Integer durationDays,
    Id branchId
  ) {
    if (baseDate == null)
      throw new AuraHandledException(
        'A valid start date and duration are required.'
      );
    Datetime candidate = baseDate.addDays(durationDays);
    Date openDate = nextOpenDate(candidate.date(), branchId);
    Integer shiftDays = candidate.date().daysBetween(openDate);
    return shiftDays == 0 ? candidate : candidate.addDays(shiftDays);
  }

  public static Date nextOpenDate(Date candidate, Id branchId) {
    if (candidate == null)
      return null;
    verifyOptionalBranch(branchId);
    List<Library_Scan_Transaction__c> closures = [
      SELECT Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION AND Status__c = 'Active'
      LIMIT 500
    ];
    for (Integer offset = 0; offset <= MAX_LOOKAHEAD_DAYS; offset++) {
      Date day = candidate.addDays(offset);
      if (!isClosed(day, branchId, closures))
        return day;
    }
    throw new AuraHandledException(
      'No open library date was found in the next year.'
    );
  }

  private static Boolean isClosed(
    Date day,
    Id branchId,
    List<Library_Scan_Transaction__c> closures
  ) {
    for (Library_Scan_Transaction__c row : closures) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      Date startDate = parseDate(payload.get('s'));
      Date endDate = parseDate(payload.get('e'));
      Id closureBranch = parseId(payload.get('b'));
      if (
        startDate != null &&
        endDate != null &&
        startDate <= day &&
        day <= endDate &&
        (closureBranch == null ||
        closureBranch == branchId)
      )
        return true;
    }
    return false;
  }

  private static void validate(String name, Date startDate, Date endDate) {
    if (
      String.isBlank(name) ||
      startDate == null ||
      endDate == null ||
      endDate < startDate
    )
      throw new AuraHandledException(
        'Closure name and a valid date range are required.'
      );
    if (startDate.daysBetween(endDate) > 366)
      throw new AuraHandledException(
        'A closure cannot span more than one year.'
      );
  }
  private static void verifyOptionalBranch(Id branchId) {
    if (branchId != null)
      verifyBranch(branchId);
  }
  private static void verifyBranch(Id branchId) {
    if (
      [
        SELECT COUNT()
        FROM Library_Scan_Transaction__c
        WHERE
          Id = :branchId
          AND Operation__c = 'Library Branch'
          AND Status__c = 'Active'
      ] == 0
    )
      throw new AuraHandledException('The branch could not be found.');
  }
  private static ClosureDTO toDto(Library_Scan_Transaction__c row) {
    Map<String, Object> p = parse(row.Result_Message__c);
    ClosureDTO dto = new ClosureDTO();
    dto.id = row.Id;
    dto.name = stringValue(p.get('n'));
    dto.startDate = parseDate(p.get('s'));
    dto.endDate = parseDate(p.get('e'));
    dto.branchId = parseId(p.get('b'));
    dto.timezone = stringValue(p.get('t'));
    dto.emergency = p.get('x') == true;
    dto.status = row.Status__c;
    return dto;
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
  private static Id parseId(Object value) {
    try {
      return value == null ? null : Id.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
