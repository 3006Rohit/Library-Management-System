public without sharing class LibraryStocktakeService {
  private static final String AUDIT_OPERATION = 'Stocktake Audit';
  private static final String LINE_OPERATION = 'Stocktake Line';

  public class AuditDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String scope;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer scanned;
    @AuraEnabled
    public Integer discrepancies;
    @AuraEnabled
    public Datetime startedAt;
    @AuraEnabled
    public Datetime closedAt;
  }
  public class LineDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id auditId;
    @AuraEnabled
    public String barcode;
    @AuraEnabled
    public String copyName;
    @AuraEnabled
    public String expectedStatus;
    @AuraEnabled
    public String observedStatus;
    @AuraEnabled
    public Boolean discrepancy;
    @AuraEnabled
    public String note;
    @AuraEnabled
    public Datetime scannedAt;
  }

  public static AuditDTO start(String name, String scope) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(name))
      throw new AuraHandledException('An audit name is required.');
    String key =
      'STOCKTAKE:' +
      name.trim().left(60) +
      ':' +
      DateTime.now().getTime();
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = AUDIT_OPERATION,
      Status__c = 'Open',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'n' => name.trim().left(80),
            's' => String.isBlank(scope)
              ? 'All inventory'
              : scope.trim().left(100),
            'c' => 0,
            'd' => 0
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return toAudit(row);
  }

  public static LineDTO scan(
    Id auditId,
    String barcode,
    String observedStatus,
    String note
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (auditId == null || String.isBlank(barcode))
      throw new AuraHandledException('Choose an audit and scan a barcode.');
    Library_Scan_Transaction__c audit = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :auditId AND Operation__c = :AUDIT_OPERATION
      LIMIT 1
    ];
    if (audit.Status__c != 'Open')
      throw new AuraHandledException(
        'Only an open stocktake can receive scans.'
      );
    Book_Copy__c copy = [
      SELECT Id, Name, Barcode__c, Status__c
      FROM Book_Copy__c
      WHERE Barcode__c = :barcode.trim()
      LIMIT 1
    ];
    String key = 'STOCKTAKE_LINE:' + String.valueOf(auditId) + ':' + copy.Id;
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :LINE_OPERATION AND Idempotency_Key__c = :key
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return toLine(existing[0], auditId, copy);
    String observed = String.isBlank(observedStatus)
      ? copy.Status__c
      : observedStatus.trim();
    Boolean discrepancy = observed != copy.Status__c;
    Library_Scan_Transaction__c line = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = LINE_OPERATION,
      Status__c = discrepancy ? 'Discrepancy' : 'Matched',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'a' => auditId,
            'b' => copy.Barcode__c,
            'c' => copy.Status__c,
            'o' => observed,
            'n' => String.isBlank(note) ? null : note.trim().left(80)
          }
        )
        .left(255)
    );
    Database.insert(line, AccessLevel.SYSTEM_MODE);
    updateAuditCounts(auditId);
    return toLine(line, auditId, copy);
  }

  public static void close(Id auditId, String summary) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(summary) || summary.trim().length() < 10)
      throw new AuraHandledException(
        'Provide a closing summary of at least 10 characters.'
      );
    Library_Scan_Transaction__c audit = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :auditId AND Operation__c = :AUDIT_OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (audit.Status__c != 'Open')
      throw new AuraHandledException('This stocktake is already closed.');
    Map<String, Object> payload = parse(audit.Result_Message__c);
    payload.put('x', summary.trim().left(100));
    payload.put('t', String.valueOf(System.now()));
    audit.Result_Message__c = JSON.serialize(payload).left(255);
    audit.Status__c = 'Closed';
    Database.update(audit, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Stocktake Closed',
      'Manage_Library_Catalog',
      null,
      String.valueOf(audit.Id),
      summary,
      'Closed',
      null,
      payload
    );
  }

  public static List<AuditDTO> getAudits() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    List<AuditDTO> result = new List<AuditDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :AUDIT_OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 100
    ])
      result.add(toAudit(row));
    return result;
  }
  public static List<LineDTO> getLines(Id auditId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Map<Id, Book_Copy__c> copies = new Map<Id, Book_Copy__c>();
    List<LineDTO> result = new List<LineDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :LINE_OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 1000
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      if (String.valueOf(payload.get('a')) != String.valueOf(auditId))
        continue;
      Id copyId = findCopyId(String.valueOf(payload.get('b')));
      Book_Copy__c copy = copyId == null
        ? null
        : [
            SELECT Id, Name, Barcode__c, Status__c
            FROM Book_Copy__c
            WHERE Id = :copyId
            LIMIT 1
          ];
      result.add(toLine(row, auditId, copy));
    }
    return result;
  }
  private static void updateAuditCounts(Id auditId) {
    Integer scanned = 0;
    Integer discrepancies = 0;
    for (Library_Scan_Transaction__c line : [
      SELECT Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :LINE_OPERATION
      LIMIT 1000
    ]) {
      Map<String, Object> p = parse(line.Result_Message__c);
      if (String.valueOf(p.get('a')) != String.valueOf(auditId))
        continue;
      scanned++;
      if (line.Status__c == 'Discrepancy')
        discrepancies++;
    }
    Library_Scan_Transaction__c audit = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :auditId
      LIMIT 1
      FOR UPDATE
    ];
    Map<String, Object> p = parse(audit.Result_Message__c);
    p.put('c', scanned);
    p.put('d', discrepancies);
    audit.Result_Message__c = JSON.serialize(p).left(255);
    update audit;
  }
  private static Id findCopyId(String barcode) {
    List<Book_Copy__c> rows = [
      SELECT Id
      FROM Book_Copy__c
      WHERE Barcode__c = :barcode
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0].Id;
  }
  private static AuditDTO toAudit(Library_Scan_Transaction__c row) {
    Map<String, Object> p = parse(row.Result_Message__c);
    AuditDTO dto = new AuditDTO();
    dto.id = row.Id;
    dto.name = stringValue(p.get('n'));
    dto.scope = stringValue(p.get('s'));
    dto.status = row.Status__c;
    dto.scanned = integerValue(p.get('c'));
    dto.discrepancies = integerValue(p.get('d'));
    dto.startedAt = row.Created_At__c;
    dto.closedAt = parseDateTime(p.get('t'));
    return dto;
  }
  private static LineDTO toLine(
    Library_Scan_Transaction__c row,
    Id auditId,
    Book_Copy__c copy
  ) {
    Map<String, Object> p = parse(row.Result_Message__c);
    LineDTO dto = new LineDTO();
    dto.id = row.Id;
    dto.auditId = auditId;
    dto.barcode = stringValue(p.get('b'));
    dto.copyName = copy == null ? null : copy.Name;
    dto.expectedStatus = stringValue(p.get('c'));
    dto.observedStatus = stringValue(p.get('o'));
    dto.discrepancy = row.Status__c == 'Discrepancy';
    dto.note = stringValue(p.get('n'));
    dto.scannedAt = row.Created_At__c;
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
  private static Integer integerValue(Object value) {
    try {
      return value == null ? 0 : Integer.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return 0;
    }
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
