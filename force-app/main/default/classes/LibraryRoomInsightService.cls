public without sharing class LibraryRoomInsightService {
  private static final String ROOM_OPERATION = 'Library Room';
  private static final String BOOKING_OPERATION = 'Room Booking';
  // Opening-hours window shown in the hourly view (start hour of each slot).
  private static final Integer FIRST_HOUR = 8;
  private static final Integer LAST_HOUR = 21;
  private static final List<String> DAY_SHORT = new List<String>{
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  };
  private static final List<String> DAY_LONG = new List<String>{
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  };

  public class HourBucket {
    @AuraEnabled
    public Integer hour;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Integer bookings;
    @AuraEnabled
    public Integer percent;
    @AuraEnabled
    public String level;
  }

  public class DayBucket {
    @AuraEnabled
    public Integer day;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Integer bookings;
    @AuraEnabled
    public Integer percent;
    @AuraEnabled
    public String level;
  }

  public class RoomStat implements Comparable {
    @AuraEnabled
    public Id roomId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String roomType;
    @AuraEnabled
    public Integer capacity;
    @AuraEnabled
    public Integer bookings;
    @AuraEnabled
    public Integer bookedHours;
    @AuraEnabled
    public Integer sharePercent;
    @AuraEnabled
    public Integer topSeat;
    @AuraEnabled
    public String level;
    public Integer compareTo(Object other) {
      RoomStat that = (RoomStat) other;
      if (bookings == that.bookings)
        return name == null ? 0 : name.compareTo(that.name);
      return bookings > that.bookings ? -1 : 1;
    }
  }

  public class SeatStat implements Comparable {
    @AuraEnabled
    public Id roomId;
    @AuraEnabled
    public String roomName;
    @AuraEnabled
    public Integer seatNo;
    @AuraEnabled
    public Integer bookings;
    public Integer compareTo(Object other) {
      SeatStat that = (SeatStat) other;
      if (bookings == that.bookings)
        return seatNo - that.seatNo;
      return bookings > that.bookings ? -1 : 1;
    }
  }

  public class InsightsDTO {
    @AuraEnabled
    public Boolean hasData;
    @AuraEnabled
    public Integer totalBookings;
    @AuraEnabled
    public Integer activeBookings;
    @AuraEnabled
    public Integer canceledBookings;
    @AuraEnabled
    public Integer cancellationPercent;
    @AuraEnabled
    public Integer bookedHours;
    @AuraEnabled
    public String peakHourLabel;
    @AuraEnabled
    public String peakDayLabel;
    @AuraEnabled
    public List<String> quietTimes;
    @AuraEnabled
    public List<HourBucket> hours;
    @AuraEnabled
    public List<DayBucket> days;
    @AuraEnabled
    public List<RoomStat> rooms;
    @AuraEnabled
    public List<SeatStat> topSeats;
    @AuraEnabled
    public List<String> suggestions;
    @AuraEnabled
    public Datetime generatedAt;
  }

  // Librarian view: full detail including seats, with operational suggestions.
  public static InsightsDTO getInsights() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    InsightsDTO result = compute();
    result.suggestions = librarianSuggestions(result);
    return result;
  }

  // Librarian assistant view: same read-only data, gated on the circulation
  // permission that the Agentforce librarian user holds.
  public static InsightsDTO getAgentInsights() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    InsightsDTO result = compute();
    result.suggestions = librarianSuggestions(result);
    return result;
  }

  // Member view: busy times and tips only. No member data is ever exposed.
  public static InsightsDTO getForecast(String sessionToken) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    InsightsDTO result = compute();
    result.topSeats = new List<SeatStat>();
    result.suggestions = memberTips(result);
    return result;
  }

  private static InsightsDTO compute() {
    Map<Id, Map<String, Object>> rooms = new Map<Id, Map<String, Object>>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :ROOM_OPERATION AND Status__c = 'Published'
      WITH SYSTEM_MODE
      ORDER BY Created_At__c ASC
      LIMIT 200
    ]) {
      rooms.put(row.Id, parse(row.Result_Message__c));
    }

    Map<Integer, Integer> hourCounts = new Map<Integer, Integer>();
    Map<Integer, Integer> dayCounts = new Map<Integer, Integer>();
    Map<Id, Integer> roomBookings = new Map<Id, Integer>();
    Map<Id, Integer> roomHours = new Map<Id, Integer>();
    Map<String, Integer> seatCounts = new Map<String, Integer>();
    Integer active = 0;
    Integer canceled = 0;
    Integer totalHours = 0;

    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = :BOOKING_OPERATION
        AND Status__c IN ('Booked', 'Canceled')
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 2000
    ]) {
      if (row.Status__c == 'Canceled') {
        canceled++;
        continue;
      }
      Map<String, Object> payload = parse(row.Result_Message__c);
      Datetime startAt = parseDate(payload.get('s'));
      Datetime endAt = parseDate(payload.get('e'));
      Id roomId = parseId(payload.get('r'));
      if (startAt == null || endAt == null || endAt <= startAt) {
        continue;
      }
      active++;
      Integer day = Integer.valueOf(startAt.format('u'));
      dayCounts.put(day, count(dayCounts, day) + 1);
      if (roomId != null) {
        roomBookings.put(
          roomId,
          roomBookings.containsKey(roomId) ? roomBookings.get(roomId) + 1 : 1
        );
        Integer seat = integerValue(payload.get('k'));
        if (seat != null) {
          String key = String.valueOf(roomId) + '|' + String.valueOf(seat);
          seatCounts.put(
            key,
            seatCounts.containsKey(key) ? seatCounts.get(key) + 1 : 1
          );
        }
      }
      Datetime cursor = startAt;
      Integer guard = 0;
      while (cursor < endAt && guard < 12) {
        Integer hour = Integer.valueOf(cursor.format('H'));
        hourCounts.put(hour, count(hourCounts, hour) + 1);
        totalHours++;
        if (roomId != null) {
          roomHours.put(
            roomId,
            roomHours.containsKey(roomId) ? roomHours.get(roomId) + 1 : 1
          );
        }
        cursor = cursor.addHours(1);
        guard++;
      }
    }

    InsightsDTO dto = new InsightsDTO();
    dto.activeBookings = active;
    dto.canceledBookings = canceled;
    dto.totalBookings = active + canceled;
    dto.cancellationPercent = dto.totalBookings == 0
      ? 0
      : Math.round(100.0 * canceled / dto.totalBookings);
    dto.bookedHours = totalHours;
    dto.hasData = active > 0;
    dto.generatedAt = System.now();

    Integer maxHour = 0;
    Integer peakHour = null;
    for (Integer h = FIRST_HOUR; h <= LAST_HOUR; h++) {
      Integer value = count(hourCounts, h);
      if (value > maxHour) {
        maxHour = value;
        peakHour = h;
      }
    }
    dto.hours = new List<HourBucket>();
    for (Integer h = FIRST_HOUR; h <= LAST_HOUR; h++) {
      HourBucket bucket = new HourBucket();
      bucket.hour = h;
      bucket.label = hourLabel(h);
      bucket.bookings = count(hourCounts, h);
      bucket.percent = maxHour == 0
        ? 0
        : Math.round(100.0 * bucket.bookings / maxHour);
      bucket.level = level(bucket.percent, maxHour);
      dto.hours.add(bucket);
    }
    dto.peakHourLabel = peakHour == null ? null : hourRange(peakHour);
    dto.quietTimes = quietTimes(dto.hours, maxHour);

    Integer maxDay = 0;
    Integer peakDay = null;
    for (Integer d = 1; d <= 7; d++) {
      Integer value = count(dayCounts, d);
      if (value > maxDay) {
        maxDay = value;
        peakDay = d;
      }
    }
    dto.days = new List<DayBucket>();
    for (Integer d = 1; d <= 7; d++) {
      DayBucket bucket = new DayBucket();
      bucket.day = d;
      bucket.label = DAY_SHORT[d - 1];
      bucket.bookings = count(dayCounts, d);
      bucket.percent = maxDay == 0
        ? 0
        : Math.round(100.0 * bucket.bookings / maxDay);
      bucket.level = level(bucket.percent, maxDay);
      dto.days.add(bucket);
    }
    dto.peakDayLabel = peakDay == null ? null : DAY_LONG[peakDay - 1];

    Integer maxRoom = 0;
    for (Integer value : roomBookings.values()) {
      maxRoom = Math.max(maxRoom, value);
    }
    dto.rooms = new List<RoomStat>();
    for (Id roomId : rooms.keySet()) {
      Map<String, Object> room = rooms.get(roomId);
      RoomStat stat = new RoomStat();
      stat.roomId = roomId;
      stat.name = stringValue(room.get('n'));
      stat.roomType = LibraryRoomBookingService.normalizeRoomType(
        stringValue(room.get('t'))
      );
      stat.capacity = integerValue(room.get('c'));
      stat.bookings = roomBookings.containsKey(roomId)
        ? roomBookings.get(roomId)
        : 0;
      stat.bookedHours = roomHours.containsKey(roomId)
        ? roomHours.get(roomId)
        : 0;
      stat.sharePercent = active == 0
        ? 0
        : Math.round(100.0 * stat.bookings / active);
      stat.level = level(
        maxRoom == 0 ? 0 : Math.round(100.0 * stat.bookings / maxRoom),
        maxRoom
      );
      Integer bestCount = 0;
      for (String key : seatCounts.keySet()) {
        if (!key.startsWith(String.valueOf(roomId) + '|'))
          continue;
        if (seatCounts.get(key) > bestCount) {
          bestCount = seatCounts.get(key);
          stat.topSeat = Integer.valueOf(key.substringAfter('|'));
        }
      }
      dto.rooms.add(stat);
    }
    dto.rooms.sort();

    dto.topSeats = new List<SeatStat>();
    List<SeatStat> seats = new List<SeatStat>();
    for (String key : seatCounts.keySet()) {
      Id roomId = parseId(key.substringBefore('|'));
      if (roomId == null || !rooms.containsKey(roomId))
        continue;
      SeatStat seat = new SeatStat();
      seat.roomId = roomId;
      seat.roomName = stringValue(rooms.get(roomId).get('n'));
      seat.seatNo = Integer.valueOf(key.substringAfter('|'));
      seat.bookings = seatCounts.get(key);
      seats.add(seat);
    }
    seats.sort();
    for (Integer i = 0; i < Math.min(5, seats.size()); i++) {
      dto.topSeats.add(seats[i]);
    }
    return dto;
  }

  private static List<String> librarianSuggestions(InsightsDTO dto) {
    List<String> tips = new List<String>();
    if (!dto.hasData) {
      tips.add(
        'No room bookings yet. Insights and suggestions will appear once members start booking rooms.'
      );
      return tips;
    }
    Integer total = dto.bookedHours == 0 ? 1 : dto.bookedHours;
    if (dto.peakHourLabel != null) {
      Integer peakCount = 0;
      for (HourBucket bucket : dto.hours) {
        peakCount = Math.max(peakCount, bucket.bookings);
      }
      tips.add(
        'Demand peaks at ' +
          dto.peakHourLabel +
          ' (' +
          peakCount +
          ' seat-hours, ' +
          Math.round(100.0 * peakCount / total) +
          '% of all booked time). Keep staff cover then, and consider holding a spare room or extra seats ready for that hour.'
      );
    }
    if (dto.quietTimes != null && !dto.quietTimes.isEmpty()) {
      tips.add(
        'The quietest times are ' +
          String.join(dto.quietTimes, ', ') +
          '. Promote these slots to members to spread demand away from the peak.'
      );
    }
    if (dto.peakDayLabel != null) {
      tips.add(
        dto.peakDayLabel +
        ' is the busiest day. Plan extra availability or reminders for it.'
      );
    }
    if (dto.rooms.size() > 1) {
      RoomStat busiest = dto.rooms[0];
      RoomStat quietest = dto.rooms[dto.rooms.size() - 1];
      if (busiest.sharePercent >= 40 && busiest.bookings >= 3) {
        tips.add(
          busiest.name +
            ' takes ' +
            busiest.sharePercent +
            '% of all bookings. If it is often full, add seats there or steer members to ' +
            quietest.name +
            '.'
        );
      }
      if (
        quietest.sharePercent <= 10 &&
        dto.activeBookings >= 5 &&
        quietest.roomId != busiest.roomId
      ) {
        tips.add(
          quietest.name +
            ' gets only ' +
            quietest.sharePercent +
            '% of bookings. Promote it, or check its location and equipment.'
        );
      }
    }
    if (!dto.topSeats.isEmpty()) {
      SeatStat topSeat = dto.topSeats[0];
      Boolean sharedRoom = true;
      for (RoomStat room : dto.rooms) {
        if (room.roomId == topSeat.roomId && room.roomType == 'Private')
          sharedRoom = false;
      }
      if (sharedRoom && topSeat.bookings >= 3) {
        tips.add(
          'Seat ' +
            topSeat.seatNo +
            ' in ' +
            topSeat.roomName +
            ' is the most requested (' +
            topSeat.bookings +
            ' bookings). Members clearly prefer it, so look at what makes it popular and offer more like it.'
        );
      }
    }
    Integer privateRooms = 0;
    Integer privateBookings = 0;
    for (RoomStat room : dto.rooms) {
      if (room.roomType == 'Private') {
        privateRooms++;
        privateBookings += room.bookings;
      }
    }
    if (privateRooms > 0 && dto.activeBookings > 0) {
      Integer privateShare = Math.round(
        100.0 * privateBookings / dto.activeBookings
      );
      if (privateShare >= 35 && privateRooms <= 2) {
        tips.add(
          'Private rooms account for ' +
            privateShare +
            '% of bookings but are only ' +
            privateRooms +
            ' of ' +
            dto.rooms.size() +
            ' rooms. Consider adding another private room.'
        );
      }
    }
    if (dto.cancellationPercent >= 25 && dto.totalBookings >= 5) {
      tips.add(
        dto.cancellationPercent +
        '% of bookings are canceled. Send reminders before the slot, or limit repeat cancellations, to free seats for others.'
      );
    }
    return tips;
  }

  private static List<String> memberTips(InsightsDTO dto) {
    List<String> tips = new List<String>();
    if (!dto.hasData) {
      tips.add(
        'There is not enough booking history yet to predict busy times. Any time should be easy to book.'
      );
      return tips;
    }
    if (dto.peakHourLabel != null) {
      tips.add(
        'Rooms are usually busiest at ' +
          dto.peakHourLabel +
          '. Book early if you need that time.'
      );
    }
    if (dto.quietTimes != null && !dto.quietTimes.isEmpty()) {
      tips.add(
        'For the best chance of a free seat, try ' +
          String.join(dto.quietTimes, ', ') +
          '.'
      );
    }
    if (dto.peakDayLabel != null) {
      tips.add(dto.peakDayLabel + ' tends to be the busiest day of the week.');
    }
    for (RoomStat room : dto.rooms) {
      if (room.roomType == 'Private' && room.level == 'High') {
        tips.add(
          room.name +
          ' (private) is in high demand, so reserve it ahead of time.'
        );
        break;
      }
    }
    return tips;
  }

  private static List<String> quietTimes(
    List<HourBucket> hours,
    Integer maxHour
  ) {
    List<String> result = new List<String>();
    if (maxHour == 0)
      return result;
    List<HourBucket> sorted = new List<HourBucket>(hours);
    // Simple selection of the three least-booked hours.
    for (Integer pick = 0; pick < 3 && !sorted.isEmpty(); pick++) {
      Integer best = 0;
      for (Integer i = 1; i < sorted.size(); i++) {
        if (sorted[i].bookings < sorted[best].bookings)
          best = i;
      }
      HourBucket chosen = sorted.remove(best);
      if (chosen.level == 'Low')
        result.add(hourRange(chosen.hour));
    }
    return result;
  }

  private static String level(Integer percent, Integer max) {
    if (max == 0)
      return 'None';
    if (percent >= 70)
      return 'High';
    if (percent >= 35)
      return 'Medium';
    return 'Low';
  }

  private static Integer count(Map<Integer, Integer> values, Integer key) {
    return values.containsKey(key) ? values.get(key) : 0;
  }

  private static String hourLabel(Integer hour) {
    if (hour == 0)
      return '12 AM';
    if (hour < 12)
      return hour + ' AM';
    if (hour == 12)
      return '12 PM';
    return (hour - 12) + ' PM';
  }

  private static String hourRange(Integer hour) {
    return hourLabel(hour) + ' - ' + hourLabel(Math.mod(hour + 1, 24));
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
    // Same round trip as LibraryRoomBookingService: bookings are written with
    // String.valueOf(Datetime) and read back with Datetime.valueOf, so the hour
    // is the wall-clock hour in the user time zone.
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
