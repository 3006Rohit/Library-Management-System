global with sharing class LibraryAgentRoomAvailabilityAction {
  global class Request {
    @InvocableVariable(required=false)
    global String sessionToken;
    @InvocableVariable(required=false)
    global String startTime;
    @InvocableVariable(required=false)
    global Integer durationHours;
    @InvocableVariable(required=false)
    global Integer minimumCapacity;
  }

  global class Response {
    @InvocableVariable
    public Boolean available;
    @InvocableVariable
    public String message;
    @InvocableVariable
    public String windowStart;
    @InvocableVariable
    public String windowEnd;
    @InvocableVariable
    public Decimal freeRoomCount;
    @InvocableVariable
    public String roomsJson;
  }

  @InvocableMethod(
    label='Get Room Availability'
    description='Read-only check of which study rooms and seats are free for a time window (default: right now for one hour). Members pass their session token; librarians need no token. Never books or changes a room.'
  )
  global static List<Response> execute(List<Request> requests) {
    Request input = requests == null || requests.isEmpty()
      ? new Request()
      : requests[0];
    Response output = new Response();
    try {
      // Members are identified by the server-validated session token; without
      // one, the caller must hold the librarian circulation permission.
      if (String.isNotBlank(input.sessionToken)) {
        LibraryMemberSessionService.getCurrentMember(input.sessionToken);
      } else {
        LibraryPolicyService.require('Manage_Library_Circulation');
      }
      Datetime startAt = System.now();
      if (String.isNotBlank(input.startTime)) {
        startAt = LibraryAgentTimeParser.parse(input.startTime);
        if (startAt == null) {
          output.available = false;
          output.message = 'That start time could not be understood. Ask for a date and time, for example 2026-11-04 15:00.';
          return new List<Response>{ output };
        }
      }
      Integer hours = input.durationHours == null ||
        input.durationHours < 1
        ? 1
        : Math.min(input.durationHours, 8);
      Datetime endAt = startAt.addHours(hours);
      List<Map<String, Object>> rooms = new List<Map<String, Object>>();
      Integer free = 0;
      for (
        LibraryRoomBookingService.RoomDTO room : LibraryRoomBookingService.getAvailability(
          startAt,
          endAt,
          input.minimumCapacity
        )
      ) {
        Boolean isFree = room.available == true;
        if (isFree)
          free++;
        rooms.add(
          new Map<String, Object>{
            'room' => room.name,
            'type' => room.roomType,
            'location' => room.location,
            'capacity' => room.capacity,
            'seatsFree' => room.availableSeats,
            'free' => isFree
          }
        );
      }
      output.available = true;
      output.windowStart = startAt.format('yyyy-MM-dd HH:mm');
      output.windowEnd = endAt.format('yyyy-MM-dd HH:mm');
      output.freeRoomCount = free;
      output.roomsJson = JSON.serialize(rooms);
      output.message = rooms.isEmpty()
        ? 'There are no study rooms set up yet.'
        : 'Room availability loaded.';
    } catch (Exception ex) {
      output.available = false;
      output.message = 'Room availability is temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_ROOM_AVAILABILITY_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    return new List<Response>{ output };
  }
}
