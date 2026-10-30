public without sharing class LibraryAcquisitionInsightService {
  // A decision is kept for this long before the book is re-evaluated.
  private static final Integer DECISION_HOLD_DAYS = 30;

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
    @AuraEnabled
    public String decisionNotes;
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
      WITH SYSTEM_MODE
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
      WITH SYSTEM_MODE
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
      WITH SYSTEM_MODE
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
      WITH SYSTEM_MODE
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
      WITH SYSTEM_MODE
      GROUP BY Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).agingCopies = Integer.valueOf(
          row.get('countValue')
        );
    }

    Set<Id> bookIds = new Set<Id>();
    for (Book__c book : books)
      bookIds.add(book.Id);
    // One record per book and type, reused across refreshes so decisions stick.
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
        Snapshot_Key__c
      FROM Acquisition_Recommendation__c
      WHERE Book__c IN :bookIds
      WITH SYSTEM_MODE
      ORDER BY CreatedDate DESC
      LIMIT 5000
    ]) {
      String key = String.valueOf(record.Book__c) +
        '|' +
        record.Recommendation_Type__c;
      if (!existing.containsKey(key))
        existing.put(key, record);
    }

    Datetime decisionHoldCutoff = System.now().addDays(-DECISION_HOLD_DAYS);
    List<Acquisition_Recommendation__c> toInsert = new List<Acquisition_Recommendation__c>();
    List<Acquisition_Recommendation__c> toUpdate = new List<Acquisition_Recommendation__c>();
    List<Acquisition_Recommendation__c> records = new List<Acquisition_Recommendation__c>();
    List<Book__c> recordBooks = new List<Book__c>();
    List<Signal> recordSignals = new List<Signal>();
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
      Integer unmet = Math.max(signal.reservations - available, 0);
      Boolean busy = signal.recentCheckouts >= 8 && available <= 1;
      String type;
      Integer quantity;
      Integer score;
      if (unmet > 0 || busy) {
        type = 'Purchase';
        quantity = Math.max(1, unmet);
        if (quantity == 1 && busy && available == 0)
          quantity = 2;
        // Waiting readers matter most, then borrowing volume, then an empty shelf.
        score =
          Math.min(unmet * 30, 60) +
          Math.min(signal.recentCheckouts * 2, 30) +
          (available == 0 ? 10 : 0);
      } else if (signal.damagedCopies > 0 || signal.agingCopies > 0) {
        type = 'Replace';
        quantity = Math.max(1, signal.damagedCopies);
        score =
          Math.min(signal.damagedCopies * 25, 60) +
          Math.min(signal.agingCopies * 8, 40);
      } else {
        continue;
      }
      score = Math.max(1, Math.min(score, 100));
      String confidence = evidenceCount >= 8
        ? 'High'
        : evidenceCount >= 3 ? 'Medium' : 'Low';
      String evidence = String.format(
        '{0} reservations waiting, {1} checkouts in 90 days, {2} damaged or lost, {3} older than five years, {4} on the shelf.',
        new List<String>{
          String.valueOf(signal.reservations),
          String.valueOf(signal.recentCheckouts),
          String.valueOf(signal.damagedCopies),
          String.valueOf(signal.agingCopies),
          String.valueOf(available)
        }
      );
      String key = String.valueOf(book.Id) + '|' + type;
      Acquisition_Recommendation__c record = existing.get(key);
      Boolean decided =
        record != null &&
        record.Status__c != 'Open' &&
        record.Decided_At__c != null &&
        record.Decided_At__c > decisionHoldCutoff;
      if (!decided) {
        Boolean isNew = record == null;
        if (isNew)
          record = new Acquisition_Recommendation__c(
            Book__c = book.Id,
            Recommendation_Type__c = type
          );
        record.Recommendation_Score__c = score;
        record.Recommended_Quantity__c = quantity;
        record.Confidence__c = confidence;
        record.Evidence__c = evidence;
        record.Status__c = 'Open';
        record.Decision_Notes__c = null;
        record.Decided_At__c = null;
        record.Evidence_Window_Start__c = windowStart;
        record.Evidence_Window_End__c = windowEnd;
        record.Refreshed_At__c = refreshedAt;
        record.Snapshot_Key__c = key;
        if (isNew)
          toInsert.add(record);
        else
          toUpdate.add(record);
      }
      records.add(record);
      recordBooks.add(book);
      recordSignals.add(signal);
    }
    if (!toInsert.isEmpty())
      Database.insert(toInsert, AccessLevel.SYSTEM_MODE);
    if (!toUpdate.isEmpty())
      Database.update(toUpdate, AccessLevel.SYSTEM_MODE);

    List<RecommendationDTO> result = new List<RecommendationDTO>();
    for (Integer i = 0; i < records.size(); i++) {
      Book__c book = recordBooks[i];
      Integer available = book.Available_Copies__c == null
        ? 0
        : Integer.valueOf(book.Available_Copies__c);
      result.add(toDto(records[i], book, recordSignals[i], available));
    }
    return result;
  }

  public static Acquisition_Recommendation__c decide(
    Id recommendationId,
    String status,
    String notes
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Set<String> allowed = new Set<String>{
      'Accepted',
      'Rejected',
      'Deferred',
      'Open'
    };
    if (recommendationId == null || !allowed.contains(status))
      throw new AuraHandledException(
        'A valid recommendation and decision are required.'
      );
    List<Acquisition_Recommendation__c> found = [
      SELECT Id, Status__c, Decision_Notes__c, Decided_At__c
      FROM Acquisition_Recommendation__c
      WHERE Id = :recommendationId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (found.isEmpty())
      throw new AuraHandledException('The recommendation could not be found.');
    Acquisition_Recommendation__c record = found[0];
    Boolean reopening = status == 'Open';
    record.Status__c = status;
    record.Decision_Notes__c = reopening || String.isBlank(notes)
      ? null
      : notes.trim().left(32768);
    record.Decided_At__c = reopening ? null : System.now();
    Database.update(record, AccessLevel.SYSTEM_MODE);
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
    Integer available
  ) {
    RecommendationDTO dto = new RecommendationDTO();
    dto.id = record.Id;
    dto.bookId = book.Id;
    dto.bookTitle = book.Name;
    dto.recommendationType = record.Recommendation_Type__c;
    dto.score = record.Recommendation_Score__c;
    dto.confidence = record.Confidence__c;
    dto.evidence = record.Evidence__c;
    dto.recommendedQuantity = record.Recommended_Quantity__c == null
      ? null
      : Integer.valueOf(record.Recommended_Quantity__c);
    dto.status = record.Status__c;
    dto.evidenceWindowStart = record.Evidence_Window_Start__c;
    dto.evidenceWindowEnd = record.Evidence_Window_End__c;
    dto.refreshedAt = record.Refreshed_At__c;
    dto.reservations = signal.reservations;
    dto.availableCopies = available;
    dto.recentCheckouts = signal.recentCheckouts;
    dto.damagedCopies = signal.damagedCopies;
    dto.agingCopies = signal.agingCopies;
    dto.insufficientEvidence = false;
    dto.decisionNotes = record.Decision_Notes__c;
    return dto;
  }
}
