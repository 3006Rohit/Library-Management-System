@IsTest
private class LibraryMemberControllerTest {
  @TestSetup
  static void setup() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Member Test Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 10,
      Fee__c = 100
    );
    insert plan;
    Account account = new Account(Name = 'Member Test Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Mapped',
      LastName = 'Member',
      Email = 'mapped@example.com',
      AccountId = account.Id,
      Phone = '+91 9999999999',
      MailingStreet = 'Original address'
    );
    insert contact;
    Member__c member = new Member__c(
      First_Name__c = 'Mapped',
      Last_Name__c = 'Member',
      Email__c = 'mapped@example.com',
      Normalized_Email__c = 'mapped@example.com',
      Contact__c = contact.Id,
      Membership_Plan__c = plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3,
      Status__c = 'Active',
      Account_Status__c = 'Active'
    );
    insert member;
    Book__c book = new Book__c(
      Name = 'Member Test Book',
      ISBN__c = 'MEMBER-TEST-ISBN',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 0
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'MEMBER-TEST-COPY',
      Status__c = 'Borrowed',
      Condition__c = 'Good'
    );
    insert copy;
    Borrow_Record__c loan = new Borrow_Record__c(
      Member__c = member.Id,
      Contact__c = contact.Id,
      Book_Copy__c = copy.Id,
      Borrow_Date__c = System.now(),
      Due_Date__c = System.now().addDays(14),
      Status__c = 'Active',
      Renewal_Count__c = 0
    );
    insert loan;
    insert new Reservation__c(
      Member__c = member.Id,
      Contact__c = contact.Id,
      Book__c = book.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 1
    );
    insert new Fine__c(
      Member__c = member.Id,
      Contact__c = contact.Id,
      Borrow_Record__c = loan.Id,
      Fine_Type__c = 'Other',
      Amount__c = 10,
      Paid_Amount__c = 0,
      Status__c = 'Unpaid',
      Generated_Date__c = Date.today()
    );
    insert new Membership_Payment__c(
      Member__c = member.Id,
      New_Plan__c = plan.Id,
      Amount__c = 100,
      Status__c = 'Paid',
      Payment_Method__c = 'Demo Payment',
      Payment_Date__c = System.now(),
      Transaction_Reference__c = 'TEST-PAYMENT'
    );
    insert new Member_Notification__c(
      Member__c = member.Id,
      Type__c = 'General',
      Subject__c = 'Test',
      Message__c = 'Test notification',
      Status__c = 'Unread',
      Dedup_Key__c = 'MEMBER-TEST-NOTIFICATION'
    );

    Contact otherContact = new Contact(
      FirstName = 'Other',
      LastName = 'Member',
      Email = 'other-member@example.com',
      AccountId = account.Id
    );
    insert otherContact;
    Member__c otherMember = new Member__c(
      First_Name__c = 'Other',
      Last_Name__c = 'Member',
      Email__c = 'other-member@example.com',
      Normalized_Email__c = 'other-member@example.com',
      Contact__c = otherContact.Id,
      Membership_Plan__c = plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3,
      Status__c = 'Active',
      Account_Status__c = 'Active'
    );
    insert otherMember;
    Book_Copy__c otherCopy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'MEMBER-TEST-OTHER-COPY',
      Status__c = 'Borrowed',
      Condition__c = 'Good'
    );
    insert otherCopy;
    Borrow_Record__c otherLoan = new Borrow_Record__c(
      Member__c = otherMember.Id,
      Book_Copy__c = otherCopy.Id,
      Borrow_Date__c = System.now(),
      Due_Date__c = System.now().addDays(14),
      Status__c = 'Active',
      Renewal_Count__c = 0
    );
    insert otherLoan;
    insert new Reservation__c(
      Member__c = otherMember.Id,
      Book__c = book.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 2
    );
    insert new Fine__c(
      Member__c = otherMember.Id,
      Borrow_Record__c = otherLoan.Id,
      Fine_Type__c = 'Other',
      Amount__c = 20,
      Paid_Amount__c = 0,
      Status__c = 'Unpaid',
      Generated_Date__c = Date.today()
    );
    insert new Membership_Payment__c(
      Member__c = otherMember.Id,
      New_Plan__c = plan.Id,
      Amount__c = 200,
      Status__c = 'Paid',
      Payment_Method__c = 'Demo Payment',
      Payment_Date__c = System.now(),
      Transaction_Reference__c = 'OTHER-TEST-PAYMENT'
    );
    insert new Member_Notification__c(
      Member__c = otherMember.Id,
      Type__c = 'General',
      Subject__c = 'Other test',
      Message__c = 'Other member notification',
      Status__c = 'Unread',
      Dedup_Key__c = 'OTHER-MEMBER-TEST-NOTIFICATION'
    );
  }

  private static Member__c mappedMember() {
    return [
      SELECT Id, Contact__c
      FROM Member__c
      WHERE Email__c = 'mapped@example.com'
      LIMIT 1
    ];
  }
  private static void authenticate(Member__c member) {
    LibraryMemberController.testUserId = UserInfo.getUserId();
    LibraryMemberIdentityService.testContactId = member.Contact__c;
  }

  @IsTest
  static void mappedMemberCanReadOnlyOwnPortalData() {
    Member__c member = mappedMember();
    authenticate(member);
    Member__c context = LibraryMemberController.getCurrentMemberContext();
    LibraryMemberController.DashboardData dashboard = LibraryMemberController.getMyDashboard();
    System.assertEquals(member.Id, context.Id);
    System.assertEquals(member.Id, dashboard.member.Id);
    System.assertEquals(1, dashboard.activeLoans);
    System.assertEquals(1, dashboard.activeReservations);
    System.assertEquals(10, dashboard.outstandingFine);
    System.assertEquals(1, LibraryMemberController.getMyBorrowings().size());
    System.assertEquals(1, LibraryMemberController.getMyReservations().size());
    System.assertEquals(1, LibraryMemberController.getMyFines().size());
    System.assertEquals(1, LibraryMemberController.getMyPayments().size());
    System.assertEquals(member.Id, LibraryMemberController.getMyProfile().Id);
    System.assertEquals(
      member.Id,
      LibraryMemberController.getMyMembership().Id
    );
    Book__c book = [SELECT Id FROM Book__c WHERE ISBN__c = 'MEMBER-TEST-ISBN'];
    System.assertEquals(
      1,
      LibraryMemberController.searchCatalog('Member Test', null, null, 20, 1)
        .size()
    );
    System.assertEquals(
      book.Id,
      LibraryMemberController.getBookDetails(book.Id).Id
    );
    System.assertNotEquals(
      null,
      LibraryMemberController.getCatalogCategories()
    );
    System.assertNotEquals(null, LibraryMemberController.getUpgradePlans());
    Member_Notification__c notification = LibraryMemberController.getMyNotifications()[0];
    LibraryMemberController.markNotificationRead(notification.Id);
    System.assertEquals(
      'Read',
      [SELECT Status__c FROM Member_Notification__c WHERE Id = :notification.Id]
      .Status__c
    );
  }

  @IsTest
  static void memberCanMutateOnlyOwnLoanAndReservation() {
    Member__c member = mappedMember();
    authenticate(member);
    Borrow_Record__c loan = [
      SELECT Id
      FROM Borrow_Record__c
      WHERE Member__c = :member.Id
      LIMIT 1
    ];
    LibraryMemberController.renewMyLoan(loan.Id);
    System.assertEquals(
      1,
      [SELECT Renewal_Count__c FROM Borrow_Record__c WHERE Id = :loan.Id]
      .Renewal_Count__c
    );
    Reservation__c reservation = [
      SELECT Id
      FROM Reservation__c
      WHERE Member__c = :member.Id
      LIMIT 1
    ];
    LibraryMemberController.cancelMyReservation(reservation.Id);
    System.assertEquals(
      'Cancelled',
      [SELECT Status__c FROM Reservation__c WHERE Id = :reservation.Id]
      .Status__c
    );
    Book__c book = [SELECT Id FROM Book__c WHERE ISBN__c = 'MEMBER-TEST-ISBN'];
    System.assertNotEquals(null, LibraryMemberController.reserveBook(book.Id));
  }

  @IsTest
  static void memberCannotReadOrMutateAnotherMembersRecords() {
    Member__c member = mappedMember();
    Member__c other = [
      SELECT Id
      FROM Member__c
      WHERE Email__c = 'other-member@example.com'
      LIMIT 1
    ];
    authenticate(member);

    System.assertEquals(member.Id, LibraryMemberController.getMyProfile().Id);
    System.assertNotEquals(other.Id, LibraryMemberController.getMyProfile().Id);
    System.assertEquals(1, LibraryMemberController.getMyBorrowings().size());
    System.assertEquals(1, LibraryMemberController.getMyReservations().size());
    System.assertEquals(1, LibraryMemberController.getMyFines().size());
    System.assertEquals(1, LibraryMemberController.getMyPayments().size());
    System.assertEquals(1, LibraryMemberController.getMyNotifications().size());

    Borrow_Record__c otherLoan = [
      SELECT Id, Renewal_Count__c
      FROM Borrow_Record__c
      WHERE Member__c = :other.Id
      LIMIT 1
    ];
    Reservation__c otherReservation = [
      SELECT Id, Status__c
      FROM Reservation__c
      WHERE Member__c = :other.Id
      LIMIT 1
    ];
    Boolean loanDenied = false;
    Boolean reservationDenied = false;
    try {
      LibraryMemberController.renewMyLoan(otherLoan.Id);
    } catch (AuraHandledException expected) {
      loanDenied = true;
    }
    try {
      LibraryMemberController.cancelMyReservation(otherReservation.Id);
    } catch (AuraHandledException expected) {
      reservationDenied = true;
    }
    System.assertEquals(true, loanDenied);
    System.assertEquals(true, reservationDenied);
    System.assertEquals(
      otherLoan.Renewal_Count__c,
      [SELECT Renewal_Count__c FROM Borrow_Record__c WHERE Id = :otherLoan.Id]
      .Renewal_Count__c
    );
    System.assertEquals(
      otherReservation.Status__c,
      [SELECT Status__c FROM Reservation__c WHERE Id = :otherReservation.Id]
      .Status__c
    );
  }

  @IsTest
  static void invalidRecordIdsCannotMutateMemberData() {
    Member__c member = mappedMember();
    authenticate(member);
    Id wrongObjectId = [
      SELECT Id
      FROM Membership_Payment__c
      WHERE Member__c = :member.Id
      LIMIT 1
    ]
    .Id;
    Integer failures = 0;
    try {
      LibraryMemberController.renewMyLoan(wrongObjectId);
    } catch (Exception expected) {
      failures++;
    }
    try {
      LibraryMemberController.cancelMyReservation(wrongObjectId);
    } catch (Exception expected) {
      failures++;
    }
    System.assertEquals(2, failures);
  }

  @IsTest
  static void contactSharingKeysAreMaintained() {
    Member__c member = mappedMember();
    Membership_Payment__c payment = new Membership_Payment__c(
      Member__c = member.Id
    );
    Member_Notification__c notification = new Member_Notification__c(
      Member__c = member.Id
    );
    LibraryTransactionContactService.syncMembershipPayments(
      new List<Membership_Payment__c>{ payment }
    );
    LibraryTransactionContactService.syncMemberNotifications(
      new List<Member_Notification__c>{ notification }
    );
    System.assertEquals(member.Contact__c, payment.get('Contact__c'));
    System.assertEquals(member.Contact__c, notification.get('Contact__c'));

    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Member Test Account'
    ];
    Contact replacement = new Contact(
      LastName = 'Replacement',
      Email = 'replacement-member@example.com',
      AccountId = account.Id
    );
    insert replacement;
    update new Member__c(Id = member.Id, Contact__c = replacement.Id);

    System.assertEquals(
      replacement.Id,
      [
        SELECT Contact__c
        FROM Borrow_Record__c
        WHERE Member__c = :member.Id
        LIMIT 1
      ]
      .Contact__c
    );
    System.assertEquals(
      replacement.Id,
      [
        SELECT Contact__c
        FROM Reservation__c
        WHERE Member__c = :member.Id
        LIMIT 1
      ]
      .Contact__c
    );
  }

  @IsTest
  static void profileUpdateSynchronizesOnlyMappedContact() {
    Member__c member = mappedMember();
    authenticate(member);
    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Member Test Account'
    ];
    Contact other = new Contact(
      LastName = 'Other',
      Email = 'other@example.com',
      AccountId = account.Id,
      Phone = '111'
    );
    insert other;
    LibraryMemberController.updateMyProfile(
      'Updated',
      'Member',
      '+91 8888888888',
      'Updated address'
    );
    Contact mapped = [
      SELECT FirstName, Phone, MailingStreet
      FROM Contact
      WHERE Id = :member.Contact__c
    ];
    other = [SELECT Phone FROM Contact WHERE Id = :other.Id];
    System.assertEquals('Updated', mapped.FirstName);
    System.assertEquals('+91 8888888888', mapped.Phone);
    System.assertEquals('Updated address', mapped.MailingStreet);
    System.assertEquals('111', other.Phone);
  }

  @IsTest
  static void memberBorrowUsesAuthenticatedIdentityAndFulfillsReadyReservation() {
    Member__c member = mappedMember();
    authenticate(member);
    Fine__c fine = [
      SELECT Id, Amount__c
      FROM Fine__c
      WHERE Member__c = :member.Id
      LIMIT 1
    ];
    fine.Status__c = 'Paid';
    fine.Paid_Amount__c = fine.Amount__c;
    update fine;
    Book__c book = new Book__c(
      Name = 'Ready Member Book',
      ISBN__c = 'READY-MEMBER-ISBN',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'READY-MEMBER-COPY',
      Status__c = 'Reserved',
      Condition__c = 'Good'
    );
    insert copy;
    Reservation__c ready = new Reservation__c(
      Member__c = member.Id,
      Contact__c = member.Contact__c,
      Book__c = book.Id,
      Book_Copy__c = copy.Id,
      Reservation_Date__c = System.now().addDays(-1),
      Ready_Date__c = System.now(),
      Status__c = 'Ready',
      Queue_Position__c = 1
    );
    insert ready;
    Test.startTest();
    Id loanId = LibraryMemberController.borrowBook(book.Id);
    Test.stopTest();
    Borrow_Record__c loan = [
      SELECT Member__c, Book_Copy__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
    ];
    ready = [
      SELECT Status__c, Fulfilled_Date__c
      FROM Reservation__c
      WHERE Id = :ready.Id
    ];
    System.assertEquals(member.Id, loan.Member__c);
    System.assertEquals(copy.Id, loan.Book_Copy__c);
    System.assertEquals('Fulfilled', ready.Status__c);
    System.assertNotEquals(null, ready.Fulfilled_Date__c);
  }

  @IsTest
  static void missingDuplicateMismatchAndInactiveMappingsAreDenied() {
    Member__c member = mappedMember();
    System.assertEquals(
      'MEMBER_MAPPING_NOT_FOUND',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>(),
        member.Contact__c
      )
    );
    Member__c mapping = new Member__c(
      Contact__c = member.Contact__c,
      Status__c = 'Active'
    );
    System.assertEquals(
      'MEMBER_MAPPING_DUPLICATE',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>{ mapping, mapping.clone() },
        member.Contact__c
      )
    );
    System.assertEquals(
      'CONTACT_MAPPING_MISMATCH',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>{ mapping },
        UserInfo.getUserId()
      )
    );
    mapping.Account_Status__c = 'Pending';
    System.assertEquals(
      'MEMBER_PENDING_APPROVAL',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>{ mapping },
        member.Contact__c
      )
    );
    mapping.Account_Status__c = 'Rejected';
    System.assertEquals(
      'MEMBER_REJECTED',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>{ mapping },
        member.Contact__c
      )
    );
    mapping.Account_Status__c = 'Suspended';
    System.assertEquals(
      'MEMBER_SUSPENDED',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>{ mapping },
        member.Contact__c
      )
    );
    mapping.Account_Status__c = null;
    mapping.Status__c = 'Suspended';
    System.assertEquals(
      'MEMBER_INACTIVE',
      LibraryMemberIdentityService.mappingCode(
        new List<Member__c>{ mapping },
        member.Contact__c
      )
    );
    for (
      String code : new List<String>{
        'MEMBER_MAPPING_NOT_FOUND',
        'MEMBER_MAPPING_DUPLICATE',
        'CONTACT_MAPPING_MISMATCH',
        'MEMBER_PENDING_APPROVAL',
        'MEMBER_REJECTED',
        'MEMBER_SUSPENDED',
        'MEMBER_INACTIVE',
        'MEMBER_RECORD_NOT_FOUND',
        'MEMBER_FIELD_ACCESS_DENIED'
      }
    )
      System.assertNotEquals(null, LibraryMemberIdentityService.failure(code));
    LibraryMemberController.testUserId = UserInfo.getUserId();
    LibraryMemberIdentityService.testContactId = null;
    Boolean denied = false;
    try {
      LibraryMemberController.getCurrentMemberContext();
    } catch (AuraHandledException expected) {
      denied = true;
    }
    System.assertEquals(true, denied);
  }
}
