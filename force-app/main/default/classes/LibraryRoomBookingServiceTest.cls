@IsTest
private class LibraryRoomBookingServiceTest {
  @IsTest
  static void roomBookingPreventsOverlapAndCanBeCanceled() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Room Plan',
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
      Last_Name__c = 'Member',
      Email__c = 'room-member@example.com',
      Normalized_Email__c = 'room-member@example.com',
      External_Auth_Id__c = 'room-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'room-test'
    );
    Id roomId = LibraryRoomBookingService.createRoom(
      'Study Room A',
      'First Floor',
      6,
      'Whiteboard'
    );
    Datetime startAt = System.now().addDays(1);
    LibraryRoomBookingService.BookingDTO booking = LibraryRoomBookingService.book(
      token,
      roomId,
      startAt,
      startAt.addHours(2),
      'Study group'
    );
    System.assertEquals('Booked', booking.status);
    Boolean blocked = false;
    try {
      LibraryRoomBookingService.book(
        token,
        roomId,
        startAt.addHours(1),
        startAt.addHours(3),
        'Overlap'
      );
    } catch (Exception ignored) {
      blocked = true;
    }
    System.assertEquals(true, blocked);
    System.assertEquals(
      1,
      LibraryRoomBookingService.getMyBookings(token).size()
    );
    LibraryRoomBookingService.cancel(token, booking.id);
    System.assertEquals(
      0,
      LibraryRoomBookingService.getMyBookings(token).size()
    );
  }
}
