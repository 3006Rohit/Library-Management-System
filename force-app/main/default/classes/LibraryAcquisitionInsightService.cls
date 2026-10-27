public without sharing class LibraryAcquisitionInsightService {
  public class RecommendationDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id bookId;
    @AuraEnabled
    public String bookTitle;
    @AuraEnabled
    public String recommendationType;
    @AuraEnabled
    public Decimal score;
    @AuraEnabled
    public String confidence;
    @AuraEnabled
    public String evidence;
    @AuraEnabled
    public Integer recommendedQuantity;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Date evidenceWindowStart;
    @AuraEnabled
    public Date evidenceWindowEnd;
    @AuraEnabled
    public Datetime refreshedAt;
    @AuraEnabled
    public Integer reservations;
    @AuraEnabled
    public Integer availableCopies;
    @AuraEnabled
    public Integer recentCheckouts;
    @AuraEnabled
    public Integer damagedCopies;
    @AuraEnabled
    public Integer agingCopies;
    @AuraEnabled
    public Boolean insufficientEvidence;
  }

  private class Signal {
    Integer reservations = 0;
    Integer recentCheckouts = 0;
    Integer damagedCopies = 0;
    Integer agingCopies = 0;
  }

  public static List<RecommendationDTO> getRecommendations() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Date windowStart = Date.today().addDays(-90);
    Date windowEnd = Date.today();
    Datetime refreshedAt = System.now();
    List<Book__c> books = [
      SELECT Id, Name, Total_Copies__c, Available_Copies__c
      FROM Book__c
      WHERE Status__c != 'Archived'
      ORDER BY Name
      LIMIT 500
    ];
    Map<Id, Signal> signals = new Map<Id, Signal>();
    for (Book__c book : books)
      signals.put(book.Id, new Signal());
    for (AggregateResult row : [
      SELECT Book__c bookId, COUNT(Id) countValue
      FROM Reservation__c
      WHERE Book__c != NULL AND Status__c IN ('Pending', 'Ready')
      GROUP BY Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).reservations = Integer.valueOf(
          row.get('countValue')
        );
    }
    for (AggregateResult row : [
      SELECT Book_Copy__r.Book__c bookId, COUNT(Id) countValue
      FROM Borrow_Record__c
      WHERE Book_Copy__r.Book__c != NULL AND Borrow_Date__c >= :windowStart
      GROUP BY Book_Copy__r.Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).recentCheckouts = Integer.valueOf(
          row.get('countValue')
        );
    }
    for (AggregateResult row : [
      SELECT Book__c bookId, COUNT(Id) countValue
      FROM Book_Copy__c
      WHERE Book__c != NULL AND Status__c IN ('Damaged', 'Lost')
      GROUP BY Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).damagedCopies = Integer.valueOf(
          row.get('countValue')
        );
    }
    Date agingCutoff = Date.today().addYears(-5);
    for (AggregateResult row : [
      SELECT Book__c bookId, COUNT(Id) countValue
      FROM Book_Copy__c
      WHERE
        Book__c != NULL
        AND Acquisition_Date__c <= :agingCutoff
        AND Status__c NOT IN ('Retired', 'Lost')
      GROUP BY Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).agingCopies = Integer.valueOf(
          row.get('countValue')
        );
    }

    Map<String, Acquisition_Recommendation__c> existing = new Map<String, Acquisition_Recommendation__c>();
    for (Acquisition_Recommendation__c record : [
      SELECT
        Id,
        Book__c,
        Recommendation_Type__c,
        Recommendation_Score__c,
        Recommended_Quantity__c,
        Confidence__c,
        Evidence__c,
        Status__c,
        Evidence_Window_Start__c,
        Evidence_Window_End__c,
        Refreshed_At__c,
        Decision_Notes__c,
        Decided_At__c,
        Snapshot_Key__c,
        Book__r.Name
      FROM Acquisition_Recommendation__c
      WHERE
        Evidence_Window_Start__c = :windowStart
        AND Evidence_Window_End__c = :windowEnd
      ORDER BY Recommendation_Score__c DESC, CreatedDate DESC
    ])
      existing.put(record.Snapshot_Key__c, record);

    List<Acquisition_Recommendation__c> toInsert = new List<Acquisition_Recommendation__c>();
    List<RecommendationDTO> result = new List<RecommendationDTO>();
    for (Book__c book : books) {
      Signal signal = signals.get(book.Id);
      Integer available = book.Available_Copies__c == null
        ? 0
        : Integer.valueOf(book.Available_Copies__c);
      Integer evidenceCount =
        signal.reservations +
        signal.recentCheckouts +
        signal.damagedCopies +
        signal.agingCopies;
      if (evidenceCount == 0)
        continue;
      String type;
      Integer quantity = 0;
      if (
        signal.reservations > available ||
        (signal.recentCheckouts >= 8 &&
        available <= 1)
      ) {
        type = 'Purchase';
        quantity = Math.max(1, signal.reservations - available);
        if (quantity == 1 && signal.recentCheckouts >= 8 && available == 0)
          quantity = 2;
      } else if (signal.damagedCopies > 0 || signal.agingCopies > 0) {
        type = 'Replace';
        quantity = Math.max(1, signal.damagedCopies);
      } else {
        continue;
      }
      Decimal score = Math.min(
        100,
        signal.reservations * 20 +
          signal.recentCheckouts * 3 +
          signal.damagedCopies * 5 +
          signal.agingCopies * 2
      );
      String confidence = evidenceCount >= 8
        ? 'High'
        : evidenceCount >= 3 ? 'Medium' : 'Low';
      String evidence = String.format(
        '90-day evidence: {0} pending/ready reservations, {1} checkouts, {2} damaged/lost copies, {3} copies older than five years; {4} copies available. Refreshed {5}.',
        new List<String>{
          String.valueOf(signal.reservations),
          String.valueOf(signal.recentCheckouts),
          String.valueOf(signal.damagedCopies),
          String.valueOf(signal.agingCopies),
          String.valueOf(available),
          String.valueOf(refreshedAt)
        }
      );
      String key = String.valueOf(book.Id) + '|' + String.valueOf(windowStart);
      Acquisition_Recommendation__c record = existing.get(key);
      if (record == null) {
        record = new Acquisition_Recommendation__c(
          Book__c = book.Id,
          Recommendation_Type__c = type,
          Recommendation_Score__c = score,
          Recommended_Quantity__c = quantity,
          Confidence__c = confidence,
          Evidence__c = evidence,
          Status__c = 'Open',
          Evidence_Window_Start__c = windowStart,
          Evidence_Window_End__c = windowEnd,
          Refreshed_At__c = refreshedAt,
          Snapshot_Key__c = key
        );
        toInsert.add(record);
      }
      result.add(
        toDto(
          record,
          book,
          signal,
          available,
          type,
          score,
          confidence,
          evidence,
          quantity,
          windowStart,
          windowEnd,
          refreshedAt
        )
      );
    }
    if (!toInsert.isEmpty())
      Database.insert(toInsert, AccessLevel.SYSTEM_MODE);
    Integer insertIndex = 0;
    for (RecommendationDTO dto : result)
      if (dto.id == null && insertIndex < toInsert.size())
        dto.id = toInsert[insertIndex++].Id;
    return result;
  }

  public static Acquisition_Recommendation__c decide(
    Id recommendationId,
    String status,
    String notes
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Set<String> allowed = new Set<String>{ 'Accepted', 'Rejected', 'Deferred' };
    if (recommendationId == null || !allowed.contains(status))
      throw new AuraHandledException(
        'A valid recommendation and decision are required.'
      );
    Acquisition_Recommendation__c record = [
      SELECT Id, Status__c, Decision_Notes__c, Decided_At__c
      FROM Acquisition_Recommendation__c
      WHERE Id = :recommendationId
      LIMIT 1
    ];
    record.Status__c = status;
    record.Decision_Notes__c = String.isBlank(notes)
      ? null
      : notes.trim().left(32768);
    record.Decided_At__c = System.now();
    update record;
    return record;
  }

  public static void recordSearchTelemetry(
    String searchTerm,
    Integer resultCount,
    Id bookId
  ) {
    if (String.isBlank(searchTerm))
      return;
    String normalized = searchTerm.trim().toLowerCase();
    Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(normalized));
    String hash = EncodingUtil.convertToHex(digest);
    Search_Analytics__c event = new Search_Analytics__c(
      Search_Hash__c = hash,
      Search_Result_Count__c = resultCount == null ||
        resultCount < 0
        ? 0
        : resultCount,
      Search_Status__c = resultCount == null ||
        resultCount == 0
        ? 'Zero Results'
        : 'Results',
      Searched_At__c = System.now(),
      Book__c = bookId
    );
    Database.insert(event, AccessLevel.SYSTEM_MODE);
  }

  private static RecommendationDTO toDto(
    Acquisition_Recommendation__c record,
    Book__c book,
    Signal signal,
    Integer available,
    String type,
    Decimal score,
    String confidence,
    String evidence,
    Integer quantity,
    Date windowStart,
    Date windowEnd,
    Datetime refreshedAt
  ) {
    RecommendationDTO dto = new RecommendationDTO();
    dto.id = record.Id;
    dto.bookId = book.Id;
    dto.bookTitle = book.Name;
    dto.recommendationType = record.Id == null
      ? type
      : record.Recommendation_Type__c;
    dto.score = record.Id == null ? score : record.Recommendation_Score__c;
    dto.confidence = record.Id == null ? confidence : record.Confidence__c;
    dto.evidence = record.Id == null ? evidence : record.Evidence__c;
    dto.recommendedQuantity = record.Id == null
      ? quantity
      : Integer.valueOf(record.Recommended_Quantity__c);
    dto.status = record.Id == null ? 'Open' : record.Status__c;
    dto.evidenceWindowStart = record.Id == null
      ? windowStart
      : record.Evidence_Window_Start__c;
    dto.evidenceWindowEnd = record.Id == null
      ? windowEnd
      : record.Evidence_Window_End__c;
    dto.refreshedAt = record.Id == null ? refreshedAt : record.Refreshed_At__c;
    dto.reservations = signal.reservations;
    dto.availableCopies = available;
    dto.recentCheckouts = signal.recentCheckouts;
    dto.damagedCopies = signal.damagedCopies;
    dto.agingCopies = signal.agingCopies;
    dto.insufficientEvidence = false;
    return dto;
  }
}
