@IsTest
private class LibraryAgentTransactionsTest {
  private static Member__c member(String key) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Txn Plan ' + key,
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
    Member__c value = new Member__c(
      First_Name__c = 'Txn',
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
    insert value;
    return value;
  }

  private static String session(Member__c value) {
    return LibraryMemberSessionService.create(value, null, 'txn-test');
  }

  private static Book__c book(String name, String isbn, Boolean available) {
    Book__c value = new Book__c(
      Name = name,
      ISBN__c = isbn,
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = available ? 1 : 0
    );
    insert value;
    insert new Book_Copy__c(
      Book__c = value.Id,
      Barcode__c = isbn + '-COPY',
      Status__c = available ? 'Available' : 'Borrowed',
      Condition__c = 'Good'
    );
    return value;
  }

  private static LibraryAgentPrepareTransactionAction.Response prepare(
    LibraryAgentPrepareTransactionAction.Request request
  ) {
    return LibraryAgentPrepareTransactionAction.execute(
      new List<LibraryAgentPrepareTransactionAction.Request>{ request }
    )[0];
  }

  private static LibraryAgentPrepareTransactionAction.Request req(
    String token,
    String action,
    String name
  ) {
    LibraryAgentPrepareTransactionAction.Request request = new LibraryAgentPrepareTransactionAction.Request();
    request.sessionToken = token;
    request.action = action;
    request.targetName = name;
    return request;
  }

  private static LibraryAgentCommitTransactionAction.Response confirmWith(
    String token,
    String confirmation
  ) {
    LibraryAgentCommitTransactionAction.Request request = new LibraryAgentCommitTransactionAction.Request();
    request.sessionToken = token;
    request.confirmationToken = confirmation;
    return LibraryAgentCommitTransactionAction.execute(
      new List<LibraryAgentCommitTransactionAction.Request>{ request }
    )[0];
  }

  private static String futureTime(Integer days, String clock) {
    return String.valueOf(Date.today().addDays(days)) + ' ' + clock;
  }

  @IsTest
  static void borrowIsPreviewedThenSubmittedOnceForApproval() {
    String token = session(member('txn-borrow'));
    Book__c wanted = book('Alpha Atlas', 'TXN-ALPHA', true);

    LibraryAgentPrepareTransactionAction.Response prepared = prepare(
      req(token, 'borrow_book', 'alpha atlas')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assert(prepared.preview.contains('Alpha Atlas'));
    System.assert(prepared.preview.contains('librarian must approve'));
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending'],
      'Preparing must not write anything.'
    );

    LibraryAgentCommitTransactionAction.Response done = confirmWith(
      token,
      prepared.confirmationToken
    );
    System.assertEquals(true, done.committed, done.message);
    System.assert(done.message.contains('awaiting librarian approval'));
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending']
    );

    // The same confirmation cannot be replayed.
    System.assertEquals(
      false,
      confirmWith(token, prepared.confirmationToken).committed
    );
    System.assertNotEquals(null, wanted.Id);
  }

  @IsTest
  static void borrowingAnUnavailableTitleSuggestsReserving() {
    String token = session(member('txn-unavail'));
    book('Gone Girl Guide', 'TXN-GONE', false);
    LibraryAgentPrepareTransactionAction.Response result = prepare(
      req(token, 'BORROW_BOOK', 'Gone Girl Guide')
    );
    System.assertEquals(false, result.prepared);
    System.assert(result.message.contains('reserved instead'), result.message);
  }

  @IsTest
  static void reservationJoinsTheQueueAfterConfirmation() {
    Member__c reader = member('txn-reserve');
    String token = session(reader);
    Book__c wanted = book('Borrowed Bestseller', 'TXN-RES', false);
    LibraryAgentPrepareTransactionAction.Response prepared = prepare(
      req(token, 'RESERVE_BOOK', 'Borrowed Bestseller')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assert(prepared.preview.contains('join the queue'));
    LibraryAgentCommitTransactionAction.Response done = confirmWith(
      token,
      prepared.confirmationToken
    );
    System.assertEquals(true, done.committed, done.message);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Reservation__c
        WHERE Member__c = :reader.Id AND Book__c = :wanted.Id
      ]
    );
    // A second reservation of the same title is refused at preview.
    System.assertEquals(
      false,
      prepare(req(token, 'RESERVE_BOOK', 'Borrowed Bestseller')).prepared
    );
  }

  @IsTest
  static void ambiguousAndUnknownTitlesAreNotGuessed() {
    String token = session(member('txn-ambig'));
    book('Ocean Tides', 'TXN-O1', true);
    book('Ocean Storms', 'TXN-O2', true);
    LibraryAgentPrepareTransactionAction.Response several = prepare(
      req(token, 'BORROW_BOOK', 'Ocean')
    );
    System.assertEquals(false, several.prepared);
    System.assert(several.message.contains('Several books match'));
    System.assertEquals(
      false,
      prepare(req(token, 'BORROW_BOOK', 'No Such Title')).prepared
    );
    // An unsupported action is not enabled.
    System.assertEquals(
      false,
      prepare(req(token, 'WAIVE_FINE', 'Ocean Tides')).prepared
    );
  }

  @IsTest
  static void seatBookingResolvesRoomByNameAndRejectsTakenSeats() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    LibraryRoomBookingService.createRoom(
      'Study Room A',
      'First Floor',
      3,
      null
    );
    LibraryPolicyService.testGrantedPermissions.clear();
    String tokenA = session(member('txn-seat-a'));
    String tokenB = session(member('txn-seat-b'));

    LibraryAgentPrepareTransactionAction.Request request = req(
      tokenA,
      'BOOK_ROOM',
      'room a'
    );
    request.seatNumber = 2;
    request.startTime = futureTime(2, '15:00');
    request.durationHours = 1;
    request.purpose = 'Exam revision';
    LibraryAgentPrepareTransactionAction.Response prepared = prepare(request);
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assert(prepared.preview.contains('seat 2 in Study Room A'));
    System.assert(prepared.preview.contains('Exam revision'));
    System.assertEquals(
      0,
      LibraryRoomBookingService.getMyBookings(tokenA).size()
    );

    LibraryAgentCommitTransactionAction.Response done = confirmWith(
      tokenA,
      prepared.confirmationToken
    );
    System.assertEquals(true, done.committed, done.message);
    List<LibraryRoomBookingService.BookingDTO> mine = LibraryRoomBookingService.getMyBookings(
      tokenA
    );
    System.assertEquals(1, mine.size());
    System.assertEquals(2, mine[0].seatNumber);

    // Another member cannot take the same seat, but gets the next free one.
    LibraryAgentPrepareTransactionAction.Request clash = req(
      tokenB,
      'BOOK_ROOM',
      'Study Room A'
    );
    clash.seatNumber = 2;
    clash.startTime = futureTime(2, '15:00');
    LibraryAgentPrepareTransactionAction.Response taken = prepare(clash);
    System.assertEquals(false, taken.prepared);
    System.assert(taken.message.contains('already taken'), taken.message);
    clash.seatNumber = null;
    LibraryAgentPrepareTransactionAction.Response next = prepare(clash);
    System.assertEquals(true, next.prepared, next.message);
    System.assert(next.preview.contains('seat 1 in Study Room A'));
  }

  @IsTest
  static void privateRoomsAreBookedWholeAndPastTimesAreRefused() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    LibraryRoomBookingService.createRoom('Quiet Pod', null, 1, null, 'Private');
    LibraryPolicyService.testGrantedPermissions.clear();
    String token = session(member('txn-pod'));
    LibraryAgentPrepareTransactionAction.Request request = req(
      token,
      'BOOK_ROOM',
      'Quiet Pod'
    );
    request.startTime = futureTime(3, '10:00');
    LibraryAgentPrepareTransactionAction.Response prepared = prepare(request);
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assert(prepared.preview.contains('private room Quiet Pod'));
    System.assertEquals(
      true,
      confirmWith(token, prepared.confirmationToken).committed
    );

    request.startTime = futureTime(-1, '10:00');
    System.assertEquals(false, prepare(request).prepared);
    request.startTime = null;
    System.assertEquals(false, prepare(request).prepared);
  }

  @IsTest
  static void confirmationIsBoundToTheMemberAndPausedBeforeCommit() {
    String token = session(member('txn-bind-a'));
    String otherToken = session(member('txn-bind-b'));
    book('Bound Book', 'TXN-BOUND', true);
    LibraryAgentPrepareTransactionAction.Response prepared = prepare(
      req(token, 'BORROW_BOOK', 'Bound Book')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);

    // Another member's session cannot use this member's confirmation.
    System.assertEquals(
      false,
      confirmWith(otherToken, prepared.confirmationToken).committed
    );

    // Too soon after the preview: refused, but the confirmation stays usable.
    LibraryAgentConfirmationService.minConfirmDelaySeconds = 60;
    LibraryAgentCommitTransactionAction.Response early = confirmWith(
      token,
      prepared.confirmationToken
    );
    System.assertEquals(false, early.committed);
    System.assert(early.message.contains('Please wait'), early.message);
    LibraryAgentConfirmationService.minConfirmDelaySeconds = 0;
    System.assertEquals(
      true,
      confirmWith(token, prepared.confirmationToken).committed
    );
  }

  @IsTest
  static void confirmingWithoutACodeUsesTheLatestPreviewOnly() {
    String token = session(member('txn-nocode'));
    book('First Pick', 'TXN-N1', true);
    book('Second Pick', 'TXN-N2', true);

    // Nothing has been prepared yet.
    System.assertEquals(false, confirmWith(token, null).committed);

    prepare(req(token, 'BORROW_BOOK', 'First Pick'));
    LibraryAgentPrepareTransactionAction.Response second = prepare(
      req(token, 'BORROW_BOOK', 'Second Pick')
    );
    System.assertEquals(true, second.prepared, second.message);
    LibraryAgentCommitTransactionAction.Response done = confirmWith(
      token,
      null
    );
    System.assertEquals(true, done.committed, done.message);
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending']
    );
    System.assertEquals(
      'Second Pick',
      [
        SELECT Book_Copy__r.Book__r.Name
        FROM Borrow_Record__c
        WHERE Status__c = 'Pending'
        LIMIT 1
      ]
      .Book_Copy__r.Book__r.Name
    );
    // The same preview cannot be confirmed twice.
    System.assertEquals(false, confirmWith(token, null).committed);
  }

  @IsTest
  static void failedCommitKeepsTheConfirmationUsable() {
    String token = session(member('txn-fail'));
    Book__c wanted = book('Vanishing Volume', 'TXN-VAN', true);
    LibraryAgentPrepareTransactionAction.Response prepared = prepare(
      req(token, 'BORROW_BOOK', 'Vanishing Volume')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);
    // The only copy is taken before the member confirms.
    update new Book_Copy__c(
      Id = [SELECT Id FROM Book_Copy__c WHERE Book__c = :wanted.Id LIMIT 1]
      .Id,
      Status__c = 'Borrowed'
    );
    LibraryAgentCommitTransactionAction.Response failed = confirmWith(
      token,
      prepared.confirmationToken
    );
    System.assertEquals(false, failed.committed);
    System.assert(!String.isBlank(failed.message));
    System.assertEquals(
      'Pending',
      [
        SELECT Status__c
        FROM Library_Scan_Transaction__c
        WHERE Operation__c = 'BORROW_BOOK'
        LIMIT 1
      ]
      .Status__c
    );
  }

  @IsTest
  static void timeParserReadsLocalAndZonedTimes() {
    Datetime local = LibraryAgentTimeParser.parse('2026-11-04 15:00');
    System.assertEquals(
      Datetime.newInstance(2026, 11, 4, 15, 0, 0).getTime(),
      local.getTime()
    );
    System.assertEquals(
      local.getTime(),
      LibraryAgentTimeParser.parse('2026-11-04T15:00:00').getTime()
    );
    Datetime zoned = LibraryAgentTimeParser.parse('2026-11-04T15:00:00Z');
    System.assertEquals(
      Datetime.newInstanceGmt(2026, 11, 4, 15, 0, 0).getTime(),
      zoned.getTime()
    );
    System.assertEquals(
      zoned.getTime(),
      LibraryAgentTimeParser.parse('2026-11-04T20:30:00+05:30').getTime()
    );
    System.assertEquals(null, LibraryAgentTimeParser.parse('tomorrow-ish'));
    System.assertEquals(null, LibraryAgentTimeParser.parse(null));
  }
}
