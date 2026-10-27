@IsTest
private class LibraryEventServiceTest {
  @IsTest
  static void eventRegistrationIsIdempotentAndCancelable() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Event Plan',
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
      First_Name__c = 'Event',
      Last_Name__c = 'Member',
      Email__c = 'event-member@example.com',
      Normalized_Email__c = 'event-member@example.com',
      External_Auth_Id__c = 'event-member',
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
      'event-test'
    );
    Id eventId = LibraryEventService.create(
      'Story Hour',
      'A community reading event',
      System.now().addDays(2),
      System.now().addDays(2).addHours(1),
      1,
      'Main Hall'
    );
    LibraryEventService.EventDTO first = LibraryEventService.register(
      token,
      eventId
    );
    LibraryEventService.EventDTO second = LibraryEventService.register(
      token,
      eventId
    );
    System.assertEquals('Registered', first.registrationStatus);
    System.assertEquals(first.registrationStatus, second.registrationStatus);
    Member__c waitlistedMember = new Member__c(
      First_Name__c = 'Waitlisted',
      Last_Name__c = 'Member',
      Email__c = 'event-waitlisted@example.com',
      Normalized_Email__c = 'event-waitlisted@example.com',
      External_Auth_Id__c = 'event-waitlisted',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert waitlistedMember;
    String waitlistedToken = LibraryMemberSessionService.create(
      waitlistedMember,
      null,
      'event-waitlisted-test'
    );
    LibraryEventService.EventDTO waiting = LibraryEventService.register(
      waitlistedToken,
      eventId
    );
    System.assertEquals('Waitlisted', waiting.registrationStatus);
    System.assertEquals(1, LibraryEventService.getUpcoming(token).size());
    LibraryEventService.cancel(token, eventId);
    System.assertEquals(
      'Registered',
      LibraryEventService.getUpcoming(waitlistedToken)[0].registrationStatus
    );
    String checkInToken = LibraryEventService.issueCheckInToken(
      waitlistedToken,
      eventId
    );
    LibraryEventService.CheckInDTO checkedIn = LibraryEventService.checkIn(
      eventId,
      checkInToken
    );
    System.assertEquals('Attended', checkedIn.status);
    System.assertEquals(
      'Attended',
      LibraryEventService.getUpcoming(waitlistedToken)[0].registrationStatus
    );
  }
}
