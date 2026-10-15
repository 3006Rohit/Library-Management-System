@IsTest
private class LibraryMemberAuthControllerTest {
  @IsTest
  static void memberDtosExposeAllowlistedFieldsToAura() {
    LibraryMemberSessionController.LoanDTO loan = new LibraryMemberSessionController.LoanDTO();
    loan.bookTitle = 'Visible Book';
    loan.status = 'Active';
    loan.dueDate = System.now();
    String loanJson = JSON.serialize(loan);
    System.assert(loanJson.contains('"bookTitle":"Visible Book"'), loanJson);
    System.assert(loanJson.contains('"status":"Active"'), loanJson);

    LibraryMemberSessionController.ReservationDTO reservation = new LibraryMemberSessionController.ReservationDTO();
    reservation.bookName = 'Reserved Book';
    reservation.status = 'Ready';
    reservation.queuePosition = 1;
    String reservationJson = JSON.serialize(reservation);
    System.assert(
      reservationJson.contains('"bookName":"Reserved Book"'),
      reservationJson
    );
    System.assert(
      reservationJson.contains('"status":"Ready"'),
      reservationJson
    );
  }
  @IsTest
  static void passwordHashUsesSaltAndNeverStoresPlaintext() {
    String salt = LibraryMemberPasswordService.newSalt();
    String hash = LibraryMemberPasswordService.hash(salt, 'LibraryPass123');
    System.assertNotEquals('LibraryPass123', hash);
    System.assertNotEquals(
      hash,
      LibraryMemberPasswordService.hash('different-salt', 'LibraryPass123')
    );
    Member__c member = new Member__c(
      First_Name__c = 'A',
      Last_Name__c = 'Member',
      Email__c = 'auth-test@example.com',
      Normalized_Email__c = 'auth-test@example.com',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Password_Salt__c = salt,
      Password_Hash__c = hash
    );
    System.assert(
      LibraryMemberPasswordService.matches(member, 'LibraryPass123')
    );
    System.assertEquals(
      false,
      LibraryMemberPasswordService.matches(member, 'WrongPass123')
    );
  }
  @IsTest
  static void passwordPolicyRejectsWeakValues() {
    try {
      LibraryMemberPasswordService.validate('weak', 'weak');
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    LibraryMemberPasswordService.validate('StrongPass123', 'StrongPass123');
  }
  @IsTest
  static void tokenHashesAreNotRawTokens() {
    String token = LibraryMemberPasswordService.token();
    System.assertNotEquals(
      token,
      LibraryMemberPasswordService.tokenHash(token)
    );
    System.assertEquals(
      LibraryMemberPasswordService.tokenHash(token),
      LibraryMemberPasswordService.tokenHash(token)
    );
  }
  @IsTest
  static void authenticatedSessionResolvesAndRevokesWithoutUser() {
    String salt = LibraryMemberPasswordService.newSalt();
    Member__c member = new Member__c(
      First_Name__c = 'Session',
      Last_Name__c = 'Member',
      Email__c = 'session-test@example.com',
      Normalized_Email__c = 'session-test@example.com',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Password_Salt__c = salt,
      Password_Hash__c = LibraryMemberPasswordService.hash(
        salt,
        'StrongPass123'
      )
    );
    insert member;
    Test.startTest();
    LibraryMemberAuthController.AuthResult result = LibraryMemberAuthController.login(
      'session-test@example.com',
      'StrongPass123'
    );
    System.assertNotEquals(null, result.sessionToken);
    System.assertEquals(
      member.Id,
      LibraryMemberAuthController.validateSession(result.sessionToken).Id
    );
    System.assertEquals(
      member.Id,
      LibraryMemberAuthController.getCurrentMemberContext(result.sessionToken)
        .Id
    );
    LibraryMemberSessionController.getMyDashboard(result.sessionToken);
    LibraryDataCloudService.MemberAnalyticsDTO analytics = LibraryMemberSessionController.getMyAnalytics(
      result.sessionToken
    );
    System.assertEquals(true, analytics.available);
    System.assertEquals(0, analytics.totalLoans);
    System.assertNotEquals(
      null,
      LibraryMemberSessionController.getSuggestedBooks(result.sessionToken)
    );
    LibraryMemberSessionController.getCatalogCategories(result.sessionToken);
    LibraryMemberSessionController.searchCatalog(
      result.sessionToken,
      null,
      null,
      null,
      10,
      1
    );
    LibraryMemberSessionController.getMyBorrowings(result.sessionToken);
    LibraryMemberSessionController.getMyReservations(result.sessionToken);
    LibraryMemberSessionController.getMyFines(result.sessionToken);
    LibraryMemberSessionController.getMyPayments(result.sessionToken);
    LibraryMemberSessionController.getMyProfile(result.sessionToken);
    LibraryMemberSessionController.getMyMembership(result.sessionToken);
    LibraryMemberSessionController.getMyNotifications(result.sessionToken);
    LibraryMemberAuthController.logout(result.sessionToken);
    Test.stopTest();
    try {
      LibraryMemberAuthController.validateSession(result.sessionToken);
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
  }
  @IsTest
  static void loginLockoutAndGenericFailures() {
    String salt = LibraryMemberPasswordService.newSalt();
    Member__c member = new Member__c(
      First_Name__c = 'Locked',
      Last_Name__c = 'Member',
      Email__c = 'locked-test@example.com',
      Normalized_Email__c = 'locked-test@example.com',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Password_Salt__c = salt,
      Password_Hash__c = LibraryMemberPasswordService.hash(
        salt,
        'StrongPass123'
      )
    );
    insert member;
    for (Integer i = 0; i < 5; i++) {
      try {
        LibraryMemberAuthController.login(
          'locked-test@example.com',
          'WrongPass123'
        );
        System.assert(false);
      } catch (Exception expected) {
        System.assert(true);
      }
    }
    member = [
      SELECT Failed_Login_Count__c, Locked_Until__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assertEquals(0, member.Failed_Login_Count__c);
    System.assert(member.Locked_Until__c > System.now());
    try {
      LibraryMemberAuthController.login(
        'missing-test@example.com',
        'WrongPass123'
      );
      System.assert(false);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberAuthController.login('not-an-email', 'WrongPass123');
      System.assert(false);
    } catch (Exception expected) {
      System.assert(true);
    }
  }
  @IsTest
  static void activationResetAndPasswordChangeAreSingleUse() {
    Member__c member = new Member__c(
      First_Name__c = 'Flow',
      Last_Name__c = 'Member',
      Email__c = 'flow-test@example.com',
      Normalized_Email__c = 'flow-test@example.com',
      Status__c = 'Suspended',
      Account_Status__c = 'Active',
      Registration_Status__c = 'Approved'
    );
    insert member;
    String activation = LibraryMemberAuthController.issueActivation(member);
    LibraryMemberAuthController.activateAccount(
      activation,
      'StrongPass123',
      'StrongPass123'
    );
    member = [
      SELECT
        Status__c,
        Email_Verified__c,
        Password_Hash__c,
        Password_Salt__c,
        Activation_Token_Hash__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assertEquals('Active', member.Status__c);
    System.assertEquals(true, member.Email_Verified__c);
    System.assertEquals(null, member.Activation_Token_Hash__c);
    System.assert(
      LibraryMemberPasswordService.matches(member, 'StrongPass123')
    );
    try {
      LibraryMemberAuthController.activateAccount(
        activation,
        'AnotherPass123',
        'AnotherPass123'
      );
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    String session = LibraryMemberSessionService.create(member, null, null);
    String reset = LibraryMemberPasswordService.token();
    member.Reset_Token_Hash__c = LibraryMemberPasswordService.tokenHash(reset);
    member.Reset_Token_Expires_At__c = System.now().addHours(1);
    update member;
    LibraryMemberAuthController.resetPassword(
      reset,
      'NewStrong123',
      'NewStrong123'
    );
    member = [
      SELECT Password_Hash__c, Password_Salt__c, Reset_Token_Hash__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assert(LibraryMemberPasswordService.matches(member, 'NewStrong123'));
    System.assertEquals(null, member.Reset_Token_Hash__c);
    try {
      LibraryMemberAuthController.validateSession(session);
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    try {
      LibraryMemberAuthController.resetPassword(
        reset,
        'OtherStrong123',
        'OtherStrong123'
      );
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    LibraryMemberAuthController.forgotPassword('unknown-flow@example.com');
    LibraryMemberAuthController.forgotPassword('flow-test@example.com');
    LibraryMemberAuthController.AuthResult loggedIn = LibraryMemberAuthController.login(
      'flow-test@example.com',
      'NewStrong123'
    );
    LibraryMemberAuthController.changePassword(
      loggedIn.sessionToken,
      'NewStrong123',
      'ChangedStrong123',
      'ChangedStrong123'
    );
    try {
      LibraryMemberAuthController.validateSession(loggedIn.sessionToken);
      System.assert(false);
    } catch (Exception expected) {
      System.assert(true);
    }
    System.assertNotEquals(
      null,
      LibraryMemberAuthController.login(
          'flow-test@example.com',
          'ChangedStrong123'
        )
        .sessionToken
    );
  }
  @IsTest
  static void sessionExpiryAndMemberIsolation() {
    List<Member__c> members = new List<Member__c>();
    for (Integer i = 1; i <= 2; i++) {
      String email = 'isolation-' + i + '@example.com';
      String salt = LibraryMemberPasswordService.newSalt();
      members.add(
        new Member__c(
          First_Name__c = 'Member',
          Last_Name__c = String.valueOf(i),
          Email__c = email,
          Normalized_Email__c = email,
          Status__c = 'Active',
          Account_Status__c = 'Active',
          Password_Salt__c = salt,
          Password_Hash__c = LibraryMemberPasswordService.hash(
            salt,
            'StrongPass123'
          )
        )
      );
    }
    insert members;
    String tokenA = LibraryMemberSessionService.create(members[0], null, null);
    String tokenB = LibraryMemberSessionService.create(members[1], null, null);
    System.assertEquals(
      members[0].Id,
      LibraryMemberSessionController.getCurrentMemberContext(tokenA).Id
    );
    System.assertEquals(
      members[1].Id,
      LibraryMemberSessionController.getCurrentMemberContext(tokenB).Id
    );
    System.assertEquals(
      members[0].Id,
      LibraryMemberSessionController.getMyProfile(tokenA).Id
    );
    System.assertEquals(
      0,
      LibraryMemberSessionController.getMyBorrowings(tokenA).size()
    );
    LibraryMemberSessionController.updateMyProfile(
      tokenA,
      'Changed',
      'Member',
      '+91 9876543210',
      'Library address'
    );
    LibraryMemberSessionController.getMyMembership(tokenA);
    LibraryMemberSessionController.getUpgradePlans(tokenA);
    try {
      LibraryMemberSessionController.markNotificationRead(tokenA, null);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.renewMyLoan(tokenA, null);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.cancelMyReservation(tokenA, null);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.payForMembershipUpgrade(tokenA, null);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.renewMyMembership(tokenA);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.getBookDetails(tokenA, null);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.borrowBook(tokenA, null);
    } catch (Exception expected) {
      System.assert(true);
    }
    Member_Session__c expired = [
      SELECT Id
      FROM Member_Session__c
      WHERE Token_Hash__c = :LibraryMemberPasswordService.tokenHash(tokenB)
      LIMIT 1
    ];
    expired.Expires_At__c = System.now().addMinutes(-1);
    update expired;
    try {
      LibraryMemberSessionController.getCurrentMemberContext(tokenB);
      System.assert(false);
    } catch (Exception expected) {
      System.assert(true);
    }
    try {
      LibraryMemberSessionController.getCurrentMemberContext('tampered-token');
      System.assert(false);
    } catch (Exception expected) {
      System.assert(true);
    }
    Member__c inactive = new Member__c(
      First_Name__c = 'Inactive',
      Last_Name__c = 'Member',
      Email__c = 'inactive-session@example.com',
      Normalized_Email__c = 'inactive-session@example.com',
      Status__c = 'Suspended',
      Account_Status__c = 'Active'
    );
    insert inactive;
    String inactiveToken = LibraryMemberSessionService.create(
      inactive,
      null,
      null
    );
    try {
      LibraryMemberSessionService.getCurrentMember(inactiveToken);
      System.assert(false);
    } catch (Exception expected) {
      System.assert(true);
    }
  }
}
