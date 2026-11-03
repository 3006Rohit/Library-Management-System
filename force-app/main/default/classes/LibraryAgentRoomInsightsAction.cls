global with sharing class LibraryAgentRoomInsightsAction {
  global class Request {
    @InvocableVariable(required=false)
    global String requestContext;
  }

  global class Response {
    @InvocableVariable
    public Boolean available;
    @InvocableVariable
    public String message;
    @InvocableVariable
    public Decimal totalBookings;
    @InvocableVariable
    public Decimal activeBookings;
    @InvocableVariable
    public Decimal canceledBookings;
    @InvocableVariable
    public Decimal cancellationPercent;
    @InvocableVariable
    public String peakHourLabel;
    @InvocableVariable
    public String peakDayLabel;
    @InvocableVariable
    public String quietTimes;
    @InvocableVariable
    public String busyHoursJson;
    @InvocableVariable
    public String busyDaysJson;
    @InvocableVariable
    public String busiestRoomsJson;
    @InvocableVariable
    public String topSeatsJson;
    @InvocableVariable
    public String suggestions;
  }

  @InvocableMethod(
    label='Get Room Demand Insights'
    description='Read-only librarian insights on study room demand: peak hours and days, the most in-demand rooms and seats, cancellation rate and suggestions. Use for room and seat demand questions; do not invent values.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      LibraryRoomInsightService.InsightsDTO source = LibraryRoomInsightService.getAgentInsights();
      output.available = source.hasData;
      output.suggestions = String.join(source.suggestions, '\n');
      if (source.hasData != true) {
        output.message = 'There are no room bookings yet, so there is no demand data.';
        return new List<Response>{ output };
      }
      output.totalBookings = source.totalBookings;
      output.activeBookings = source.activeBookings;
      output.canceledBookings = source.canceledBookings;
      output.cancellationPercent = source.cancellationPercent;
      output.peakHourLabel = source.peakHourLabel;
      output.peakDayLabel = source.peakDayLabel;
      output.quietTimes = String.join(source.quietTimes, ', ');

      List<Map<String, Object>> hours = new List<Map<String, Object>>();
      for (LibraryRoomInsightService.HourBucket bucket : source.hours) {
        hours.add(
          new Map<String, Object>{
            'hour' => bucket.label,
            'bookings' => bucket.bookings,
            'demand' => bucket.level
          }
        );
      }
      List<Map<String, Object>> days = new List<Map<String, Object>>();
      for (LibraryRoomInsightService.DayBucket bucket : source.days) {
        days.add(
          new Map<String, Object>{
            'day' => bucket.label,
            'bookings' => bucket.bookings,
            'demand' => bucket.level
          }
        );
      }
      List<Map<String, Object>> rooms = new List<Map<String, Object>>();
      for (LibraryRoomInsightService.RoomStat room : source.rooms) {
        rooms.add(
          new Map<String, Object>{
            'room' => room.name,
            'type' => room.roomType,
            'capacity' => room.capacity,
            'bookings' => room.bookings,
            'bookedHours' => room.bookedHours,
            'sharePercent' => room.sharePercent,
            'demand' => room.level
          }
        );
      }
      List<Map<String, Object>> seats = new List<Map<String, Object>>();
      for (LibraryRoomInsightService.SeatStat seat : source.topSeats) {
        seats.add(
          new Map<String, Object>{
            'room' => seat.roomName,
            'seat' => seat.seatNo,
            'bookings' => seat.bookings
          }
        );
      }
      output.busyHoursJson = JSON.serialize(hours);
      output.busyDaysJson = JSON.serialize(days);
      output.busiestRoomsJson = JSON.serialize(rooms);
      output.topSeatsJson = JSON.serialize(seats);
      output.message = 'Room demand insights loaded.';
    } catch (Exception ex) {
      output.available = false;
      output.message = 'Room insights are temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_ROOM_INSIGHTS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    return new List<Response>{ output };
  }
}
