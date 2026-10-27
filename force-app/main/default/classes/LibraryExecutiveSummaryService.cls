public without sharing class LibraryExecutiveSummaryService {
  private static final String OPERATION = 'Executive Summary';

  public class SummaryDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Date reportingDate;
    @AuraEnabled
    public Datetime generatedAt;
    @AuraEnabled
    public Integer activeMembers;
    @AuraEnabled
    public Integer pendingRegistrations;
    @AuraEnabled
    public Integer activeLoans;
    @AuraEnabled
    public Integer overdueLoans;
    @AuraEnabled
    public Integer pendingReservations;
    @AuraEnabled
    public Integer unpaidFines;
    @AuraEnabled
    public Decimal unpaidFineBalance;
    @AuraEnabled
    public Integer openRiskAlerts;
    @AuraEnabled
    public Integer noShows;
  }

  public static SummaryDTO generate() {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Date reportDate = Date.today();
    String key = 'EXEC_SUMMARY:' + String.valueOf(reportDate);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION AND Idempotency_Key__c = :key
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return toDto(existing[0]);

    Datetime nowValue = System.now();
    SummaryDTO summary = new SummaryDTO();
    summary.reportingDate = reportDate;
    summary.generatedAt = nowValue;
    summary.activeMembers = [
      SELECT COUNT()
      FROM Member__c
      WHERE Status__c = 'Active'
    ];
    summary.pendingRegistrations = [
      SELECT COUNT()
      FROM Library_Registration__c
      WHERE Status__c = 'Pending'
    ];
    summary.activeLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Return_Date__c = NULL AND Status__c IN ('Active', 'Overdue')
    ];
    summary.overdueLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Return_Date__c = NULL AND Due_Date__c < :reportDate
    ];
    summary.pendingReservations = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE Status__c IN ('Pending', 'Ready')
    ];
    summary.unpaidFines = 0;
    summary.unpaidFineBalance = 0;
    for (Fine__c fine : [
      SELECT Balance__c
      FROM Fine__c
      WHERE Status__c IN ('Unpaid', 'Partially Paid')
      LIMIT 5000
    ]) {
      summary.unpaidFines++;
      summary.unpaidFineBalance += fine.Balance__c == null
        ? 0
        : fine.Balance__c;
    }
    summary.openRiskAlerts = [
      SELECT COUNT()
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = 'Risk Alert' AND Status__c = 'Open'
    ];
    summary.noShows = [
      SELECT COUNT()
      FROM Library_Scan_Transaction__c
      WHERE Status__c = 'No-show' AND Created_At__c = LAST_N_DAYS:90
    ];
    Map<String, Object> payload = new Map<String, Object>{
      'd' => String.valueOf(summary.reportingDate),
      'm' => summary.activeMembers,
      'r' => summary.pendingRegistrations,
      'l' => summary.activeLoans,
      'o' => summary.overdueLoans,
      'q' => summary.pendingReservations,
      'f' => summary.unpaidFines,
      'b' => summary.unpaidFineBalance,
      'a' => summary.openRiskAlerts,
      'n' => summary.noShows
    };
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Status__c = 'Completed',
      Created_At__c = nowValue,
      Result_Message__c = JSON.serialize(payload).left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    summary.id = row.Id;
    LibraryOperationAuditService.record(
      'Executive Summary Generated',
      'Manage_Library_Registrations',
      null,
      key,
      'Daily aggregate reporting snapshot',
      'Completed',
      null,
      payload
    );
    return summary;
  }

  public static List<SummaryDTO> getRecent(Integer limitSize) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Integer size = limitSize == null ||
      limitSize < 1
      ? 30
      : Math.min(limitSize, 100);
    List<SummaryDTO> result = new List<SummaryDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 100
    ]) {
      result.add(toDto(row));
      if (result.size() >= size)
        break;
    }
    return result;
  }

  private static SummaryDTO toDto(Library_Scan_Transaction__c row) {
    Map<String, Object> p = parse(row.Result_Message__c);
    SummaryDTO summary = new SummaryDTO();
    summary.id = row.Id;
    summary.generatedAt = row.Created_At__c;
    summary.reportingDate = parseDate(p.get('d'));
    summary.activeMembers = integerValue(p.get('m'));
    summary.pendingRegistrations = integerValue(p.get('r'));
    summary.activeLoans = integerValue(p.get('l'));
    summary.overdueLoans = integerValue(p.get('o'));
    summary.pendingReservations = integerValue(p.get('q'));
    summary.unpaidFines = integerValue(p.get('f'));
    summary.unpaidFineBalance = decimalValue(p.get('b'));
    summary.openRiskAlerts = integerValue(p.get('a'));
    summary.noShows = integerValue(p.get('n'));
    return summary;
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
  private static Integer integerValue(Object value) {
    try {
      return value == null ? 0 : Integer.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return 0;
    }
  }
  private static Decimal decimalValue(Object value) {
    try {
      return value == null ? 0 : Decimal.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return 0;
    }
  }
}
