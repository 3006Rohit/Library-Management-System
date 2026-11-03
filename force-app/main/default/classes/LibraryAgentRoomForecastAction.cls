global with sharing class LibraryAgentRoomForecastAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
  }

  global class Response {
    @InvocableVariable
    public Boolean available;
    @InvocableVariable
    public String message;
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
    public String tips;
  }

  @InvocableMethod(
    label='Get Room Busy Times'
    description='Use for questions about when study rooms are busiest or the best time to book. Identity comes from the server-validated session token. Returns only anonymous busy-time guidance, never other members or seats.'
  )
  global static List<Response> execute(List<Request> requests) {
    String token = requests == null || requests.isEmpty()
      ? null
      : requests[0].sessionToken;
    Response output = new Response();
    LibraryRoomInsightService.InsightsDTO source = LibraryRoomInsightService.getForecast(
      token
    );
    output.available = source.hasData;
    output.tips = String.join(source.suggestions, '\n');
    if (source.hasData != true) {
      output.message = 'There is not enough booking history yet to show busy times.';
      return new List<Response>{ output };
    }
    output.peakHourLabel = source.peakHourLabel;
    output.peakDayLabel = source.peakDayLabel;
    output.quietTimes = String.join(source.quietTimes, ', ');

    List<Map<String, Object>> hours = new List<Map<String, Object>>();
    for (LibraryRoomInsightService.HourBucket bucket : source.hours) {
      hours.add(
        new Map<String, Object>{
          'hour' => bucket.label,
          'demand' => bucket.level
        }
      );
    }
    List<Map<String, Object>> days = new List<Map<String, Object>>();
    for (LibraryRoomInsightService.DayBucket bucket : source.days) {
      days.add(
        new Map<String, Object>{
          'day' => bucket.label,
          'demand' => bucket.level
        }
      );
    }
    output.busyHoursJson = JSON.serialize(hours);
    output.busyDaysJson = JSON.serialize(days);
    output.message = 'Room busy times loaded.';
    return new List<Response>{ output };
  }
}
