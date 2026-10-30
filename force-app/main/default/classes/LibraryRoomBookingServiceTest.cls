@IsTest
private class LibraryRoomBookingServiceTest {
  private static Member__c newMember(String key) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Room Plan ' + key,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 10,
      Fee__c = 10
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Room',
      Last_Name__c = key,
      Email__c = key + '@example.com',
      Normalized_Email__c = key + '@example.com',
      External_Auth_Id__c = key,
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    return member;
  }

  private static Boolean fails(
    String token,
    Id roomId,
    Integer seat,
    Datetime startAt
  ) {
    try {
      LibraryRoomBookingService.book(
        token,
        roomId,
        seat,
        startAt,
        startAt.addHours(2),
        'x'
      );
      return false;
    } catch (Exception ignored) {
      return true;
    }
  }

  @IsTest
  static void seatBookingPreventsConflictsAndCanBeCanceled() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    String tokenA = LibraryMemberSessionService.create(
      newMember('seat-a'),
      null,
      'room-test'
    );
    String tokenB = LibraryMemberSessionService.create(
      newMember('seat-b'),
      null,
      'room-test'
    );
    Id roomId = LibraryRoomBookingService.createRoom(
      'Study Room A',
      'First Floor',
      3,
      'Whiteboard'
    );
    Datetime startAt = System.now().addDays(1);
    Datetime endAt = startAt.addHours(2);

    LibraryRoomBookingService.BookingDTO booking = LibraryRoomBookingService.book(
      tokenA,
      roomId,
      2,
      startAt,
      endAt,
      'Study'
    );
    System.assertEquals('Booked', booking.status);
    System.assertEquals(2, booking.seatNumber);

    List<LibraryRoomBookingService.RoomDTO> rooms = LibraryRoomBookingService.getRooms(
      tokenB,
      startAt,
      endAt,
      1
    );
    System.assertEquals(2, rooms[0].availableSeats);
    List<LibraryRoomBookingService.SeatDTO> seats = LibraryRoomBookingService.getSeats(
      tokenB,
      roomId,
      startAt.addHours(1),
      startAt.addHours(3)
    );
    System.assertEquals(3, seats.size());
    System.assertEquals(true, seats[1].taken);
    System.assertEquals(false, seats[0].taken);

    System.assertEquals(
      true,
      fails(tokenB, roomId, 2, startAt.addHours(1)),
      'taken seat'
    );
    System.assertEquals(true, fails(tokenB, roomId, 4, startAt), 'no such seat');
    System.assertEquals(
      true,
      fails(tokenA, roomId, 3, startAt.addHours(1)),
      'member already seated'
    );
    LibraryRoomBookingService.book(
      tokenB,
      roomId,
      1,
      startAt,
      endAt,
      null
    );

    LibraryRoomBookingService.cancel(tokenA, booking.id);
    System.assertEquals(
      0,
      LibraryRoomBookingService.getMyBookings(tokenA).size()
    );
    LibraryRoomBookingService.book(tokenB, roomId, 2, startAt.addDays(1), startAt.addDays(1).addHours(1), null);
    System.assertEquals(
      2,
      LibraryRoomBookingService.getMyBookings(tokenB).size()
    );
  }

  @IsTest
  static void librarianCanListAndRetireRooms() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    String token = LibraryMemberSessionService.create(
      newMember('retire'),
      null,
      'room-test'
    );
    Id roomId = LibraryRoomBookingService.createRoom('Room B', null, 4, null);
    System.assertEquals(1, LibraryRoomBookingService.listRooms().size());
    Datetime startAt = System.now().addDays(1);
    LibraryRoomBookingService.book(
      token,
      roomId,
      1,
      startAt,
      startAt.addHours(1),
      null
    );
    LibraryRoomBookingService.retireRoom(roomId);
    System.assertEquals(0, LibraryRoomBookingService.listRooms().size());
    System.assertEquals(0, LibraryRoomBookingService.getMyBookings(token).size());
  }

  @IsTest
  static void rejectsInvalidSeatCounts() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    for (Integer seats : new List<Integer>{ 0, -1, 201 }) {
      try {
        LibraryRoomBookingService.createRoom('Bad', null, seats, null);
        System.assert(false, 'Expected failure for ' + seats);
      } catch (AuraHandledException expected) {
        System.assert(expected.getMessage() != null);
      }
    }
  }
}
