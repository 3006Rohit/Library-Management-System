@IsTest
private class LibraryScanServiceTest {
  private class Fixture {
    Member__c member;
    Book_Copy__c copy;
    String sessionToken;
  }

  private static Fixture fixture(String suffix) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Scan Plan ' + suffix,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert plan;
    Account account = new Account(Name = 'Scan Account ' + suffix);
    insert account;
    Contact contact = new Contact(
      FirstName = 'Scan',
      LastName = suffix,
      Email = 'scan-' + suffix.toLowerCase() + '@example.com',
      AccountId = account.Id
    );
    insert contact;
    Member__c member = new Member__c(
      First_Name__c = 'Scan',
      Last_Name__c = suffix,
      Email__c = contact.Email,
      Normalized_Email__c = contact.Email,
      Contact__c = contact.Id,
      Membership_Plan__c = plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3,
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Email_Verified__c = true
    );
    insert member;
    Book__c book = new Book__c(
      Name = 'Scanned Book ' + suffix,
      ISBN__c = 'SCAN-' + suffix,
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'SCAN-BAR-' + suffix,
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    insert copy;
    Fixture result = new Fixture();
    result.member = member;
    result.copy = copy;
    result.sessionToken = LibraryMemberSessionService.create(
      member,
      '127.0.0.1',
      'scan-test'
    );
    return result;
  }

  @IsTest
  static void checkoutScanIsIdempotent() {
    Fixture f = fixture('One');

    Test.startTest();
    LibraryScanService.ScanResult first = LibraryScanService.selfCheckout(
      f.sessionToken,
      f.copy.Barcode__c,
      'scan-idempotency-one'
    );
    LibraryScanService.ScanResult second = LibraryScanService.selfCheckout(
      f.sessionToken,
      f.copy.Barcode__c,
      'scan-idempotency-one'
    );
    Test.stopTest();

    System.assertEquals(true, first.success);
    System.assertEquals(first.loanId, second.loanId);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE Member__c = :f.member.Id AND Book_Copy__c = :f.copy.Id
      ]
    );
  }

  @IsTest
  static void returnScanUsesOnlyMemberLoan() {
    Fixture f = fixture('Two');
    LibraryScanService.ScanResult checkout = LibraryScanService.selfCheckout(
      f.sessionToken,
      f.copy.Barcode__c,
      'scan-idempotency-two'
    );

    Test.startTest();
    LibraryScanService.ScanResult returned = LibraryScanService.returnItem(
      f.sessionToken,
      f.copy.Barcode__c,
      'scan-return-two'
    );
    Test.stopTest();

    System.assertEquals(true, checkout.success);
    System.assertEquals(true, returned.success);
    System.assertEquals(
      'Returned',
      [SELECT Status__c FROM Borrow_Record__c WHERE Id = :checkout.loanId]
      .Status__c
    );
    System.assertEquals(
      'Available',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :f.copy.Id].Status__c
    );
  }

  @IsTest
  static void unknownBarcodeFailsWithoutLoan() {
    Fixture f = fixture('Three');

    Test.startTest();
    LibraryScanService.ScanResult result = LibraryScanService.selfCheckout(
      f.sessionToken,
      'DOES-NOT-EXIST',
      'scan-idempotency-three'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Borrow_Record__c WHERE Member__c = :f.member.Id]
    );
  }
}
