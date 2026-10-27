@IsTest
private class LibraryAcquisitionInsightServiceTest {
  private class Fixture {
    Membership_Plan__c plan;
    Account account;
    Contact contact;
    Member__c member;
    Book__c book;
    Book_Copy__c copy;
  }

  private static Fixture fixture() {
    LibraryPolicyService.testGrantedPermissions = new Set<String>{
      'Manage_Library_Catalog',
      'Manage_Library_Circulation'
    };
    LibraryRegistrationService.testLibrarianAuthorized = true;
    Fixture f = new Fixture();
    f.plan = new Membership_Plan__c(
      Name = 'Insight Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 10,
      Fee__c = 10
    );
    insert f.plan;
    f.account = new Account(Name = 'Insight Account');
    insert f.account;
    f.contact = new Contact(
      FirstName = 'Insight',
      LastName = 'Member',
      Email = 'insight@example.com',
      AccountId = f.account.Id
    );
    insert f.contact;
    f.member = new Member__c(
      First_Name__c = 'Insight',
      Last_Name__c = 'Member',
      Email__c = f.contact.Email,
      Contact__c = f.contact.Id,
      External_Auth_Id__c = 'insight-member',
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
      Name = 'Insight Book',
      ISBN__c = 'INSIGHT-1',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert f.book;
    f.copy = new Book_Copy__c(
      Book__c = f.book.Id,
      Barcode__c = 'INSIGHT-BAR',
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    insert f.copy;
    return f;
  }

  @IsTest
  static void recommendationsPersistEvidenceAndDecision() {
    Fixture f = fixture();
    Id loanId = LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    Reservation__c reservation = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 1
    );
    insert reservation;
    Test.startTest();
    List<LibraryAcquisitionInsightService.RecommendationDTO> rows = LibraryAcquisitionInsightService.getRecommendations();
    Test.stopTest();
    System.assertEquals(1, rows.size());
    System.assertEquals('Purchase', rows[0].recommendationType);
    System.assertEquals('Open', rows[0].status);
    System.assert(rows[0].evidence.contains('reservations'));
    Acquisition_Recommendation__c snapshot = [
      SELECT Id, Evidence__c, Status__c, Snapshot_Key__c
      FROM Acquisition_Recommendation__c
      LIMIT 1
    ];
    System.assertNotEquals(null, snapshot.Snapshot_Key__c);
    LibraryAcquisitionInsightService.decide(
      snapshot.Id,
      'Accepted',
      'Approved for next order'
    );
    snapshot = [
      SELECT Status__c, Decision_Notes__c
      FROM Acquisition_Recommendation__c
      WHERE Id = :snapshot.Id
    ];
    System.assertEquals('Accepted', snapshot.Status__c);
    System.assertEquals('Approved for next order', snapshot.Decision_Notes__c);
    System.assertNotEquals(null, loanId);
  }

  @IsTest
  static void telemetryStoresHashWithoutRawQuery() {
    fixture();
    Test.startTest();
    LibraryAcquisitionInsightService.recordSearchTelemetry(
      'rare science fiction',
      0,
      null
    );
    Test.stopTest();
    Search_Analytics__c event = [
      SELECT Search_Hash__c, Search_Result_Count__c, Search_Status__c
      FROM Search_Analytics__c
      LIMIT 1
    ];
    System.assertEquals(64, event.Search_Hash__c.length());
    System.assertEquals(0, event.Search_Result_Count__c);
    System.assertEquals('Zero Results', event.Search_Status__c);
  }
}
