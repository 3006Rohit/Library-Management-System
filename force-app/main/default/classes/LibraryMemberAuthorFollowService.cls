public without sharing class LibraryMemberAuthorFollowService {
  private static final String OPERATION = 'Author Follow';

  public class FollowDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id authorId;
    @AuraEnabled
    public String authorName;
    @AuraEnabled
    public Datetime followedAt;
  }

  public static List<FollowDTO> getAll(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 200
    ];
    Set<Id> authorIds = new Set<Id>();
    Map<Id, Id> rowAuthors = new Map<Id, Id>();
    for (Library_Scan_Transaction__c row : rows) {
      Id authorId = parseId(row.Result_Message__c);
      if (authorId != null) {
        authorIds.add(authorId);
        rowAuthors.put(row.Id, authorId);
      }
    }
    Map<Id, Author__c> authors = authorIds.isEmpty()
      ? new Map<Id, Author__c>()
      : new Map<Id, Author__c>(
          [SELECT Id, Name FROM Author__c WHERE Id IN :authorIds]
        );
    List<FollowDTO> result = new List<FollowDTO>();
    for (Library_Scan_Transaction__c row : rows) {
      Id authorId = rowAuthors.get(row.Id);
      if (authorId == null || !authors.containsKey(authorId))
        continue;
      FollowDTO dto = new FollowDTO();
      dto.id = row.Id;
      dto.authorId = authorId;
      dto.authorName = authors.get(authorId).Name;
      dto.followedAt = row.Created_At__c;
      result.add(dto);
    }
    return result;
  }

  public static FollowDTO follow(String sessionToken, Id authorId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    if (authorId == null)
      throw new AuraHandledException('Choose an author to follow.');
    Author__c author = [
      SELECT Id, Name
      FROM Author__c
      WHERE Id = :authorId
      LIMIT 1
    ];
    String key =
      'AUTHOR_FOLLOW:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(author.Id);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :key
        AND Member__c = :member.Id
        AND Operation__c = :OPERATION
      LIMIT 1
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
    row.Result_Message__c = String.valueOf(author.Id);
    row.Status__c = 'Completed';
    Database.upsert(row, AccessLevel.SYSTEM_MODE);
    FollowDTO result = new FollowDTO();
    result.id = row.Id;
    result.authorId = author.Id;
    result.authorName = author.Name;
    result.followedAt = row.Created_At__c;
    return result;
  }

  public static void unfollow(String sessionToken, Id followId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Library_Scan_Transaction__c row = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :followId
        AND Member__c = :member.Id
        AND Operation__c = :OPERATION
      LIMIT 1
    ];
    Database.delete(row, AccessLevel.SYSTEM_MODE);
  }

  private static Id parseId(String raw) {
    try {
      return String.isBlank(raw) ? null : Id.valueOf(raw);
    } catch (Exception ignored) {
      return null;
    }
  }
}
