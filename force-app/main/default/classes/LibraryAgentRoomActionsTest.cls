@IsTest
private class LibraryAgentRoomActionsTest {
  private static void booking(Id roomId, Integer seat, Datetime startAt) {
    insert new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'TEST:' + String.valueOf(Crypto.getRandomLong()),
      Operation__c = 'Room Booking',
      Status__c = 'Booked',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
        new Map<String, Object>{
          'r' => String.valueOf(roomId),
          'k' => seat,
          's' => String.valueOf(startAt),
          'e' => String.valueOf(startAt.addHours(1))
        }
      )
    );
  }

  private static void seed() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Id roomId = LibraryRoomBookingService.createRoom(
      'Room A',
      'Ground',
      6,
      null
    );
    LibraryPolicyService.testGrantedPermissions.clear();
    Datetime busy = Datetime.newInstance(
      Date.today().addDays(1),
      Time.newInstance(17, 0, 0, 0)
    );
    booking(roomId, 2, busy);
    booking(roomId, 2, busy.addDays(1));
    booking(roomId, 3, busy.addHours(-8));
  }

  @IsTest
  static void librarianActionRequiresCirculationPermissionAndMapsInsights() {
    seed();
    LibraryAgentRoomInsightsAction.Response denied = LibraryAgentRoomInsightsAction.execute(
      new List<LibraryAgentRoomInsightsAction.Request>{
        new LibraryAgentRoomInsightsAction.Request()
      }
    )[0];
    System.assertEquals(false, denied.available);
    System.assertEquals(
      'Room insights are temporarily unavailable.',
      denied.message
    );

    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    LibraryAgentRoomInsightsAction.Response ok = LibraryAgentRoomInsightsAction.execute(
      new List<LibraryAgentRoomInsightsAction.Request>{
        new LibraryAgentRoomInsightsAction.Request()
      }
    )[0];
    System.assertEquals(true, ok.available);
    System.assertEquals(3, ok.totalBookings);
    System.assertEquals('5 PM - 6 PM', ok.peakHourLabel);
    System.assert(ok.busiestRoomsJson.contains('Room A'));
    System.assert(ok.topSeatsJson.contains('"seat":2'));
    System.assert(!String.isBlank(ok.suggestions));
  }

  @IsTest
  static void librarianActionHandlesNoHistory() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    LibraryAgentRoomInsightsAction.Response empty = LibraryAgentRoomInsightsAction.execute(
      new List<LibraryAgentRoomInsightsAction.Request>{
        new LibraryAgentRoomInsightsAction.Request()
      }
    )[0];
    System.assertEquals(false, empty.available);
    System.assert(empty.message.contains('no room bookings'));
  }

  @IsTest
  static void memberActionReturnsAnonymousBusyTimesOnly() {
    seed();
    Member__c member = new Member__c(
      First_Name__c = 'Forecast',
      Last_Name__c = 'Reader',
      Email__c = 'forecast-reader@example.com',
      Normalized_Email__c = 'forecast-reader@example.com',
      Status__c = 'Active',
      Account_Status__c = 'Active'
    );
    insert member;
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'Agent test'
    );
    LibraryAgentRoomForecastAction.Request request = new LibraryAgentRoomForecastAction.Request();
    request.sessionToken = token;
    LibraryAgentRoomForecastAction.Response ok = LibraryAgentRoomForecastAction.execute(
      new List<LibraryAgentRoomForecastAction.Request>{ request }
    )[0];
    System.assertEquals(true, ok.available);
    System.assertEquals('5 PM - 6 PM', ok.peakHourLabel);
    System.assert(ok.busyHoursJson.contains('demand'));
    System.assert(!ok.busyHoursJson.contains('Room A'));
    System.assert(!String.isBlank(ok.tips));

    request.sessionToken = 'not-a-session-token';
    Boolean rejected = false;
    try {
      LibraryAgentRoomForecastAction.execute(
        new List<LibraryAgentRoomForecastAction.Request>{ request }
      );
    } catch (Exception ex) {
      rejected = true;
    }
    System.assertEquals(true, rejected);
  }
}
