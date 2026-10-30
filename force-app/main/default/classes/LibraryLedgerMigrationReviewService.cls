public without sharing class LibraryLedgerMigrationReviewService {
  private static final String OPERATION = 'Ledger Migration Review';
  private static final String PERMISSION = 'Manage_Library_Circulation';

  public class ReviewDTO {
    @AuraEnabled
    public Id auditId;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String manifestVersion;
    @AuraEnabled
    public String reviewer;
    @AuraEnabled
    public String reviewNote;
    @AuraEnabled
    public Datetime reviewedAt;
  }

  public static ReviewDTO recordReview(
    String manifestVersion,
    Datetime generatedAt,
    String reviewNote,
    Integer totalRows,
    Integer migratableRows,
    Integer blockerCount
  ) {
    LibraryPolicyService.require(PERMISSION);
    String version = normalizeVersion(manifestVersion);
    if (generatedAt == null)
      throw new AuraHandledException('A manifest generation time is required.');
    String correlation =
      'LMR:' +
      version +
      ':' +
      String.valueOf(generatedAt.getTime()).right(8);
    Id auditId = LibraryOperationAuditService.record(
      OPERATION,
      PERMISSION,
      null,
      correlation,
      String.isBlank(reviewNote) ? 'Inventory reviewed.' : reviewNote,
      'Reviewed',
      null,
      null
    );
    ReviewDTO result = new ReviewDTO();
    result.auditId = auditId;
    result.status = 'Reviewed';
    result.manifestVersion = version;
    result.reviewer = UserInfo.getName();
    result.reviewNote = String.isBlank(reviewNote)
      ? 'Inventory reviewed.'
      : reviewNote.trim().left(40);
    result.reviewedAt = System.now();
    return result;
  }

  public static ReviewDTO getLatestReview() {
    LibraryPolicyService.require(PERMISSION);
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 200
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      if (stringValue(payload.get('o')) != OPERATION)
        continue;
      ReviewDTO result = new ReviewDTO();
      result.auditId = row.Id;
      result.status = stringValue(payload.get('z'));
      result.manifestVersion = manifestVersionFromCorrelation(
        stringValue(payload.get('c'))
      );
      result.reviewer = stringValue(payload.get('n'));
      result.reviewNote = stringValue(payload.get('r'));
      result.reviewedAt = row.Created_At__c;
      return result;
    }
    return null;
  }

  private static String normalizeVersion(String value) {
    if (String.isBlank(value))
      throw new AuraHandledException('A manifest version is required.');
    return value.trim().left(30);
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

  private static String manifestVersionFromCorrelation(String correlation) {
    String prefix = 'LMR:';
    if (String.isBlank(correlation) || !correlation.startsWith(prefix))
      return null;
    String remainder = correlation.substring(prefix.length());
    Integer separator = remainder.lastIndexOf(':');
    return separator > 0 ? remainder.substring(0, separator) : remainder;
  }
}
