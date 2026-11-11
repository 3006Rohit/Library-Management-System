@IsTest
private class LibraryAgentLibrarianWriteTest {
  private static Member__c member(String key) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Lib Write Plan ' + key,
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
      First_Name__c = 'Lena',
      Last_Name__c = key,
      Email__c = key + '@example.com',
      Normalized_Email__c = key + '@example.com',
      Phone__c = '555-0100',
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

  private static Book__c book(String name, String isbn, Boolean available) {
    Book__c value = new Book__c(
      Name = name,
      ISBN__c = isbn,
      Publisher__c = 'Old Press',
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

  private static void grant() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
  }

  private static LibraryAgentLibrarianPrepareAction.Response prepare(
    LibraryAgentLibrarianPrepareAction.Request request
  ) {
    return LibraryAgentLibrarianPrepareAction.execute(
      new List<LibraryAgentLibrarianPrepareAction.Request>{ request }
    )[0];
  }

  private static LibraryAgentLibrarianPrepareAction.Request req(
    String action,
    String memberLookup,
    String bookLookup
  ) {
    LibraryAgentLibrarianPrepareAction.Request request = new LibraryAgentLibrarianPrepareAction.Request();
    request.action = action;
    request.memberLookup = memberLookup;
    request.bookLookup = bookLookup;
    return request;
  }

  private static LibraryAgentLibrarianCommitAction.Response commitStep() {
    return LibraryAgentLibrarianCommitAction.execute(
      new List<LibraryAgentLibrarianCommitAction.Request>{
        new LibraryAgentLibrarianCommitAction.Request()
      }
    )[0];
  }

  @IsTest
  static void writesAreRefusedWithoutLibrarianPermission() {
    member('lw-denied');
    LibraryAgentLibrarianPrepareAction.Response denied = prepare(
      req('UPDATE_MEMBER', 'lw-denied@example.com', null)
    );
    System.assertEquals(false, denied.prepared);
    System.assert(
      denied.message.contains('could not be prepared'),
      denied.message
    );
  }

  @IsTest
  static void memberEditIsPreviewedThenSavedOnceAndKeepsOtherFields() {
    grant();
    Member__c existing = member('lw-edit');
    LibraryAgentLibrarianPrepareAction.Request request = req(
      'UPDATE_MEMBER',
      'Lena lw-edit',
      null
    );
    request.phone = '555-0199';
    LibraryAgentLibrarianPrepareAction.Response prepared = prepare(request);
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assert(prepared.preview.contains('555-0199'));
    System.assertEquals(
      '555-0100',
      [SELECT Phone__c FROM Member__c WHERE Id = :existing.Id].Phone__c,
      'Preparing must not write anything.'
    );

    LibraryAgentLibrarianCommitAction.Response done = commitStep();
    System.assertEquals(true, done.committed, done.message);
    Member__c saved = [
      SELECT Phone__c, First_Name__c, Email__c
      FROM Member__c
      WHERE Id = :existing.Id
    ];
    System.assertEquals('555-0199', saved.Phone__c);
    System.assertEquals('Lena', saved.First_Name__c);
    System.assertEquals('lw-edit@example.com', saved.Email__c);

    System.assertEquals(
      false,
      commitStep().committed,
      'The same confirmation cannot be replayed.'
    );
  }

  @IsTest
  static void memberEditWithNoRealChangeIsRefused() {
    grant();
    member('lw-same');
    LibraryAgentLibrarianPrepareAction.Request request = req(
      'UPDATE_MEMBER',
      'lw-same@example.com',
      null
    );
    request.phone = '555-0100';
    LibraryAgentLibrarianPrepareAction.Response result = prepare(request);
    System.assertEquals(false, result.prepared);
    System.assert(result.message.contains('Nothing would change'));
  }

  @IsTest
  static void bookEditKeepsIsbnAndTitleWhenOnlyPublisherChanges() {
    grant();
    Book__c existing = book('Edit Me', 'LW-EDIT', true);
    LibraryAgentLibrarianPrepareAction.Request request = req(
      'UPDATE_BOOK',
      null,
      'edit me'
    );
    request.publisher = 'New Press';
    LibraryAgentLibrarianPrepareAction.Response prepared = prepare(request);
    System.assertEquals(true, prepared.prepared, prepared.message);

    System.assertEquals(true, commitStep().committed);
    Book__c saved = [
      SELECT Name, ISBN__c, Publisher__c
      FROM Book__c
      WHERE Id = :existing.Id
    ];
    System.assertEquals('New Press', saved.Publisher__c);
    System.assertEquals('Edit Me', saved.Name);
    System.assertEquals('LW-EDIT', saved.ISBN__c);
  }

  @IsTest
  static void checkoutForMemberIsConfirmedBeforeItHappens() {
    grant();
    Member__c borrower = member('lw-borrow');
    book('Checkout Book', 'LW-OUT', true);

    LibraryAgentLibrarianPrepareAction.Response prepared = prepare(
      req('BORROW_FOR_MEMBER', 'lw-borrow@example.com', 'Checkout Book')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Member__c = :borrower.Id]
    );

    LibraryAgentLibrarianCommitAction.Response done = commitStep();
    System.assertEquals(true, done.committed, done.message);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE Member__c = :borrower.Id AND Status__c = 'Active'
      ]
    );
  }

  @IsTest
  static void checkoutIsRefusedWhenNoCopyIsFree() {
    grant();
    member('lw-none');
    book('Out Book', 'LW-NONE', false);
    LibraryAgentLibrarianPrepareAction.Response result = prepare(
      req('BORROW_FOR_MEMBER', 'lw-none@example.com', 'Out Book')
    );
    System.assertEquals(false, result.prepared);
    System.assert(result.message.contains('reserved'), result.message);
  }

  @IsTest
  static void reservationForMemberJoinsTheQueueAfterConfirmation() {
    grant();
    Member__c reader = member('lw-reserve');
    book('Queue Book', 'LW-QUEUE', false);

    LibraryAgentLibrarianPrepareAction.Response prepared = prepare(
      req('RESERVE_FOR_MEMBER', 'lw-reserve@example.com', 'Queue Book')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Reservation__c WHERE Member__c = :reader.Id]
    );

    LibraryAgentLibrarianCommitAction.Response done = commitStep();
    System.assertEquals(true, done.committed, done.message);
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Reservation__c WHERE Member__c = :reader.Id]
    );
  }

  @IsTest
  static void pendingBorrowRequestIsApprovedAfterConfirmation() {
    grant();
    Member__c reader = member('lw-approve');
    Book__c wanted = book('Approve Book', 'LW-APPROVE', true);
    String session = LibraryMemberSessionService.create(
      reader,
      null,
      'lw-test'
    );
    LibraryMemberSessionController.borrowBook(session, wanted.Id);
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending']
    );

    LibraryAgentLibrarianPrepareAction.Response prepared = prepare(
      req('APPROVE_BORROW', 'lw-approve@example.com', 'Approve Book')
    );
    System.assertEquals(true, prepared.prepared, prepared.message);
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending'],
      'Preparing must not approve anything.'
    );

    LibraryAgentLibrarianCommitAction.Response done = commitStep();
    System.assertEquals(true, done.committed, done.message);
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending']
    );
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE Member__c = :reader.Id AND Status__c = 'Active'
      ]
    );
  }

  @IsTest
  static void commitWithNothingPreparedAndUnknownActionsFailSafely() {
    grant();
    System.assertEquals(false, commitStep().committed);
    LibraryAgentLibrarianPrepareAction.Response unknown = prepare(
      req('DELETE_MEMBER', 'x', null)
    );
    System.assertEquals(false, unknown.prepared);
    System.assert(unknown.message.contains('not enabled'));
  }

  @IsTest
  static void aTamperedPayloadIsRejected() {
    grant();
    Member__c reader = member('lw-tamper');
    LibraryAgentLibrarianPrepareAction.Request request = req(
      'UPDATE_MEMBER',
      'lw-tamper@example.com',
      null
    );
    request.phone = '555-0123';
    System.assertEquals(true, prepare(request).prepared);
    Agent_Confirmation__c row = [
      SELECT Id, Payload__c
      FROM Agent_Confirmation__c
      LIMIT 1
    ];
    row.Payload__c = row.Payload__c.replace('555-0123', '555-9999');
    update row;

    LibraryAgentLibrarianCommitAction.Response result = commitStep();
    System.assertEquals(false, result.committed);
    System.assertEquals(
      '555-0100',
      [SELECT Phone__c FROM Member__c WHERE Id = :reader.Id].Phone__c
    );
  }
}
