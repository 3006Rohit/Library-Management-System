public with sharing class LibraryLibrarianSessionController {
  public class BookingDetailDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id roomId;
    @AuraEnabled
    public String roomName;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public Datetime startAt;
    @AuraEnabled
    public Datetime endAt;
    @AuraEnabled
    public String purpose;
    @AuraEnabled
    public String status;
  }

  @AuraEnabled(cacheable=true)
  public static List<BookingDetailDTO> getAllRoomBookings() {
    LibraryPolicyService.require('Manage_Library_Registrations');
    Map<Id, String> roomNames = new Map<Id, String>();
    Map<Id, String> memberNames = new Map<Id, String>();

    List<Library_Scan_Transaction__c> bookings = [
      SELECT
        Id,
        Member__c,
        Member__r.Name,
        Result_Message__c,
        Status__c,
        Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = 'Room Booking'
      ORDER BY Created_At__c DESC
      LIMIT 500
    ];

    List<BookingDetailDTO> result = new List<BookingDetailDTO>();
    for (Library_Scan_Transaction__c booking : bookings) {
      Map<String, Object> payload = parse(booking.Result_Message__c);
      Id roomId = parseId(payload.get('r'));

      if (!roomNames.containsKey(roomId)) {
        roomNames.put(roomId, getRoomName(roomId));
      }

      BookingDetailDTO dto = new BookingDetailDTO();
      dto.id = booking.Id;
      dto.roomId = roomId;
      dto.roomName = roomNames.get(roomId);
      dto.memberId = booking.Member__c;
      dto.memberName = booking.Member__r == null
        ? null
        : booking.Member__r.Name;
      dto.startAt = parseDate(payload.get('s'));
      dto.endAt = parseDate(payload.get('e'));
      dto.purpose = stringValue(payload.get('p'));
      dto.status = booking.Status__c;
      result.add(dto);
    }

    return result;
  }

  @AuraEnabled
  public static void cancelRoomBookingAsLibrarian(Id bookingId) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :bookingId AND Operation__c = 'Room Booking'
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The booking could not be found.');
    Library_Scan_Transaction__c booking = rows[0];
    booking.Status__c = 'Canceled';
    Database.update(booking, AccessLevel.SYSTEM_MODE);
  }

  private static String getRoomName(Id roomId) {
    List<Library_Scan_Transaction__c> rooms = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :roomId AND Operation__c = 'Library Room'
      LIMIT 1
    ];
    if (rooms.isEmpty())
      return null;
    Map<String, Object> payload = parse(rooms[0].Result_Message__c);
    return stringValue(payload.get('n'));
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

  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
