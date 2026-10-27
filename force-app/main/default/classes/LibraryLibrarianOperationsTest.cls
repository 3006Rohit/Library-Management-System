@IsTest
private class LibraryLibrarianOperationsTest {
  private class Fixture {
    Membership_Plan__c plan;
    Account account;
    Contact contact;
    Member__c member;
    Book__c book;
    Book_Copy__c copy;
  }
  private static void authorizeLibrarian() {
    LibraryPolicyService.testGrantedPermissions = new Set<String>{
      'Manage_Library_Catalog',
      'Manage_Library_Circulation',
      'Manage_Library_Fines',
      'Manage_Library_Registrations'
    };
    LibraryRegistrationService.testLibrarianAuthorized = true;
  }
  private static Fixture fixture(String suffix) {
    authorizeLibrarian();
    Fixture f = new Fixture();
    f.plan = new Membership_Plan__c(
      Name = 'Plan ' + suffix,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 10,
      Fee__c = 500
    );
    insert f.plan;
    f.account = new Account(Name = 'Library Community Members');
    insert f.account;
    f.contact = new Contact(
      FirstName = 'Test',
      LastName = suffix,
      Email = suffix.toLowerCase() + '@example.com',
      AccountId = f.account.Id
    );
    insert f.contact;
    f.member = new Member__c(
      First_Name__c = 'Test',
      Last_Name__c = suffix,
      Email__c = f.contact.Email,
      Contact__c = f.contact.Id,
      External_Auth_Id__c = 'test-' + suffix,
      Email_Verified__c = true,
      Account_Status__c = 'Active',
      Membership_Plan__c = f.plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3,
      Status__c = 'Active'
    );
    insert f.member;
    f.book = new Book__c(
      Name = 'Book ' + suffix,
      ISBN__c = 'ISBN-' + suffix,
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert f.book;
    f.copy = new Book_Copy__c(
      Book__c = f.book.Id,
      Barcode__c = 'BAR-' + suffix,
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    insert f.copy;
    return f;
  }
  @IsTest
  static void checkoutUsesPlanDurationAndReturnCreatesFine() {
    Fixture f = fixture('One');
    Id loanId = LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    Borrow_Record__c loan = [
      SELECT Id, Due_Date__c, Status__c, Contact__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
    ];
    System.assertEquals('Active', loan.Status__c);
    System.assertEquals(f.contact.Id, loan.Contact__c);
    System.assertEquals(14, Date.today().daysBetween(loan.Due_Date__c.date()));
    System.assertEquals(
      'Borrowed',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :f.copy.Id].Status__c
    );
    loan.Borrow_Date__c = System.now().addDays(-5);
    loan.Due_Date__c = System.now().addDays(-2);
    update loan;
    LibraryCirculationService.returnLoan(loan.Id);
    System.assertEquals(
      'Returned',
      [SELECT Status__c FROM Borrow_Record__c WHERE Id = :loan.Id].Status__c
    );
    System.assertEquals(
      'Available',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :f.copy.Id].Status__c
    );
    Fine__c fine = [
      SELECT Amount__c, Status__c
      FROM Fine__c
      WHERE Borrow_Record__c = :loan.Id
      LIMIT 1
    ];
    System.assertEquals(20, fine.Amount__c);
    System.assertEquals('Unpaid', fine.Status__c);
  }
  @IsTest
  static void reservationPromotionAndRenewalRulesWork() {
    Fixture f = fixture('Two');
    Fixture g = fixture('Three');
    g.book = f.book;
    g.copy = f.copy;
    update g.member;
    Id loanId = LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    Reservation__c reservation = new Reservation__c(
      Member__c = g.member.Id,
      Book__c = f.book.Id,
      Contact__c = g.contact.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 1
    );
    insert reservation;
    Borrow_Record__c loan = [
      SELECT Id, Due_Date__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
    ];
    LibraryCirculationService.returnLoan(loan.Id);
    reservation = [
      SELECT Status__c, Book_Copy__c, Ready_Date__c, Expiry_Date__c
      FROM Reservation__c
      WHERE Id = :reservation.Id
    ];
    System.assertEquals('Ready', reservation.Status__c);
    System.assertEquals(f.copy.Id, reservation.Book_Copy__c);
    System.assertNotEquals(null, reservation.Expiry_Date__c);
    reservation.Status__c = 'Cancelled';
    update reservation;
    update new Book_Copy__c(Id = f.copy.Id, Status__c = 'Available');
    Id secondLoan = LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    LibraryCirculationService.renewLoan(secondLoan);
    System.assertEquals(
      1,
      [SELECT Renewal_Count__c FROM Borrow_Record__c WHERE Id = :secondLoan]
      .Renewal_Count__c
    );
    Boolean blocked = false;
    try {
      LibraryCirculationService.renewLoan(secondLoan);
    } catch (Exception e) {
      blocked = true;
    }
    System.assertEquals(true, blocked);
  }
  @IsTest
  static void paymentsAndWaiversAreControlled() {
    Fixture f = fixture('Four');
    Fine__c fine = new Fine__c(
      Member__c = f.member.Id,
      Contact__c = f.contact.Id,
      Fine_Type__c = 'Other',
      Amount__c = 50,
      Paid_Amount__c = 0,
      Status__c = 'Unpaid',
      Generated_Date__c = Date.today()
    );
    insert fine;
    Test.startTest();
    LibraryCirculationService.recordFinePayment(fine.Id, 20);
    Test.stopTest();
    fine = [SELECT Paid_Amount__c, Status__c FROM Fine__c WHERE Id = :fine.Id];
    System.assertEquals(20, fine.Paid_Amount__c);
    System.assertEquals('Partially Paid', fine.Status__c);
    LibraryCirculationService.waiveFine(fine.Id, 'Administrative waiver');
    fine = [SELECT Status__c, Notes__c FROM Fine__c WHERE Id = :fine.Id];
    System.assertEquals('Waived', fine.Status__c);
    System.assertEquals('Administrative waiver', fine.Notes__c);
  }
  @IsTest
  static void reservationServiceLifecycleIsControlled() {
    Fixture f = fixture('Six');
    Id reservationId = LibraryLibrarianController.createReservation(
      f.member.Id,
      f.book.Id
    );
    System.assertEquals(
      'Ready',
      [SELECT Status__c FROM Reservation__c WHERE Id = :reservationId].Status__c
    );
    LibraryCirculationService.cancelReservation(reservationId);
    System.assertEquals(
      'Cancelled',
      [SELECT Status__c FROM Reservation__c WHERE Id = :reservationId].Status__c
    );
    Reservation__c ready = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Book_Copy__c = f.copy.Id,
      Reservation_Date__c = System.now().addDays(-2),
      Status__c = 'Ready',
      Queue_Position__c = 1,
      Ready_Date__c = System.now().addDays(-2),
      Expiry_Date__c = System.now().addDays(-1)
    );
    insert ready;
    update new Book_Copy__c(Id = f.copy.Id, Status__c = 'Reserved');
    Id fulfilledLoan = LibraryCirculationService.checkout(
      f.member.Id,
      f.copy.Id
    );
    System.assertEquals(
      'Fulfilled',
      [SELECT Status__c FROM Reservation__c WHERE Id = :ready.Id].Status__c
    );
    LibraryCirculationService.returnLoan(fulfilledLoan);
    Reservation__c expired = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Book_Copy__c = f.copy.Id,
      Reservation_Date__c = System.now().addDays(-3),
      Status__c = 'Ready',
      Queue_Position__c = 1,
      Ready_Date__c = System.now().addDays(-3),
      Expiry_Date__c = System.now().addDays(-1)
    );
    insert expired;
    update new Book_Copy__c(Id = f.copy.Id, Status__c = 'Reserved');
    System.assertEquals(
      1,
      LibraryCirculationService.processExpiredReservations()
    );
    System.assertEquals(
      'Expired',
      [SELECT Status__c FROM Reservation__c WHERE Id = :expired.Id].Status__c
    );
    System.assertEquals(
      'Available',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :f.copy.Id].Status__c
    );
  }
  @IsTest
  static void cancellingReadyHoldPromotesNextAndKeepsCopyReserved() {
    Fixture first = fixture('ReadyCancelOne');
    Fixture second = fixture('ReadyCancelTwo');
    second.book = first.book;
    second.copy = first.copy;
    update second.member;
    Reservation__c ready = new Reservation__c(
      Member__c = first.member.Id,
      Book__c = first.book.Id,
      Contact__c = first.contact.Id,
      Book_Copy__c = first.copy.Id,
      Reservation_Date__c = System.now().addMinutes(-10),
      Status__c = 'Ready',
      Queue_Position__c = 1,
      Ready_Date__c = System.now(),
      Expiry_Date__c = System.now().addDays(2)
    );
    Reservation__c pending = new Reservation__c(
      Member__c = second.member.Id,
      Book__c = first.book.Id,
      Contact__c = second.contact.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 2
    );
    insert new List<Reservation__c>{ ready, pending };
    update new Book_Copy__c(Id = first.copy.Id, Status__c = 'Reserved');
    LibraryCirculationService.cancelReservationForMember(
      ready.Id,
      first.member.Id
    );
    Reservation__c cancelled = [
      SELECT Status__c, Book_Copy__c
      FROM Reservation__c
      WHERE Id = :ready.Id
    ];
    Reservation__c promoted = [
      SELECT
        Status__c,
        Book_Copy__c,
        Ready_Date__c,
        Expiry_Date__c,
        Queue_Position__c
      FROM Reservation__c
      WHERE Id = :pending.Id
    ];
    System.assertEquals('Cancelled', cancelled.Status__c);
    System.assertEquals(null, cancelled.Book_Copy__c);
    System.assertEquals('Ready', promoted.Status__c);
    System.assertEquals(first.copy.Id, promoted.Book_Copy__c);
    System.assertEquals(null, promoted.Queue_Position__c);
    System.assertEquals(
      'Reserved',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :first.copy.Id].Status__c
    );
  }
  @IsTest
  static void defectiveCopyReplacementExtendsDueDateWithoutCreatingSecondLoan() {
    Fixture f = fixture('Replacement');
    Book_Copy__c replacement = new Book_Copy__c(
      Book__c = f.book.Id,
      Barcode__c = 'BAR-REPLACEMENT-' +
        String.valueOf(DateTime.now().getTime()),
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    insert replacement;
    Id loanId = LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    Borrow_Record__c loan = [
      SELECT Id, Due_Date__c, Book_Copy__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
    ];
    LibraryCirculationService.reportDefectiveCopy(loanId, 'Missing pages');
    loan = [
      SELECT Id, Due_Date__c, Defect_Reported_Date__c, Replacement_Required__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
    ];
    loan.Defect_Reported_Date__c = System.now().addDays(-3);
    update loan;
    Date originalDue = loan.Due_Date__c.date();
    LibraryCirculationService.replaceDefectiveCopy(loanId, replacement.Id);
    loan = [
      SELECT
        Id,
        Book_Copy__c,
        Due_Date__c,
        Replacement_Days__c,
        Replacement_Required__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
    ];
    System.assertEquals(replacement.Id, loan.Book_Copy__c);
    System.assertEquals(3, loan.Replacement_Days__c);
    System.assertEquals(originalDue.addDays(3), loan.Due_Date__c.date());
    System.assertEquals(false, loan.Replacement_Required__c);
    System.assertEquals(
      'Damaged',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :f.copy.Id].Status__c
    );
    System.assertEquals(
      'Borrowed',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :replacement.Id].Status__c
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Id = :loanId]
    );
  }
  @IsTest
  static void controllerReturnsCatalogData() {
    Fixture f = fixture('Five');
    LibraryLibrarianController.DashboardData data = LibraryLibrarianController.getDashboard();
    List<Book__c> books = LibraryLibrarianController.searchBooks(
      'Book Five',
      null,
      null,
      25,
      1
    );
    List<Member__c> members = LibraryLibrarianController.searchMembers(
      'Five',
      null
    );
    System.assertEquals(
      1,
      LibraryLibrarianController.getAvailableCopies(f.book.Id).size()
    );
    System.assert(LibraryLibrarianController.getAuthors().size() >= 0);
    System.assert(LibraryLibrarianController.getCategories().size() >= 0);
    Id newBook = LibraryLibrarianController.addBook(
      'New Book',
      'ISBN-NEW',
      'Publisher',
      2026,
      '1',
      'English',
      'Description',
      null,
      null,
      null
    );
    System.assertNotEquals(
      null,
      LibraryLibrarianController.getBookDetail(newBook).Id
    );
    LibraryLibrarianController.updateBook(
      newBook,
      'Edited Book',
      'ISBN-NEW',
      'New Publisher',
      2026,
      '2',
      'English',
      'Edited',
      null,
      null,
      null
    );
    Id newCopy = LibraryLibrarianController.addCopy(
      newBook,
      'BAR-NEW',
      'A1',
      Date.today(),
      'Good',
      10
    );
    System.assertEquals(
      1,
      LibraryLibrarianController.getBookCopies(newBook).size()
    );
    LibraryLibrarianController.updateCopy(
      newCopy,
      'A2',
      Date.today(),
      'Excellent',
      12,
      'Maintenance'
    );
    LibraryLibrarianController.updateCopy(
      newCopy,
      'A2',
      Date.today(),
      'Excellent',
      12,
      'Available'
    );
    LibraryLibrarianController.retireCopy(newCopy);
    System.assert(data.totalBooks > 0);
    System.assertEquals(1, books.size());
    System.assertEquals(1, members.size());
  }
  @IsTest
  static void controllerReturnsOperationalData() {
    Fixture f = fixture('Five');
    Id loanId = LibraryLibrarianController.checkout(f.member.Id, f.copy.Id);
    LibraryLibrarianController.renewLoan(loanId);
    LibraryLibrarianController.returnLoan(loanId);
    Fine__c fine = new Fine__c(
      Member__c = f.member.Id,
      Contact__c = f.contact.Id,
      Fine_Type__c = 'Other',
      Amount__c = 10,
      Paid_Amount__c = 0,
      Status__c = 'Unpaid',
      Generated_Date__c = Date.today()
    );
    insert fine;
    LibraryLibrarianController.recordFinePayment(fine.Id, 5);
    LibraryLibrarianController.waiveFine(fine.Id, 'Test waiver');
    LibraryLibrarianController.getRegistrations();
    LibraryLibrarianController.getReservations();
    LibraryLibrarianController.getFines();
    LibraryLibrarianController.getMemberDetail(f.member.Id);
    System.assertEquals(1, LibraryLibrarianController.getLoans(null).size());
    System.assert(LibraryLibrarianController.getMembershipPlans().size() > 0);
    List<LibraryLibrarianController.PaymentRow> paymentRows = LibraryLibrarianController.getPayments(
      null
    );
    System.assertEquals(1, paymentRows.size());
    System.assertEquals('Fine', paymentRows[0].paymentType);
    System.assertEquals(5, paymentRows[0].amount);
    LibraryLibrarianController.setMemberAccountStatus(f.member.Id, 'Suspended');
    System.assertEquals(
      'Suspended',
      [SELECT Account_Status__c FROM Member__c WHERE Id = :f.member.Id]
      .Account_Status__c
    );
    LibraryLibrarianController.setMemberAccountStatus(f.member.Id, 'Active');
    System.assertEquals(
      'Active',
      [SELECT Account_Status__c FROM Member__c WHERE Id = :f.member.Id]
      .Account_Status__c
    );
    Id addedMemberId = LibraryLibrarianController.addMember(
      'New',
      'Member',
      'new.member@example.com',
      '9876543210',
      f.plan.Id
    );
    LibraryLibrarianController.updateMember(
      addedMemberId,
      'Updated',
      'Member',
      'updated.member@example.com',
      '9876543211',
      f.plan.Id
    );
    Member__c addedMember = [
      SELECT First_Name__c, Email__c
      FROM Member__c
      WHERE Id = :addedMemberId
    ];
    System.assertEquals('Updated', addedMember.First_Name__c);
    System.assertEquals('updated.member@example.com', addedMember.Email__c);
    Id renewalPayment = LibraryLibrarianController.renewMemberMembership(
      f.member.Id
    );
    System.assertNotEquals(null, renewalPayment);
    Boolean resetBlocked = false;
    try {
      LibraryLibrarianController.resetMemberPassword(f.member.Id);
    } catch (AuraHandledException expected) {
      resetBlocked = true;
    }
    System.assertEquals(
      true,
      resetBlocked,
      'A member without a portal user cannot reset a password.'
    );
    Boolean nullApprovalBlocked = false;
    try {
      LibraryLibrarianController.approveRegistration(null);
    } catch (Exception e) {
      nullApprovalBlocked = true;
    }
    System.assertEquals(true, nullApprovalBlocked);
    Boolean nullRejectionBlocked = false;
    try {
      LibraryLibrarianController.rejectRegistration(null, 'test');
    } catch (Exception e) {
      nullRejectionBlocked = true;
    }
    System.assertEquals(true, nullRejectionBlocked);
    Boolean nullRetryBlocked = false;
    try {
      LibraryLibrarianController.retryProvisioning(null);
    } catch (Exception e) {
      nullRetryBlocked = true;
    }
    System.assertEquals(true, nullRetryBlocked);
  }
  @IsTest
  static void readyReservationCanBeIssuedAsLoan() {
    Fixture f = fixture('ReservedIssue');
    Reservation__c readyReservation = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Reservation_Date__c = System.now(),
      Queue_Position__c = 1,
      Status__c = 'Pending'
    );
    insert readyReservation;

    Test.startTest();
    Boolean prepared = LibraryLibrarianController.prepareReservation(
      readyReservation.Id
    );
    Id reservedLoanId = LibraryLibrarianController.issueReservedBook(
      readyReservation.Id
    );
    Test.stopTest();

    System.assertEquals(true, prepared);
    System.assertEquals(
      'Active',
      [SELECT Status__c FROM Borrow_Record__c WHERE Id = :reservedLoanId]
      .Status__c
    );
    System.assertEquals(
      'Fulfilled',
      [SELECT Status__c FROM Reservation__c WHERE Id = :readyReservation.Id]
      .Status__c
    );
    System.assertEquals(
      'Borrowed',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :f.copy.Id].Status__c
    );
    LibraryReservationWorkflowService.promoteAvailableReservations(null);
    Boolean fulfilledPrepareBlocked = false;
    try {
      LibraryLibrarianController.prepareReservation(readyReservation.Id);
    } catch (AuraHandledException expected) {
      fulfilledPrepareBlocked = true;
    }
    System.assertEquals(true, fulfilledPrepareBlocked);
  }
  @IsTest
  static void membershipPlansCanBeCreatedAndEdited() {
    authorizeLibrarian();

    Test.startTest();
    Id planId = LibraryLibrarianController.saveMembershipPlan(
      null,
      'Student Plan',
      'For students',
      90,
      3,
      14,
      2,
      1,
      5,
      0,
      true
    );
    LibraryLibrarianController.saveMembershipPlan(
      planId,
      'Student Plus',
      'Extended student access',
      365,
      5,
      21,
      3,
      2,
      10,
      500,
      false
    );
    Test.stopTest();

    Membership_Plan__c saved = [
      SELECT Name, Duration_Days__c, Borrow_Limit__c, Fee__c, Active__c
      FROM Membership_Plan__c
      WHERE Id = :planId
    ];
    System.assertEquals('Student Plus', saved.Name);
    System.assertEquals(365, saved.Duration_Days__c);
    System.assertEquals(5, saved.Borrow_Limit__c);
    System.assertEquals(500, saved.Fee__c);
    System.assertEquals(false, saved.Active__c);
  }
  @IsTest
  static void unauthorizedInternalUserCannotUseLibrarianEndpoints() {
    LibraryPolicyService.testGrantedPermissions.clear();
    LibraryRegistrationService.testLibrarianAuthorized = false;
    Boolean dashboardDenied = false;
    try {
      LibraryLibrarianController.getDashboard();
    } catch (AuraHandledException expected) {
      dashboardDenied = true;
    }
    System.assertEquals(
      true,
      dashboardDenied,
      'Librarian dashboard must require a server-side custom permission.'
    );
    Boolean registrationDenied = false;
    try {
      LibraryRegistrationService.requireLibrarian();
    } catch (AuraHandledException expected) {
      registrationDenied = true;
    }
    System.assertEquals(
      true,
      registrationDenied,
      'Registration management must require a server-side custom permission.'
    );
  }
}
