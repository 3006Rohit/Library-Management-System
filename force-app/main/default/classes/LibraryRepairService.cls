public without sharing class LibraryRepairService {
  private static final String OPERATION = 'Copy Repair';

  public class RepairDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id copyId;
    @AuraEnabled
    public String copyName;
    @AuraEnabled
    public String barcode;
    @AuraEnabled
    public String previousStatus;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String resolution;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime openedAt;
    @AuraEnabled
    public Datetime resolvedAt;
  }

  public static RepairDTO open(Id copyId, String reason) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (copyId == null || String.isBlank(reason) || reason.trim().length() < 10)
      throw new AuraHandledException(
        'Choose a copy and provide at least 10 characters describing the issue.'
      );
    Book_Copy__c copy = [
      SELECT Id, Name, Barcode__c, Status__c, Condition__c
      FROM Book_Copy__c
      WHERE Id = :copyId
      LIMIT 1
      FOR UPDATE
    ];
    if (copy.Status__c == 'Borrowed')
      throw new AuraHandledException(
        'A borrowed copy must be returned through circulation before repair.'
      );
    if (
      !new Set<String>{ 'Damaged', 'Lost', 'Maintenance' }
        .contains(copy.Status__c)
    )
      throw new AuraHandledException(
        'Only damaged, lost, or maintenance copies can open a repair case.'
      );
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION AND Status__c = 'Open'
      LIMIT 500
    ];
    for (Library_Scan_Transaction__c row : existing)
      if (
        String.valueOf(parse(row.Result_Message__c).get('c')) ==
        String.valueOf(copy.Id)
      )
        return toDto(row, copy);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'REPAIR:' + String.valueOf(copy.Id),
      Operation__c = OPERATION,
      Status__c = 'Open',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'c' => copy.Id,
            'b' => copy.Barcode__c,
            'p' => copy.Status__c,
            'r' => reason.trim().left(100)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    update new Book_Copy__c(Id = copy.Id, Status__c = 'Maintenance');
    LibraryOperationAuditService.record(
      'Copy Repair Opened',
      'Manage_Library_Catalog',
      copy.Id,
      String.valueOf(row.Id),
      reason,
      'Open',
      new Map<String, Object>{ 'status' => copy.Status__c },
      new Map<String, Object>{ 'status' => 'Maintenance' }
    );
    return toDto(row, copy);
  }

  public static RepairDTO openByBarcode(String barcode, String reason) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(barcode)) {
      throw new AuraHandledException('Scan or enter a copy barcode.');
    }
    List<Book_Copy__c> copies = [
      SELECT Id
      FROM Book_Copy__c
      WHERE Barcode__c = :barcode.trim()
      LIMIT 1
    ];
    if (copies.isEmpty()) {
      throw new AuraHandledException('No copy was found for that barcode.');
    }
    return open(copies[0].Id, reason);
  }

  public static void resolve(
    Id repairId,
    String resolution,
    String status,
    String note
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (
      !new Set<String>{ 'Repaired', 'Unrepairable' }.contains(status) ||
      String.isBlank(note) ||
      note.trim().length() < 10
    )
      throw new AuraHandledException(
        'Choose Repaired or Unrepairable and provide at least 10 characters of resolution notes.'
      );
    Library_Scan_Transaction__c row = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :repairId AND Operation__c = :OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (row.Status__c != 'Open')
      throw new AuraHandledException('Only open repair cases can be resolved.');
    Map<String, Object> payload = parse(row.Result_Message__c);
    Id copyId = (Id) payload.get('c');
    Book_Copy__c copy = [
      SELECT Id, Name, Barcode__c, Status__c
      FROM Book_Copy__c
      WHERE Id = :copyId
      LIMIT 1
      FOR UPDATE
    ];
    String nextStatus = status == 'Repaired' ? 'Available' : 'Retired';
    update new Book_Copy__c(
      Id = copy.Id,
      Status__c = nextStatus,
      Condition__c = status == 'Repaired' ? 'Good' : 'Poor'
    );
    payload.put('x', resolution == null ? null : resolution.trim().left(80));
    payload.put('n', note.trim().left(100));
    payload.put('t', String.valueOf(System.now()));
    row.Result_Message__c = JSON.serialize(payload).left(255);
    row.Status__c = status;
    Database.update(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Copy Repair Resolved',
      'Manage_Library_Catalog',
      copy.Id,
      String.valueOf(row.Id),
      note,
      status,
      new Map<String, Object>{ 'status' => 'Maintenance' },
      new Map<String, Object>{ 'status' => nextStatus }
    );
  }

  public static List<RepairDTO> getAll(String status) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    List<RepairDTO> result = new List<RepairDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 500
    ]) {
      if (!String.isBlank(status) && row.Status__c != status)
        continue;
      Map<String, Object> p = parse(row.Result_Message__c);
      Id copyId = (Id) p.get('c');
      List<Book_Copy__c> copies = [
        SELECT Id, Name, Barcode__c, Status__c
        FROM Book_Copy__c
        WHERE Id = :copyId
        LIMIT 1
      ];
      if (!copies.isEmpty())
        result.add(toDto(row, copies[0]));
    }
    return result;
  }
  private static RepairDTO toDto(
    Library_Scan_Transaction__c row,
    Book_Copy__c copy
  ) {
    Map<String, Object> p = parse(row.Result_Message__c);
    RepairDTO dto = new RepairDTO();
    dto.id = row.Id;
    dto.copyId = copy.Id;
    dto.copyName = copy.Name;
    dto.barcode = copy.Barcode__c;
    dto.previousStatus = stringValue(p.get('p'));
    dto.reason = stringValue(p.get('r'));
    dto.resolution = stringValue(p.get('x'));
    dto.status = row.Status__c;
    dto.openedAt = row.Created_At__c;
    dto.resolvedAt = parseDateTime(p.get('t'));
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
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
  private static Datetime parseDateTime(Object value) {
    try {
      return value == null
        ? null
        : Datetime.valueOf(String.valueOf(value).replace('T', ' ').left(19));
    } catch (Exception ignored) {
      return null;
    }
  }
}
