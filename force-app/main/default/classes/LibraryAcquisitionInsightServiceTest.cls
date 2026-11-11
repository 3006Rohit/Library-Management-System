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

  private static void addHolds(Fixture f, Integer count, Datetime heldSince) {
    List<Reservation__c> holds = new List<Reservation__c>();
    for (Integer i = 0; i < count; i++)
      holds.add(
        new Reservation__c(
          Member__c = f.member.Id,
          Book__c = f.book.Id,
          Contact__c = f.contact.Id,
          Reservation_Date__c = heldSince,
          Status__c = 'Pending',
          Queue_Position__c = i + 1
        )
      );
    insert holds;
  }

  @IsTest
  static void recommendationsPersistEvidenceAndDecision() {
    Fixture f = fixture();
    Id loanId = LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 4, System.now());
    Test.startTest();
    List<LibraryAcquisitionInsightService.RecommendationDTO> rows = LibraryAcquisitionInsightService.getRecommendations();
    Test.stopTest();
    System.assertEquals(1, rows.size());
    System.assertEquals('Purchase', rows[0].recommendationType);
    System.assertEquals('Open', rows[0].status);
    System.assert(rows[0].evidence.contains('holds waiting'));
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
  static void decisionsSurviveRefreshAndCanBeUndone() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 4, System.now());
    List<LibraryAcquisitionInsightService.RecommendationDTO> first = LibraryAcquisitionInsightService.getRecommendations();
    // 4:1 hold ratio (capped 50) + 1 loan per copy (5) + empty shelf (10)
    System.assertEquals(65, first[0].score);
    System.assertEquals(1, first[0].recommendedQuantity);

    LibraryAcquisitionInsightService.decide(
      first[0].id,
      'Accepted',
      'Order it'
    );
    List<LibraryAcquisitionInsightService.RecommendationDTO> again = LibraryAcquisitionInsightService.getRecommendations();
    System.assertEquals(1, again.size());
    System.assertEquals(first[0].id, again[0].id);
    System.assertEquals('Accepted', again[0].status);
    System.assertEquals('Order it', again[0].decisionNotes);
    System.assertEquals(1, [SELECT COUNT() FROM Acquisition_Recommendation__c]);

    LibraryAcquisitionInsightService.decide(first[0].id, 'Open', null);
    System.assertEquals(
      'Open',
      LibraryAcquisitionInsightService.getRecommendations()[0].status
    );

    Boolean rejected = false;
    try {
      LibraryAcquisitionInsightService.decide(first[0].id, 'Bogus', null);
    } catch (AuraHandledException expected) {
      rejected = true;
    }
    System.assertEquals(true, rejected);
  }

  @IsTest
  static void purchaseQuantityFollowsHoldRatioAndWaitTime() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 10, System.now().addDays(-30));
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    // 10 holds at 3:1 needs 4 copies; 1 owned, so buy 3
    System.assertEquals('Purchase', row.recommendationType);
    System.assertEquals(3, row.recommendedQuantity);
    // ratio capped 50 + 30 day wait (15) + loans (5) + empty shelf (10)
    System.assertEquals(80, row.score);
    System.assertEquals(30, row.longestWaitDays);
  }

  @IsTest
  static void holdsBelowTargetDoNotTriggerPurchase() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 2, System.now());
    System.assertEquals(
      0,
      LibraryAcquisitionInsightService.getRecommendations().size()
    );
  }

  @IsTest
  static void longWaitTriggersOneCopyEvenBelowRatio() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 1, System.now().addDays(-25));
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    System.assertEquals('Purchase', row.recommendationType);
    System.assertEquals(1, row.recommendedQuantity);
  }

  @IsTest
  static void unusedEstablishedTitleIsFlaggedForWeeding() {
    Fixture f = fixture();
    update new Book_Copy__c(
      Id = f.copy.Id,
      Acquisition_Date__c = Date.today().addYears(-3)
    );
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    System.assertEquals('Weed', row.recommendationType);
    System.assertEquals(1, row.recommendedQuantity);
  }

  @IsTest
  static void newTitleIsNeverWeeded() {
    Fixture f = fixture();
    update new Book_Copy__c(
      Id = f.copy.Id,
      Acquisition_Date__c = Date.today().addMonths(-3)
    );
    System.assertEquals(
      0,
      LibraryAcquisitionInsightService.getRecommendations().size()
    );
  }

  @IsTest
  static void damagedCopyIsReplacedOnlyWhileTitleIsWanted() {
    Fixture f = fixture();
    update new Book_Copy__c(Id = f.copy.Id, Status__c = 'Damaged');
    // No demand: nothing to replace
    System.assertEquals(
      0,
      LibraryAcquisitionInsightService.getRecommendations().size()
    );
    addHolds(f, 1, System.now());
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    System.assertEquals('Replace', row.recommendationType);
    System.assertEquals(1, row.recommendedQuantity);
  }

  @IsTest
  static void agentforceAnswerIsUsedWhenItFollowsTheRules() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 4, System.now());
    LibraryAcquisitionInsightService.testAiResponse =
      '```json' +
      '\n' +
      '[{"bookId":"' +
      f.book.Id +
      '","type":"Purchase","quantity":2,' +
      '"score":88,"confidence":"High","rationale":"4 holds on one copy."}]' +
      '\n' +
      '```';
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    System.assertEquals('Agentforce', row.generatedBy);
    System.assertEquals('Purchase', row.recommendationType);
    System.assertEquals(2, row.recommendedQuantity);
    System.assertEquals(88, row.score);
    System.assertEquals('High', row.confidence);
    System.assert(row.evidence.contains('4 holds on one copy.'));
  }

  @IsTest
  static void agentforceCannotWeedATitleThatHasHolds() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 4, System.now());
    LibraryAcquisitionInsightService.testAiResponse =
      '[{"bookId":"' +
      f.book.Id +
      '","type":"Weed","quantity":1,' +
      '"score":90,"confidence":"High","rationale":"Remove it."}]';
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    // Rejected, so the rule-based answer is used instead
    System.assertEquals('Rules', row.generatedBy);
    System.assertEquals('Purchase', row.recommendationType);
  }

  @IsTest
  static void unreadableAgentforceOutputFallsBackToRules() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 4, System.now());
    LibraryAcquisitionInsightService.testAiResponse = 'Sorry, I cannot help.';
    LibraryAcquisitionInsightService.RecommendationDTO row = LibraryAcquisitionInsightService.getRecommendations()[0];
    System.assertEquals('Rules', row.generatedBy);
    System.assertEquals('Purchase', row.recommendationType);
  }

  @IsTest
  static void agentforceCanDecideATitleNeedsNothing() {
    Fixture f = fixture();
    LibraryCirculationService.checkout(f.member.Id, f.copy.Id);
    addHolds(f, 4, System.now());
    LibraryAcquisitionInsightService.testAiResponse =
      '[{"bookId":"' +
      f.book.Id +
      '","type":"None","quantity":0,' +
      '"score":1,"confidence":"Low","rationale":"Fine."}]';
    System.assertEquals(
      0,
      LibraryAcquisitionInsightService.getRecommendations().size()
    );
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
