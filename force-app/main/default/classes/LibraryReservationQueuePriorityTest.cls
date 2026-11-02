@IsTest
private class LibraryReservationQueuePriorityTest {
  private static Member__c member(String suffix, Id planId) {
    Account account = new Account(Name = 'QP Account ' + suffix);
    insert account;
    Contact contact = new Contact(
      FirstName = 'QP',
      LastName = suffix,
      Email = 'qp-' + suffix.toLowerCase() + '@example.com',
      AccountId = account.Id
    );
    insert contact;
    Member__c row = new Member__c(
      First_Name__c = 'QP',
      Last_Name__c = suffix,
      Email__c = contact.Email,
      Contact__c = contact.Id,
      External_Auth_Id__c = 'qp-' + suffix,
      Email_Verified__c = true,
      Account_Status__c = 'Active',
      Membership_Plan__c = planId,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 5,
      Status__c = 'Active'
    );
    insert row;
    return row;
  }

  private static Membership_Plan__c plan(String name, Decimal priority) {
    Membership_Plan__c row = new Membership_Plan__c(
      Name = name,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 5,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5,
      Queue_Priority__c = priority
    );
    insert row;
    return row;
  }

  private static Book__c book(String suffix) {
    Book__c row = new Book__c(
      Name = 'QP Book ' + suffix,
      ISBN__c = 'QP-' + suffix,
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 0
    );
    insert row;
    return row;
  }

  private static Decimal positionFor(Id reservationId) {
    return [
      SELECT Queue_Position__c
      FROM Reservation__c
      WHERE Id = :reservationId
    ]
    .Queue_Position__c;
  }

  @IsTest
  static void higherPriorityPlanJumpsAheadThenReservationTimeBreaksTies() {
    Membership_Plan__c gold = plan('QP Gold', 1);
    Membership_Plan__c basic = plan('QP Basic', 2);
    Membership_Plan__c unranked = plan('QP Unranked', null);
    Book__c bookA = book('A');
    Book__c bookB = book('B');
    Member__c unrankedMember = member('Unranked', unranked.Id);
    Member__c basicOne = member('BasicOne', basic.Id);
    Member__c basicTwo = member('BasicTwo', basic.Id);
    Member__c goldMember = member('Gold', gold.Id);

    Test.startTest();
    Id unrankedRes = LibraryCirculationService.createReservationForMember(
      unrankedMember,
      bookA.Id
    );
    Id basicOneRes = LibraryCirculationService.createReservationForMember(
      basicOne,
      bookA.Id
    );
    Id basicTwoRes = LibraryCirculationService.createReservationForMember(
      basicTwo,
      bookA.Id
    );
    Id goldRes = LibraryCirculationService.createReservationForMember(
      goldMember,
      bookA.Id
    );
    // A different book keeps its own, independent queue.
    Id otherBookRes = LibraryCirculationService.createReservationForMember(
      unrankedMember,
      bookB.Id
    );
    Test.stopTest();

    System.assertEquals(1, positionFor(goldRes), 'Gold plan is served first');
    System.assertEquals(
      2,
      positionFor(basicOneRes),
      'Earlier basic member next'
    );
    System.assertEquals(
      3,
      positionFor(basicTwoRes),
      'Later basic member after'
    );
    System.assertEquals(4, positionFor(unrankedRes), 'Unranked plan is last');
    System.assertEquals(
      1,
      positionFor(otherBookRes),
      'Each book has its own queue'
    );
  }

  @IsTest
  static void cancellingClosesTheGapPerBook() {
    Membership_Plan__c gold = plan('QP Gold C', 1);
    Membership_Plan__c basic = plan('QP Basic C', 2);
    Book__c bookA = book('CA');
    Member__c basicMember = member('BasicC', basic.Id);
    Member__c goldMember = member('GoldC', gold.Id);
    Id basicRes = LibraryCirculationService.createReservationForMember(
      basicMember,
      bookA.Id
    );
    Id goldRes = LibraryCirculationService.createReservationForMember(
      goldMember,
      bookA.Id
    );
    System.assertEquals(2, positionFor(basicRes));

    LibraryCirculationService.cancelReservationForMember(
      goldRes,
      goldMember.Id
    );

    System.assertEquals(1, positionFor(basicRes));
  }
}
