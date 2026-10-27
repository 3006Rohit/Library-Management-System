@IsTest
private class LibraryAgentConfirmationServiceTest {
  private class Fixture {
    Member__c member;
    Book__c book;
    Book_Copy__c copy;
    Borrow_Record__c loan;
    String token;
  }
  private static Fixture fixture() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Agent Confirm Plan',
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
      First_Name__c = 'Confirm',
      Last_Name__c = 'Member',
      Email__c = 'confirm@example.com',
      Normalized_Email__c = 'confirm@example.com',
      External_Auth_Id__c = 'confirm-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Book__c book = new Book__c(
      Name = 'Confirm Book',
      ISBN__c = 'CONFIRM-ISBN',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 0
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'CONFIRM-BAR',
      Status__c = 'Borrowed',
      Condition__c = 'Good'
    );
    insert copy;
    Borrow_Record__c loan = new Borrow_Record__c(
      Member__c = member.Id,
      Book_Copy__c = copy.Id,
      Borrow_Date__c = System.now(),
      Due_Date__c = System.now().addDays(7),
      Status__c = 'Active',
      Renewal_Count__c = 0
    );
    insert loan;
    Fixture f = new Fixture();
    f.member = member;
    f.book = book;
    f.copy = copy;
    f.loan = loan;
    f.token = LibraryMemberSessionService.create(
      member,
      null,
      'confirmation-test'
    );
    return f;
  }
  @IsTest
  static void renewalRequiresExplicitSingleUseConfirmation() {
    Fixture f = fixture();
    LibraryAgentConfirmationService.PreviewDTO preview = LibraryAgentConfirmationService.preview(
      f.token,
      'renew_loan',
      f.loan.Id
    );
    System.assertEquals('RENEW_LOAN', preview.action);
    System.assert(preview.preview.contains('Confirm Book'));
    LibraryAgentConfirmationService.confirm(f.token, preview.token);
    Borrow_Record__c renewed = [
      SELECT Renewal_Count__c
      FROM Borrow_Record__c
      WHERE Id = :f.loan.Id
    ];
    System.assertEquals(1, renewed.Renewal_Count__c);
    Boolean replayBlocked = false;
    try {
      LibraryAgentConfirmationService.confirm(f.token, preview.token);
    } catch (Exception error) {
      replayBlocked = true;
    }
    System.assertEquals(true, replayBlocked);
  }
  @IsTest
  static void unsupportedActionAndCrossMemberTargetAreDenied() {
    Fixture f = fixture();
    Boolean unsupported = false;
    try {
      LibraryAgentConfirmationService.preview(f.token, 'waive_fine', f.loan.Id);
    } catch (Exception error) {
      unsupported = true;
    }
    System.assertEquals(true, unsupported);
    Member__c other = f.member.clone(false, true, false, false);
    other.Id = null;
    other.Email__c = 'other-confirm@example.com';
    other.Normalized_Email__c = 'other-confirm@example.com';
    other.External_Auth_Id__c = 'other-confirm';
    insert other;
    String otherToken = LibraryMemberSessionService.create(
      other,
      null,
      'confirmation-test'
    );
    Boolean crossMemberBlocked = false;
    try {
      LibraryAgentConfirmationService.preview(
        otherToken,
        'renew_loan',
        f.loan.Id
      );
    } catch (Exception error) {
      crossMemberBlocked = true;
    }
    System.assertEquals(true, crossMemberBlocked);
  }
}
