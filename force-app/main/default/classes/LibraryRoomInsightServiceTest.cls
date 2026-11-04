@IsTest
private class LibraryRoomInsightServiceTest {
  private static Member__c member(String key) {
    Member__c value = new Member__c(
      First_Name__c = 'Room',
      Last_Name__c = key,
      Email__c = key + '@example.com',
      Normalized_Email__c = key + '@example.com',
      Status__c = 'Active',
      Account_Status__c = 'Active'
    );
    insert value;
    return value;
  }

  private static void booking(
    Id roomId,
    Integer seat,
    Datetime startAt,
    Integer hours,
    String status
  ) {
    insert new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'TEST:' + String.valueOf(Crypto.getRandomLong()),
      Operation__c = 'Room Booking',
      Status__c = status,
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
        new Map<String, Object>{
          'r' => String.valueOf(roomId),
          'k' => seat,
          's' => String.valueOf(startAt),
          'e' => String.valueOf(startAt.addHours(hours))
        }
      )
    );
  }

  private static Datetime at(Date day, Integer hour) {
    return Datetime.newInstance(day, Time.newInstance(hour, 0, 0, 0));
  }

  @IsTest
  static void privateRoomsAreSingleSeatAndDefaultsAreShared() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Id privateId = LibraryRoomBookingService.createRoom(
      'Quiet Pod',
      'Ground',
      8,
      'Desk',
      'Private'
    );
    Id sharedId = LibraryRoomBookingService.createRoom(
      'Group Room',
      null,
      6,
      null
    );
    Id oddId = LibraryRoomBookingService.createRoom(
      'Odd Type',
      null,
      4,
      null,
      'whatever'
    );
    Map<Id, LibraryRoomBookingService.RoomDTO> rooms = new Map<Id, LibraryRoomBookingService.RoomDTO>();
    for (
      LibraryRoomBookingService.RoomDTO room : LibraryRoomBookingService.listRooms()
    ) {
      rooms.put(room.id, room);
    }
    System.assertEquals(1, rooms.get(privateId).capacity);
    System.assertEquals('Private', rooms.get(privateId).roomType);
    System.assertEquals(true, rooms.get(privateId).isPrivate);
    System.assertEquals(6, rooms.get(sharedId).capacity);
    System.assertEquals('Shared', rooms.get(sharedId).roomType);
    System.assertEquals('Shared', rooms.get(oddId).roomType);
  }

  @IsTest
  static void insightsFindPeakTimesBusiestRoomAndSeat() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Id roomA = LibraryRoomBookingService.createRoom('Room A', null, 4, null);
    Id pod = LibraryRoomBookingService.createRoom(
      'Pod',
      null,
      1,
      null,
      'Private'
    );
    Date day = Date.today().addDays(-7);
    booking(roomA, 1, at(day, 17), 1, 'Booked');
    booking(roomA, 1, at(day, 17), 1, 'Booked');
    booking(roomA, 1, at(day, 17), 1, 'Booked');
    booking(roomA, 3, at(day, 10), 1, 'Booked');
    booking(pod, 1, at(day, 17), 1, 'Booked');
    booking(pod, 1, at(day, 17), 1, 'Booked');
    booking(roomA, 4, at(day, 12), 1, 'Canceled');

    LibraryRoomInsightService.InsightsDTO result = LibraryRoomInsightService.getInsights();

    System.assertEquals(true, result.hasData);
    System.assertEquals(6, result.activeBookings);
    System.assertEquals(1, result.canceledBookings);
    System.assertEquals(7, result.totalBookings);
    System.assertEquals(14, result.cancellationPercent);
    System.assertEquals('5 PM - 6 PM', result.peakHourLabel);
    String weekday = at(day, 12).format('E');
    System.assertEquals(weekday, result.peakDayLabel.left(3));
    System.assertEquals(14, result.hours.size());
    System.assertEquals(7, result.days.size());
    System.assertEquals('Room A', result.rooms[0].name);
    System.assertEquals(4, result.rooms[0].bookings);
    System.assertEquals(67, result.rooms[0].sharePercent);
    System.assertEquals(1, result.rooms[0].topSeat);
    System.assertEquals('Private', result.rooms[1].roomType);
    System.assertEquals('Room A', result.topSeats[0].roomName);
    System.assertEquals(1, result.topSeats[0].seatNo);
    System.assertEquals(3, result.quietTimes.size());
    String joined = String.join(result.suggestions, ' | ');
    System.assert(joined.contains('Demand peaks at 5 PM - 6 PM'), joined);
    System.assert(joined.contains('Room A takes 67%'), joined);
    System.assert(joined.contains('quietest times'), joined);
  }

  @IsTest
  static void memberForecastShowsBusyTimesWithoutSeatDetail() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Id roomA = LibraryRoomBookingService.createRoom('Room A', null, 4, null);
    Date day = Date.today().addDays(-3);
    booking(roomA, 1, at(day, 15), 2, 'Booked');
    booking(roomA, 2, at(day, 15), 1, 'Booked');
    String token = LibraryMemberSessionService.create(
      member('forecast'),
      null,
      'insight-test'
    );

    LibraryRoomInsightService.InsightsDTO result = LibraryRoomInsightService.getForecast(
      token
    );

    System.assertEquals(true, result.hasData);
    System.assertEquals('3 PM - 4 PM', result.peakHourLabel);
    System.assertEquals(0, result.topSeats.size());
    System.assert(!result.suggestions.isEmpty());
    System.assert(
      String.join(result.suggestions, ' ').contains('busiest at 3 PM'),
      String.join(result.suggestions, ' ')
    );
  }

  @IsTest
  static void emptyHistoryExplainsThereIsNothingToPredict() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    LibraryRoomInsightService.InsightsDTO result = LibraryRoomInsightService.getInsights();
    System.assertEquals(false, result.hasData);
    System.assertEquals(0, result.activeBookings);
    System.assertEquals(null, result.peakHourLabel);
    System.assertEquals(1, result.suggestions.size());
    System.assert(result.suggestions[0].contains('No room bookings yet'));
  }

  @IsTest
  static void librarianInsightsRequireCatalogPermission() {
    try {
      LibraryRoomInsightService.getInsights();
      System.assert(false, 'Expected the permission check to fail.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }
}
