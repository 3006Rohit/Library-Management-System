public without sharing class LibraryMemberReviewService {
  private static final String OPERATION = 'Book Review';

  public class ReviewDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id bookId;
    @AuraEnabled
    public String bookTitle;
    @AuraEnabled
    public Integer rating;
    @AuraEnabled
    public String reviewText;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime submittedAt;
  }

  public static ReviewDTO submit(
    String sessionToken,
    Id bookId,
    Integer rating,
    String reviewText
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    if (bookId == null || rating == null || rating < 1 || rating > 5)
      throw new AuraHandledException('Choose a rating from 1 to 5.');
    if (String.isBlank(reviewText) || reviewText.trim().length() < 10)
      throw new AuraHandledException(
        'Review must contain at least 10 characters.'
      );
    Book__c book = [
      SELECT Id, Name
      FROM Book__c
      WHERE Id = :bookId AND Status__c != 'Archived'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    String key =
      'BOOK_REVIEW:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(book.Id);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :key
        AND Member__c = :member.Id
        AND Operation__c = :OPERATION WITH SYSTEM_MODE LIMIT 1
    ];
    Library_Scan_Transaction__c row = existing.isEmpty()
      ? new Library_Scan_Transaction__c(
          Idempotency_Key__c = key,
          Operation__c = OPERATION,
          Member__c = member.Id,
          Status__c = 'Completed',
          Created_At__c = System.now()
        )
      : existing[0];
    if (row.Created_At__c == null)
      row.Created_At__c = System.now();
    Map<String, Object> payload = new Map<String, Object>{
      'b' => String.valueOf(book.Id),
      'r' => rating,
      's' => 'Pending',
      't' => reviewText.trim().left(150)
    };
    row.Status__c = 'Completed';
    row.Result_Message__c = JSON.serialize(payload).left(255);
    Database.upsert(row, AccessLevel.SYSTEM_MODE);
    return toDto(row, payload, book.Name);
  }

  public static List<ReviewDTO> getMine(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :OPERATION WITH SYSTEM_MODE ORDER BY Created_At__c DESC
      LIMIT 200
    ];
    return mapRows(rows);
  }

  public static List<ReviewDTO> getPublished(String sessionToken, Id bookId) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    if (bookId == null)
      return new List<ReviewDTO>();
    Book__c book = [SELECT Id, Name FROM Book__c WHERE Id = :bookId WITH SYSTEM_MODE LIMIT 1];
    String bookPattern = '%"b":"' + String.valueOf(bookId) + '"%';
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION AND Result_Message__c LIKE :bookPattern
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 200
    ];
    List<ReviewDTO> result = new List<ReviewDTO>();
    for (ReviewDTO row : mapRows(rows))
      if (row.status == 'Published' && row.bookId == bookId) {
        row.bookTitle = book.Name;
        result.add(row);
      }
    return result;
  }

  public static void moderate(Id reviewId, String status) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (status != 'Published' && status != 'Rejected')
      throw new AuraHandledException('Invalid moderation status.');
    Library_Scan_Transaction__c row = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :reviewId AND Operation__c = :OPERATION
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Map<String, Object> payload = parse(row.Result_Message__c);
    payload.put('s', status);
    row.Result_Message__c = JSON.serialize(payload).left(255);
    Database.update(row, AccessLevel.SYSTEM_MODE);
  }

  private static List<ReviewDTO> mapRows(
    List<Library_Scan_Transaction__c> rows
  ) {
    Set<Id> ids = new Set<Id>();
    Map<Id, Map<String, Object>> payloads = new Map<Id, Map<String, Object>>();
    for (Library_Scan_Transaction__c row : rows) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      Id bookId = parseId(payload.get('b'));
      if (bookId != null) {
        ids.add(bookId);
        payloads.put(row.Id, payload);
      }
    }
    Map<Id, Book__c> books = ids.isEmpty()
      ? new Map<Id, Book__c>()
      : new Map<Id, Book__c>([SELECT Id, Name FROM Book__c WHERE Id IN :ids WITH SYSTEM_MODE]);
    List<ReviewDTO> result = new List<ReviewDTO>();
    for (Library_Scan_Transaction__c row : rows)
      if (payloads.containsKey(row.Id)) {
        Map<String, Object> payload = payloads.get(row.Id);
        Id bookId = parseId(payload.get('b'));
        result.add(
          toDto(
            row,
            payload,
            books.containsKey(bookId) ? books.get(bookId).Name : null
          )
        );
      }
    return result;
  }

  private static ReviewDTO toDto(
    Library_Scan_Transaction__c row,
    Map<String, Object> payload,
    String title
  ) {
    ReviewDTO dto = new ReviewDTO();
    dto.id = row.Id;
    dto.bookId = parseId(payload.get('b'));
    dto.bookTitle = title;
    dto.rating = payload.get('r') == null
      ? null
      : Integer.valueOf(String.valueOf(payload.get('r')));
    dto.reviewText = payload.get('t') == null
      ? null
      : String.valueOf(payload.get('t'));
    dto.status = payload.get('s') == null
      ? 'Pending'
      : String.valueOf(payload.get('s'));
    dto.submittedAt = row.Created_At__c;
    return dto;
  }
  private static Map<String, Object> parse(String raw) {
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
}
