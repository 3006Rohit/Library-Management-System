public without sharing class LibraryMemberEngagementService {
  private static final String OPERATION = 'Reading List';
  private static final Set<String> STATES = new Set<String>{
    'Want to Read',
    'Currently Reading',
    'Completed',
    'Abandoned'
  };

  public class EngagementDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id bookId;
    @AuraEnabled
    public String bookTitle;
    @AuraEnabled
    public String state;
    @AuraEnabled
    public String privateNotes;
    @AuraEnabled
    public Integer rating;
    @AuraEnabled
    public Boolean notifyWhenAvailable;
    @AuraEnabled
    public Datetime lastUpdated;
  }

  public static List<EngagementDTO> getAll(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Idempotency_Key__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :OPERATION WITH SYSTEM_MODE ORDER BY Created_At__c DESC
      LIMIT 200
    ];
    Map<Id, Map<String, Object>> payloads = new Map<Id, Map<String, Object>>();
    Set<Id> bookIds = new Set<Id>();
    for (Library_Scan_Transaction__c row : rows) {
      Map<String, Object> payload = parsePayload(row.Result_Message__c);
      Id bookId = parseId(payload.get('bookId'));
      if (bookId != null) {
        payloads.put(row.Id, payload);
        bookIds.add(bookId);
      }
    }
    Map<Id, Book__c> books = bookIds.isEmpty()
      ? new Map<Id, Book__c>()
      : new Map<Id, Book__c>(
          [
            SELECT Id, Name
            FROM Book__c
            WHERE Id IN :bookIds
            WITH SYSTEM_MODE
          ]
        );
    List<EngagementDTO> result = new List<EngagementDTO>();
    for (Library_Scan_Transaction__c row : rows) {
      if (!payloads.containsKey(row.Id))
        continue;
      Map<String, Object> payload = payloads.get(row.Id);
      Id bookId = parseId(payload.get('bookId'));
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

  public static EngagementDTO save(
    String sessionToken,
    Id bookId,
    String state,
    String notes,
    Integer rating,
    Boolean notifyWhenAvailable
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    if (bookId == null || !STATES.contains(state))
      throw new AuraHandledException('Choose a valid book and reading state.');
    if (rating != null && (rating < 1 || rating > 5))
      throw new AuraHandledException('Rating must be between 1 and 5.');
    Book__c book = [
      SELECT Id, Name
      FROM Book__c
      WHERE Id = :bookId AND Status__c != 'Archived'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    String key =
      'ENGAGEMENT:' +
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
          Created_At__c = System.now()
        )
      : existing[0];
    Map<String, Object> payload = new Map<String, Object>{
      'bookId' => String.valueOf(book.Id),
      'state' => state,
      'notes' => String.isBlank(notes) ? null : notes.trim().left(200),
      'rating' => rating,
      'notify' => notifyWhenAvailable == true
    };
    row.Status__c = 'Completed';
    row.Result_Message__c = JSON.serialize(payload).left(255);
    Database.upsert(row, AccessLevel.SYSTEM_MODE);
    return toDto(row, payload, book.Name);
  }

  public static void remove(String sessionToken, Id engagementId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Library_Scan_Transaction__c row = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :engagementId
        AND Member__c = :member.Id
        AND Operation__c = :OPERATION WITH SYSTEM_MODE LIMIT 1
    ];
    Database.delete(row, AccessLevel.SYSTEM_MODE);
  }

  private static Map<String, Object> parsePayload(String raw) {
    if (String.isBlank(raw))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }

  private static Id parseId(Object value) {
    if (value == null || String.isBlank(String.valueOf(value)))
      return null;
    try {
      return Id.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }

  private static EngagementDTO toDto(
    Library_Scan_Transaction__c row,
    Map<String, Object> payload,
    String bookTitle
  ) {
    EngagementDTO dto = new EngagementDTO();
    dto.id = row.Id;
    dto.bookId = parseId(payload.get('bookId'));
    dto.bookTitle = bookTitle;
    dto.state = String.valueOf(payload.get('state'));
    dto.privateNotes = payload.get('notes') == null
      ? null
      : String.valueOf(payload.get('notes'));
    dto.rating = payload.get('rating') == null
      ? null
      : Integer.valueOf(String.valueOf(payload.get('rating')));
    dto.notifyWhenAvailable = payload.get('notify') == true;
    dto.lastUpdated = row.Created_At__c;
    return dto;
  }
}
