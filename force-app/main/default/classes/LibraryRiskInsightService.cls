public without sharing class LibraryRiskInsightService {
  private static final String OPERATION = 'Risk Alert';
  private static final Integer WINDOW_DAYS = 90;
  private static final Integer WAIVER_THRESHOLD = 3;
  private static final Integer DEFECT_THRESHOLD = 2;

  public class AlertDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id subjectId;
    @AuraEnabled
    public String subjectName;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public Integer score;
    @AuraEnabled
    public String severity;
    @AuraEnabled
    public String evidence;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String reviewerNote;
    @AuraEnabled
    public Datetime createdAt;
  }

  public class RunDTO {
    @AuraEnabled
    public Integer created;
    @AuraEnabled
    public Integer existing;
    @AuraEnabled
    public Datetime processedAt;
  }

  private class Candidate {
    Id memberId;
    String category;
    Integer count;
    String evidence;
    Candidate(Id memberId, String category, Integer count, String evidence) {
      this.memberId = memberId;
      this.category = category;
      this.count = count;
      this.evidence = evidence;
    }
  }

  public static RunDTO scan() {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Datetime nowValue = System.now();
    Date windowStart = Date.today().addDays(-WINDOW_DAYS);
    List<Candidate> candidates = new List<Candidate>();
    Map<Id, Integer> waiverCounts = new Map<Id, Integer>();
    for (Fine__c fine : [
      SELECT Id, Member__c
      FROM Fine__c
      WHERE Status__c = 'Waived' AND Generated_Date__c >= :windowStart
      LIMIT 5000
    ]) {
      if (fine.Member__c == null)
        continue;
      waiverCounts.put(
        fine.Member__c,
        (waiverCounts.containsKey(fine.Member__c)
          ? waiverCounts.get(fine.Member__c)
          : 0) + 1
      );
    }
    for (Id memberId : waiverCounts.keySet()) {
      Integer count = waiverCounts.get(memberId);
      if (count >= WAIVER_THRESHOLD)
        candidates.add(
          new Candidate(
            memberId,
            'Frequent Fine Waivers',
            count,
            count + ' waived fines in the last ' + WINDOW_DAYS + ' days.'
          )
        );
    }
    Map<Id, Integer> defectCounts = new Map<Id, Integer>();
    for (Borrow_Record__c loan : [
      SELECT Id, Member__c
      FROM Borrow_Record__c
      WHERE
        Replacement_Required__c = TRUE
        AND Defect_Reported_Date__c >= :windowStart
      LIMIT 5000
    ]) {
      if (loan.Member__c == null)
        continue;
      defectCounts.put(
        loan.Member__c,
        (defectCounts.containsKey(loan.Member__c)
          ? defectCounts.get(loan.Member__c)
          : 0) + 1
      );
    }
    for (Id memberId : defectCounts.keySet()) {
      Integer count = defectCounts.get(memberId);
      if (count >= DEFECT_THRESHOLD)
        candidates.add(
          new Candidate(
            memberId,
            'Repeated Copy Damage',
            count,
            count +
              ' replacement-required loans in the last ' +
              WINDOW_DAYS +
              ' days.'
          )
        );
    }
    Set<Id> memberIds = new Set<Id>();
    for (Candidate candidate : candidates)
      memberIds.add(candidate.memberId);
    Map<Id, Member__c> members = memberIds.isEmpty()
      ? new Map<Id, Member__c>()
      : new Map<Id, Member__c>(
          [SELECT Id, Name FROM Member__c WHERE Id IN :memberIds]
        );
    RunDTO result = new RunDTO();
    result.created = 0;
    result.existing = 0;
    for (Candidate candidate : candidates) {
      String key = key(candidate, Date.today());
      List<Library_Scan_Transaction__c> existing = [
        SELECT Id
        FROM Library_Scan_Transaction__c
        WHERE Idempotency_Key__c = :key AND Operation__c = :OPERATION
        LIMIT 1
      ];
      if (!existing.isEmpty()) {
        result.existing++;
        continue;
      }
      Integer score = candidate.category == 'Frequent Fine Waivers'
        ? Math.min(100, candidate.count * 20)
        : Math.min(100, candidate.count * 25);
      Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
        Idempotency_Key__c = key,
        Operation__c = OPERATION,
        Member__c = candidate.memberId,
        Status__c = 'Open',
        Created_At__c = nowValue,
        Result_Message__c = JSON.serialize(
            new Map<String, Object>{
              'c' => candidate.category,
              's' => score,
              'v' => score >= 75 ? 'High' : 'Medium',
              'e' => candidate.evidence,
              'w' => String.valueOf(windowStart) +
              ' to ' +
              String.valueOf(Date.today())
            }
          )
          .left(255)
      );
      Database.insert(row, AccessLevel.SYSTEM_MODE);
      result.created++;
      LibraryOperationAuditService.record(
        'Risk Alert Created',
        'Manage_Library_Registrations',
        candidate.memberId,
        key,
        candidate.evidence,
        'Open',
        null,
        new Map<String, Object>{
          'category' => candidate.category,
          'score' => score
        }
      );
    }
    result.processedAt = nowValue;
    return result;
  }

  public static List<AlertDTO> getAll(String status) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Map<Id, Member__c> members = new Map<Id, Member__c>(
      [SELECT Id, Name FROM Member__c LIMIT 5000]
    );
    List<AlertDTO> result = new List<AlertDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Member__c, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 1000
    ]) {
      if (!String.isBlank(status) && row.Status__c != status)
        continue;
      if (row.Member__c == null || !members.containsKey(row.Member__c))
        continue;
      result.add(toDto(row, members.get(row.Member__c)));
    }
    return result;
  }

  public static void decide(Id alertId, String status, String reviewerNote) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    if (
      !new Set<String>{ 'Resolved', 'False Positive' }.contains(status) ||
      String.isBlank(reviewerNote) ||
      reviewerNote.trim().length() < 10
    )
      throw new AuraHandledException(
        'Choose Resolved or False Positive and provide at least 10 characters.'
      );
    Library_Scan_Transaction__c row = [
      SELECT Id, Member__c, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :alertId AND Operation__c = :OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (row.Status__c != 'Open')
      throw new AuraHandledException('Only open risk alerts can be reviewed.');
    Map<String, Object> payload = parse(row.Result_Message__c);
    payload.put('n', reviewerNote.trim().left(80));
    row.Result_Message__c = JSON.serialize(payload).left(255);
    row.Status__c = status;
    Database.update(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Risk Alert Decision',
      'Manage_Library_Registrations',
      row.Member__c,
      String.valueOf(row.Id),
      reviewerNote,
      status,
      new Map<String, Object>{ 'status' => 'Open' },
      new Map<String, Object>{
        'status' => status,
        'category' => payload.get('c')
      }
    );
  }

  private static AlertDTO toDto(
    Library_Scan_Transaction__c row,
    Member__c member
  ) {
    Map<String, Object> p = parse(row.Result_Message__c);
    AlertDTO dto = new AlertDTO();
    dto.id = row.Id;
    dto.subjectId = row.Member__c;
    dto.subjectName = member.Name;
    dto.category = stringValue(p.get('c'));
    dto.score = p.get('s') == null
      ? null
      : Integer.valueOf(String.valueOf(p.get('s')));
    dto.severity = stringValue(p.get('v'));
    dto.evidence = stringValue(p.get('e'));
    dto.reviewerNote = stringValue(p.get('n'));
    dto.status = row.Status__c;
    dto.createdAt = row.Created_At__c;
    return dto;
  }
  private static String key(Candidate candidate, Date day) {
    return 'RISK:' +
      candidate.category +
      ':' +
      String.valueOf(candidate.memberId) +
      ':' +
      String.valueOf(day);
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
