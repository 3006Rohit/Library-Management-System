global with sharing class LibraryPublicEventsAction {
  private static final String EVENT_OPERATION = 'Library Event';

  global class Request {
    @InvocableVariable(label='Topic keyword (optional)')
    public String topic;
    @InvocableVariable(label='Branch or location (optional)')
    public String branch;
  }
  global class EventResult {
    @InvocableVariable
    public String title;
    @InvocableVariable
    public String description;
    @InvocableVariable
    public String startsAt;
    @InvocableVariable
    public String endsAt;
    @InvocableVariable
    public String location;
    @InvocableVariable
    public String message;
    public Datetime startValue;
  }

  @InvocableMethod(
    label='Get Upcoming Library Events'
    description='Use for public questions about upcoming library events, programmes and activities. Returns future published events only; never returns registrations or member data.'
  )
  global static List<EventResult> execute(List<Request> requests) {
    try {
      return executeInternal(requests);
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_PUBLIC_EVENTS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
      return new List<EventResult>{
        messageOnly('Event information is temporarily unavailable.')
      };
    }
  }

  private static List<EventResult> executeInternal(List<Request> requests) {
    Request request = requests == null ||
      requests.isEmpty() ||
      requests[0] == null
      ? new Request()
      : requests[0];
    String topic = String.isBlank(request.topic)
      ? null
      : request.topic.trim().toLowerCase();
    String branch = String.isBlank(request.branch)
      ? null
      : request.branch.trim().toLowerCase();
    Datetime nowValue = System.now();
    List<EventResult> events = new List<EventResult>();
    for (Library_Scan_Transaction__c row : [
      SELECT Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :EVENT_OPERATION AND Status__c = 'Published'
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 200
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      Datetime startAt = parseDate(payload.get('s'));
      if (startAt == null || startAt <= nowValue)
        continue;
      EventResult result = new EventResult();
      result.title = text(payload.get('t'));
      result.description = text(payload.get('d'));
      result.location = text(payload.get('l'));
      result.startValue = startAt;
      result.startsAt = startAt.format('EEE, d MMM yyyy h:mm a');
      Datetime endAt = parseDate(payload.get('e'));
      result.endsAt = endAt == null
        ? ''
        : endAt.format('EEE, d MMM yyyy h:mm a');
      if (
        topic != null &&
        !(result.title + ' ' + result.description).toLowerCase().contains(topic)
      )
        continue;
      if (branch != null && !result.location.toLowerCase().contains(branch))
        continue;
      events.add(result);
    }
    // Earliest first; the list is small (<= 200) so an insertion sort is enough.
    for (Integer i = 1; i < events.size(); i++) {
      EventResult current = events[i];
      Integer j = i - 1;
      while (j >= 0 && events[j].startValue > current.startValue) {
        events[j + 1] = events[j];
        j--;
      }
      events[j + 1] = current;
    }
    List<EventResult> output = new List<EventResult>();
    for (Integer i = 0; i < events.size() && i < 10; i++)
      output.add(events[i]);
    if (output.isEmpty())
      output.add(
        messageOnly('There are no upcoming events matching your request.')
      );
    return output;
  }

  private static EventResult messageOnly(String message) {
    EventResult result = new EventResult();
    result.message = message;
    return result;
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
  private static String text(Object value) {
    return value == null ? '' : String.valueOf(value);
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
}
