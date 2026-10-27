public without sharing class LibraryEventService {
  private static final String EVENT_OPERATION = 'Library Event';
  private static final String REGISTRATION_OPERATION = 'Event Registration';

  public class EventDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Datetime startAt;
    @AuraEnabled
    public Datetime endAt;
    @AuraEnabled
    public Integer capacity;
    @AuraEnabled
    public Integer registeredCount;
    @AuraEnabled
    public String location;
    @AuraEnabled
    public String registrationStatus;
    @AuraEnabled
    public String checkInToken;
  }

  public class CheckInDTO {
    @AuraEnabled
    public Id eventId;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime expiresAt;
  }

  public static Id create(
    String title,
    String description,
    Datetime startAt,
    Datetime endAt,
    Integer capacity,
    String location
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (
      String.isBlank(title) ||
      startAt == null ||
      endAt == null ||
      endAt <= startAt ||
      capacity == null ||
      capacity <= 0
    )
      throw new AuraHandledException(
        'Title, valid dates and a positive capacity are required.'
      );
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'EVENT:' +
        String.valueOf(Crypto.getRandomLong()).replace('-', '0'),
      Operation__c = EVENT_OPERATION,
      Status__c = 'Published',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            't' => title.trim().left(80),
            'd' => String.isBlank(description)
              ? null
              : description.trim().left(100),
            's' => String.valueOf(startAt),
            'e' => String.valueOf(endAt),
            'c' => capacity,
            'l' => String.isBlank(location) ? null : location.trim().left(60)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return row.Id;
  }

  public static List<EventDTO> getUpcoming(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> events = [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :EVENT_OPERATION AND Status__c = 'Published'
      ORDER BY Created_At__c DESC
      LIMIT 200
    ];
    Map<Id, String> memberStatuses = new Map<Id, String>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :REGISTRATION_OPERATION
      LIMIT 200
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      Id eventId = parseId(payload.get('e'));
      if (eventId != null)
        memberStatuses.put(eventId, row.Status__c);
    }
    Map<Id, Integer> counts = registrationCounts();
    Datetime nowValue = System.now();
    List<EventDTO> result = new List<EventDTO>();
    for (Library_Scan_Transaction__c row : events) {
      EventDTO dto = toDto(row);
      if (dto.startAt == null || dto.startAt <= nowValue)
        continue;
      dto.registeredCount = counts.containsKey(row.Id) ? counts.get(row.Id) : 0;
      dto.registrationStatus = memberStatuses.get(row.Id);
      result.add(dto);
    }
    return result;
  }

  public static EventDTO register(String sessionToken, Id eventId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Library_Scan_Transaction__c eventRow = eventRow(eventId);
    EventDTO event = toDto(eventRow);
    if (event.startAt == null || event.startAt <= System.now())
      throw new AuraHandledException(
        'This event is no longer open for registration.'
      );
    String key =
      'EVENT_REG:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(eventId);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      event.registrationStatus = existing[0].Status__c;
      event.registeredCount = registrationCounts().get(eventId);
      if (event.registeredCount == null)
        event.registeredCount = 0;
      return event;
    }
    Map<Id, Integer> counts = registrationCounts();
    Integer current = counts.containsKey(eventId) ? counts.get(eventId) : 0;
    String status = current < event.capacity ? 'Registered' : 'Waitlisted';
    String rawToken = status == 'Registered' ? newToken() : null;
    Library_Scan_Transaction__c registration = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = REGISTRATION_OPERATION,
      Member__c = member.Id,
      Status__c = status,
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'e' => String.valueOf(eventId),
            'h' => rawToken == null ? null : hash(rawToken),
            'x' => rawToken == null
              ? null
              : String.valueOf(System.now().addDays(1))
          }
        )
        .left(255)
    );
    Database.insert(registration, AccessLevel.SYSTEM_MODE);
    event.registrationStatus = status;
    event.checkInToken = rawToken;
    event.registeredCount = current + (status == 'Registered' ? 1 : 0);
    return event;
  }

  public static void cancel(String sessionToken, Id eventId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    eventRow(eventId);
    String key =
      'EVENT_REG:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(eventId);
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      LIMIT 1
    ];
    if (!rows.isEmpty()) {
      Boolean wasRegistered = rows[0].Status__c == 'Registered';
      Database.delete(rows[0], AccessLevel.SYSTEM_MODE);
      if (wasRegistered)
        promoteWaitlist(eventId);
    }
  }

  public static String issueCheckInToken(String sessionToken, Id eventId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    eventRow(eventId);
    String key =
      'EVENT_REG:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(eventId);
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty() || rows[0].Status__c != 'Registered')
      throw new AuraHandledException(
        'Only a confirmed registration can be checked in.'
      );
    String token = newToken();
    Map<String, Object> payload = parse(rows[0].Result_Message__c);
    payload.put('h', hash(token));
    payload.put('x', String.valueOf(System.now().addDays(1)));
    rows[0].Result_Message__c = JSON.serialize(payload).left(255);
    Database.update(rows[0], AccessLevel.SYSTEM_MODE);
    return token;
  }

  public static CheckInDTO checkIn(Id eventId, String token) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (eventId == null || String.isBlank(token))
      throw new AuraHandledException(
        'An event and check-in token are required.'
      );
    eventRow(eventId);
    String tokenHash = hash(token.trim());
    List<Library_Scan_Transaction__c> matches = [
      SELECT Id, Member__c, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = :REGISTRATION_OPERATION
        AND Status__c IN ('Registered', 'Attended')
      LIMIT 2000
      FOR UPDATE
    ];
    for (Library_Scan_Transaction__c row : matches) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      if (
        parseId(payload.get('e')) != eventId ||
        stringValue(payload.get('h')) != tokenHash
      )
        continue;
      Datetime expiresAt = parseDate(payload.get('x'));
      if (expiresAt == null || expiresAt <= System.now())
        throw new AuraHandledException('This check-in token has expired.');
      if (row.Status__c == 'Registered') {
        row.Status__c = 'Attended';
        Database.update(row, AccessLevel.SYSTEM_MODE);
      }
      CheckInDTO result = new CheckInDTO();
      result.eventId = eventId;
      result.memberId = row.Member__c;
      result.status = 'Attended';
      result.expiresAt = expiresAt;
      return result;
    }
    throw new AuraHandledException(
      'That check-in token is invalid for this event.'
    );
  }

  private static Library_Scan_Transaction__c eventRow(Id eventId) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :eventId
        AND Operation__c = :EVENT_OPERATION
        AND Status__c = 'Published'
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The event could not be found.');
    return rows[0];
  }

  private static Map<Id, Integer> registrationCounts() {
    Map<Id, Integer> result = new Map<Id, Integer>();
    for (Library_Scan_Transaction__c row : [
      SELECT Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :REGISTRATION_OPERATION AND Status__c = 'Registered'
      LIMIT 2000
    ]) {
      Id eventId = parseId(parse(row.Result_Message__c).get('e'));
      if (eventId != null)
        result.put(
          eventId,
          (result.containsKey(eventId) ? result.get(eventId) : 0) + 1
        );
    }
    return result;
  }

  private static void promoteWaitlist(Id eventId) {
    List<Library_Scan_Transaction__c> candidates = [
      SELECT Id, Status__c, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :REGISTRATION_OPERATION AND Status__c = 'Waitlisted'
      LIMIT 2000
      FOR UPDATE
    ];
    Library_Scan_Transaction__c selected;
    for (Library_Scan_Transaction__c row : candidates) {
      if (parseId(parse(row.Result_Message__c).get('e')) != eventId)
        continue;
      if (
        selected == null ||
        (row.Created_At__c != null &&
        row.Created_At__c < selected.Created_At__c)
      )
        selected = row;
    }
    if (selected != null) {
      selected.Status__c = 'Registered';
      Map<String, Object> payload = parse(selected.Result_Message__c);
      String token = newToken();
      payload.put('h', hash(token));
      payload.put('x', String.valueOf(System.now().addDays(1)));
      selected.Result_Message__c = JSON.serialize(payload).left(255);
      Database.update(selected, AccessLevel.SYSTEM_MODE);
    }
  }

  private static String newToken() {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest(
        'SHA-256',
        Blob.valueOf(
          UserInfo.getOrganizationId() +
            ':' +
            Datetime.now().getTime() +
            ':' +
            Crypto.getRandomInteger()
        )
      )
    );
  }
  private static String hash(String value) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(value))
    );
  }

  private static EventDTO toDto(Library_Scan_Transaction__c row) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    EventDTO dto = new EventDTO();
    dto.id = row.Id;
    dto.title = stringValue(payload.get('t'));
    dto.description = stringValue(payload.get('d'));
    dto.startAt = parseDate(payload.get('s'));
    dto.endAt = parseDate(payload.get('e'));
    dto.capacity = integerValue(payload.get('c'));
    dto.location = stringValue(payload.get('l'));
    dto.registeredCount = 0;
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
    if (value == null || String.isBlank(String.valueOf(value)))
      return null;
    try {
      return Id.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static Datetime parseDate(Object value) {
    if (value == null || String.isBlank(String.valueOf(value)))
      return null;
    try {
      return (Datetime) JSON.deserialize(
        '"' + String.valueOf(value).replace(' ', 'T') + '"',
        Datetime.class
      );
    } catch (Exception ignored) {
      try {
        return Datetime.valueOf(String.valueOf(value));
      } catch (Exception ignoredAgain) {
        return null;
      }
    }
  }
  private static Integer integerValue(Object value) {
    if (value == null)
      return null;
    try {
      return Integer.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
