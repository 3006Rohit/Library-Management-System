public without sharing class LibraryOperationAuditService {
  private static final String OPERATION = 'Operation Audit';

  public class AuditDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String actorId;
    @AuraEnabled
    public String actorName;
    @AuraEnabled
    public String permissionContext;
    @AuraEnabled
    public String operation;
    @AuraEnabled
    public String targetId;
    @AuraEnabled
    public String correlationId;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String result;
    @AuraEnabled
    public String beforeDigest;
    @AuraEnabled
    public String afterDigest;
    @AuraEnabled
    public Datetime createdAt;
  }

  public static Id record(
    String operation,
    String permissionContext,
    Id targetId,
    String correlationId,
    String reason,
    String result,
    Map<String, Object> beforeState,
    Map<String, Object> afterState
  ) {
    String safeOperation = String.isBlank(operation)
      ? 'Unspecified'
      : operation.trim().left(30);
    String safeCorrelation = String.isBlank(correlationId)
      ? safeOperation + ':' + String.valueOf(Crypto.getRandomLong())
      : correlationId.trim().left(32);
    String key = 'AUDIT:' + safeOperation + ':' + shortHash(safeCorrelation);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Operation__c = :OPERATION
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return existing[0].Id;
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Status__c = 'Recorded',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'a' => UserInfo.getUserId(),
            'n' => UserInfo.getName(),
            'p' => String.isBlank(permissionContext)
              ? null
              : permissionContext.trim().left(35),
            'o' => safeOperation,
            't' => targetId == null ? null : String.valueOf(targetId),
            'c' => safeCorrelation,
            'r' => String.isBlank(reason) ? null : reason.trim().left(40),
            'z' => String.isBlank(result) ? null : result.trim().left(20),
            'b' => digest(beforeState),
            'f' => digest(afterState)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return row.Id;
  }

  public static List<AuditDTO> getRecent(
    String operation,
    Id targetId,
    Integer limitSize
  ) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Integer size = limitSize == null ||
      limitSize < 1
      ? 100
      : Math.min(limitSize, 500);
    String target = targetId == null ? null : String.valueOf(targetId);
    List<AuditDTO> result = new List<AuditDTO>();
    String operationFilter = String.isBlank(operation)
      ? null
      : operation.trim();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 500
    ]) {
      AuditDTO dto = toDto(row);
      if (operationFilter != null && dto.operation != operationFilter)
        continue;
      if (target != null && dto.targetId != target)
        continue;
      result.add(dto);
      if (result.size() >= size)
        break;
    }
    return result;
  }

  private static AuditDTO toDto(Library_Scan_Transaction__c row) {
    Map<String, Object> p = parse(row.Result_Message__c);
    AuditDTO dto = new AuditDTO();
    dto.id = row.Id;
    dto.actorId = stringValue(p.get('a'));
    dto.actorName = stringValue(p.get('n'));
    dto.permissionContext = stringValue(p.get('p'));
    dto.operation = stringValue(p.get('o'));
    dto.targetId = stringValue(p.get('t'));
    dto.correlationId = stringValue(p.get('c'));
    dto.reason = stringValue(p.get('r'));
    dto.result = stringValue(p.get('z'));
    dto.beforeDigest = stringValue(p.get('b'));
    dto.afterDigest = stringValue(p.get('f'));
    dto.createdAt = row.Created_At__c;
    return dto;
  }

  private static String digest(Map<String, Object> state) {
    if (state == null || state.isEmpty())
      return null;
    Map<String, Object> safe = new Map<String, Object>();
    for (String key : state.keySet()) {
      String lowered = key == null ? '' : key.toLowerCase();
      if (
        lowered.contains('password') ||
        lowered.contains('token') ||
        lowered.contains('secret') ||
        lowered.contains('hash')
      )
        continue;
      safe.put(key, state.get(key));
    }
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(JSON.serialize(safe)))
      )
      .left(16);
  }
  private static String shortHash(String value) {
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(value))
      )
      .left(32);
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
}
