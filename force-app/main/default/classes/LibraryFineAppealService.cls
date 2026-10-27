public without sharing class LibraryFineAppealService {
  private static final String OPERATION = 'Fine Appeal';
  public class AppealDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id fineId;
    @AuraEnabled
    public String fineName;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String decisionReason;
    @AuraEnabled
    public Datetime submittedAt;
  }

  public static AppealDTO submit(
    String sessionToken,
    Id fineId,
    String reason
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    if (fineId == null || String.isBlank(reason) || reason.trim().length() < 10)
      throw new AuraHandledException(
        'Select a fine and provide at least 10 characters explaining the appeal.'
      );
    Fine__c fine = fineRow(fineId, member.Id);
    if (fine.Status__c == 'Paid' || fine.Status__c == 'Waived')
      throw new AuraHandledException('This fine is no longer appealable.');
    String key =
      'FINE_APPEAL:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(fineId);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return toDto(existing[0], fine);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Member__c = member.Id,
      Status__c = 'Pending',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'f' => String.valueOf(fineId),
            'r' => reason.trim().left(150)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return toDto(row, fine);
  }

  public static List<AppealDTO> getMine(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    return getForMember(member.Id);
  }
  public static List<AppealDTO> getAll() {
    LibraryPolicyService.require('Manage_Library_Fines');
    Map<Id, Fine__c> fines = new Map<Id, Fine__c>(
      [SELECT Id, Name, Amount__c FROM Fine__c LIMIT 2000]
    );
    List<AppealDTO> result = new List<AppealDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 500
    ]) {
      Id fineId = parseId(parse(row.Result_Message__c).get('f'));
      if (fines.containsKey(fineId))
        result.add(toDto(row, fines.get(fineId)));
    }
    return result;
  }
  public static void decide(Id appealId, String status, String decisionReason) {
    LibraryPolicyService.require('Manage_Library_Fines');
    if (
      !new Set<String>{ 'Approved', 'Rejected' }.contains(status) ||
      String.isBlank(decisionReason)
    )
      throw new AuraHandledException(
        'Choose Approved or Rejected and provide a decision reason.'
      );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :appealId AND Operation__c = :OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty() || rows[0].Status__c != 'Pending')
      throw new AuraHandledException('This appeal is not pending review.');
    Map<String, Object> payload = parse(rows[0].Result_Message__c);
    payload.put('d', decisionReason.trim().left(100));
    rows[0].Result_Message__c = JSON.serialize(payload).left(255);
    rows[0].Status__c = status;
    Database.update(rows[0], AccessLevel.SYSTEM_MODE);
  }

  private static List<AppealDTO> getForMember(Id memberId) {
    Map<Id, Fine__c> fines = new Map<Id, Fine__c>(
      [
        SELECT Id, Name, Amount__c
        FROM Fine__c
        WHERE Member__c = :memberId
        LIMIT 500
      ]
    );
    List<AppealDTO> result = new List<AppealDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :memberId AND Operation__c = :OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 200
    ]) {
      Id fineId = parseId(parse(row.Result_Message__c).get('f'));
      if (fines.containsKey(fineId))
        result.add(toDto(row, fines.get(fineId)));
    }
    return result;
  }
  private static Fine__c fineRow(Id fineId, Id memberId) {
    List<Fine__c> rows = [
      SELECT Id, Name, Amount__c, Status__c
      FROM Fine__c
      WHERE Id = :fineId AND Member__c = :memberId
      LIMIT 1
    ];
    if (rows.isEmpty())
      throw new AuraHandledException(
        'The fine could not be found for this member.'
      );
    return rows[0];
  }
  private static AppealDTO toDto(
    Library_Scan_Transaction__c row,
    Fine__c fine
  ) {
    Map<String, Object> p = parse(row.Result_Message__c);
    AppealDTO dto = new AppealDTO();
    dto.id = row.Id;
    dto.fineId = fine.Id;
    dto.fineName = fine.Name;
    dto.amount = fine.Amount__c;
    dto.reason = stringValue(p.get('r'));
    dto.status = row.Status__c;
    dto.decisionReason = stringValue(p.get('d'));
    dto.submittedAt = row.Created_At__c;
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
