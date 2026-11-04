// Runs the assistant transactions as the real Agentforce member agent user, so
// missing object or field access shows up here instead of in a chat reply. The
// tests quietly pass in an org that has no such user.
@IsTest
private class LibraryAgentTransactionsAgentUserTest {
  private static User agentUser() {
    List<User> users = [
      SELECT Id
      FROM User
      WHERE
        Profile.Name = 'Einstein Agent User'
        AND Username LIKE 'librarymemberagent%'
        AND IsActive = TRUE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0];
  }

  private static String session(String key) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Agent User Plan ' + key,
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
      First_Name__c = 'Agent',
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
    return LibraryMemberSessionService.create(member, null, 'agent-user-test');
  }

  private static void book(String name, String isbn, Boolean available) {
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
  }

  // Prepare then commit through the invocable actions, as the agent does.
  private static void runFlow(
    String token,
    LibraryAgentPrepareTransactionAction.Request request,
    String expectedMessage
  ) {
    LibraryAgentPrepareTransactionAction.Response prepared = LibraryAgentPrepareTransactionAction.execute(
      new List<LibraryAgentPrepareTransactionAction.Request>{ request }
    )[0];
    System.assertEquals(
      true,
      prepared.prepared,
      'prepare: ' + prepared.message
    );
    LibraryAgentCommitTransactionAction.Request commitRequest = new LibraryAgentCommitTransactionAction.Request();
    commitRequest.sessionToken = token;
    // The assistant passes no code: the member's latest preview is confirmed.
    LibraryAgentCommitTransactionAction.Response done = LibraryAgentCommitTransactionAction.execute(
      new List<LibraryAgentCommitTransactionAction.Request>{ commitRequest }
    )[0];
    System.assertEquals(true, done.committed, 'commit: ' + done.message);
    System.assert(done.message.contains(expectedMessage), done.message);
  }

  private static LibraryAgentPrepareTransactionAction.Request request(
    String token,
    String action,
    String name
  ) {
    LibraryAgentPrepareTransactionAction.Request value = new LibraryAgentPrepareTransactionAction.Request();
    value.sessionToken = token;
    value.action = action;
    value.targetName = name;
    return value;
  }

  @IsTest
  static void agentUserCanBorrowAfterConfirmation() {
    User agent = agentUser();
    if (agent == null)
      return;
    String token = session('au-borrow');
    book('Agent Borrow Book', 'AU-BORROW', true);
    System.runAs(agent) {
      runFlow(
        token,
        request(token, 'BORROW_BOOK', 'Agent Borrow Book'),
        'awaiting librarian approval'
      );
    }
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Status__c = 'Pending']
    );
  }

  @IsTest
  static void agentUserCanReserveAfterConfirmation() {
    User agent = agentUser();
    if (agent == null)
      return;
    String token = session('au-reserve');
    book('Agent Reserve Book', 'AU-RESERVE', false);
    System.runAs(agent) {
      runFlow(
        token,
        request(token, 'RESERVE_BOOK', 'Agent Reserve Book'),
        'reservation was placed'
      );
    }
    System.assertEquals(1, [SELECT COUNT() FROM Reservation__c]);
  }

  @IsTest
  static void agentUserCanBookASeatAfterConfirmation() {
    User agent = agentUser();
    if (agent == null)
      return;
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    LibraryRoomBookingService.createRoom('Agent Study Room', null, 2, null);
    LibraryPolicyService.testGrantedPermissions.clear();
    String token = session('au-seat');
    LibraryAgentPrepareTransactionAction.Request value = request(
      token,
      'BOOK_ROOM',
      'Agent Study Room'
    );
    value.startTime = String.valueOf(Date.today().addDays(2)) + ' 15:00';
    System.runAs(agent) {
      runFlow(token, value, 'seat was booked');
    }
    System.assertEquals(
      1,
      LibraryRoomBookingService.getMyBookings(token).size()
    );
  }
}
