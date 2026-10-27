public without sharing class LibraryRoomBookingService {
  private static final String ROOM_OPERATION = 'Library Room';
  private static final String BOOKING_OPERATION = 'Room Booking';

  public class RoomDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String location;
    @AuraEnabled
    public Integer capacity;
    @AuraEnabled
    public String equipment;
    @AuraEnabled
    public Boolean available;
  }

  public class BookingDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id roomId;
    @AuraEnabled
    public String roomName;
    @AuraEnabled
    public Datetime startAt;
    @AuraEnabled
    public Datetime endAt;
    @AuraEnabled
    public String purpose;
    @AuraEnabled
    public String status;
  }

  public static Id createRoom(
    String name,
    String location,
    Integer capacity,
    String equipment
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(name) || capacity == null || capacity <= 0)
      throw new AuraHandledException(
        'Room name and a positive capacity are required.'
      );
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'ROOM:' +
        String.valueOf(Crypto.getRandomLong()).replace('-', '0'),
      Operation__c = ROOM_OPERATION,
      Status__c = 'Published',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'n' => name.trim().left(80),
            'l' => String.isBlank(location) ? null : location.trim().left(80),
            'c' => capacity,
            'e' => String.isBlank(equipment) ? null : equipment.trim().left(80)
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return row.Id;
  }

  public static List<RoomDTO> getRooms(
    String sessionToken,
    Datetime startAt,
    Datetime endAt,
    Integer minimumCapacity
  ) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    if (minimumCapacity != null && minimumCapacity < 1)
      throw new AuraHandledException('Capacity must be positive.');
    List<Library_Scan_Transaction__c> rooms = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :ROOM_OPERATION AND Status__c = 'Published'
      ORDER BY Created_At__c ASC
      LIMIT 200
    ];
    Set<Id> unavailable = bookedRoomIds(startAt, endAt);
    List<RoomDTO> result = new List<RoomDTO>();
    for (Library_Scan_Transaction__c row : rooms) {
      RoomDTO dto = toRoomDto(row);
      if (
        minimumCapacity != null &&
        (dto.capacity == null ||
        dto.capacity < minimumCapacity)
      )
        continue;
      dto.available = !unavailable.contains(row.Id);
      result.add(dto);
    }
    return result;
  }

  public static BookingDTO book(
    String sessionToken,
    Id roomId,
    Datetime startAt,
    Datetime endAt,
    String purpose
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    validateWindow(startAt, endAt);
    Library_Scan_Transaction__c room = roomRow(roomId);
    String key =
      'ROOM_BOOK:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(roomId) +
      ':' +
      String.valueOf(startAt);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return toBookingDto(existing[0], roomName(room));
    for (Library_Scan_Transaction__c row : bookingRows()) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      if (
        parseId(payload.get('r')) == roomId &&
        overlaps(
          startAt,
          endAt,
          parseDate(payload.get('s')),
          parseDate(payload.get('e'))
        )
      )
        throw new AuraHandledException(
          'This room is already booked for that time.'
        );
    }
    Library_Scan_Transaction__c booking = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = BOOKING_OPERATION,
      Member__c = member.Id,
      Status__c = 'Booked',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'r' => String.valueOf(roomId),
            's' => String.valueOf(startAt),
            'e' => String.valueOf(endAt),
            'p' => String.isBlank(purpose) ? null : purpose.trim().left(100)
          }
        )
        .left(255)
    );
    Database.insert(booking, AccessLevel.SYSTEM_MODE);
    return toBookingDto(booking, roomName(room));
  }

  public static List<BookingDTO> getMyBookings(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Map<Id, String> names = roomNames();
    List<BookingDTO> result = new List<BookingDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :BOOKING_OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 200
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      Id roomId = parseId(payload.get('r'));
      result.add(toBookingDto(row, names.get(roomId)));
    }
    return result;
  }

  public static void cancel(String sessionToken, Id bookingId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :bookingId
        AND Member__c = :member.Id
        AND Operation__c = :BOOKING_OPERATION
      LIMIT 1
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The booking could not be found.');
    Database.delete(rows[0], AccessLevel.SYSTEM_MODE);
  }

  private static Library_Scan_Transaction__c roomRow(Id roomId) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :roomId
        AND Operation__c = :ROOM_OPERATION
        AND Status__c = 'Published'
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The room could not be found.');
    return rows[0];
  }

  private static List<Library_Scan_Transaction__c> bookingRows() {
    return [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :BOOKING_OPERATION AND Status__c = 'Booked'
      LIMIT 2000
      FOR UPDATE
    ];
  }

  private static Set<Id> bookedRoomIds(Datetime startAt, Datetime endAt) {
    Set<Id> result = new Set<Id>();
    if (startAt == null || endAt == null)
      return result;
    for (Library_Scan_Transaction__c row : bookingRows()) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      if (
        overlaps(
          startAt,
          endAt,
          parseDate(payload.get('s')),
          parseDate(payload.get('e'))
        )
      )
        result.add(parseId(payload.get('r')));
    }
    return result;
  }

  private static Map<Id, String> roomNames() {
    Map<Id, String> result = new Map<Id, String>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :ROOM_OPERATION AND Status__c = 'Published'
      LIMIT 200
    ])
      result.put(row.Id, stringValue(parse(row.Result_Message__c).get('n')));
    return result;
  }

  private static String roomName(Library_Scan_Transaction__c row) {
    return stringValue(parse(row.Result_Message__c).get('n'));
  }
  private static void validateWindow(Datetime startAt, Datetime endAt) {
    if (
      startAt == null ||
      endAt == null ||
      startAt <= System.now() ||
      endAt <= startAt ||
      endAt > startAt.addHours(8)
    )
      throw new AuraHandledException(
        'Choose a future room window of eight hours or less.'
      );
  }
  private static Boolean overlaps(
    Datetime startAt,
    Datetime endAt,
    Datetime otherStart,
    Datetime otherEnd
  ) {
    return otherStart != null &&
      otherEnd != null &&
      startAt < otherEnd &&
      endAt > otherStart;
  }
  private static BookingDTO toBookingDto(
    Library_Scan_Transaction__c row,
    String roomNameValue
  ) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    BookingDTO dto = new BookingDTO();
    dto.id = row.Id;
    dto.roomId = parseId(payload.get('r'));
    dto.roomName = roomNameValue;
    dto.startAt = parseDate(payload.get('s'));
    dto.endAt = parseDate(payload.get('e'));
    dto.purpose = stringValue(payload.get('p'));
    dto.status = row.Status__c;
    return dto;
  }
  private static RoomDTO toRoomDto(Library_Scan_Transaction__c row) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    RoomDTO dto = new RoomDTO();
    dto.id = row.Id;
    dto.name = stringValue(payload.get('n'));
    dto.location = stringValue(payload.get('l'));
    dto.capacity = integerValue(payload.get('c'));
    dto.equipment = stringValue(payload.get('e'));
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
  private static Datetime parseDate(Object value) {
    if (value == null || String.isBlank(String.valueOf(value)))
      return null;
    String raw = String.valueOf(value).replace('T', ' ');
    Integer dot = raw.indexOf('.');
    if (dot > 0)
      raw = raw.substring(0, dot);
    Integer plus = raw.indexOf('+');
    if (plus > 0)
      raw = raw.substring(0, plus);
    if (raw.endsWith('Z'))
      raw = raw.left(raw.length() - 1).trim();
    try {
      return Datetime.valueOf(raw);
    } catch (Exception ignored) {
      return null;
    }
  }
  private static Integer integerValue(Object value) {
    try {
      return value == null ? null : Integer.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
