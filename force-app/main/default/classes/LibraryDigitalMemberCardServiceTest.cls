@IsTest
private class LibraryDigitalMemberCardServiceTest {
  private static Member__c createMember() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Digital Card Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5,
      Fee__c = 10
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Digital',
      Last_Name__c = 'Card',
      Email__c = 'digital-card@example.com',
      Normalized_Email__c = 'digital-card@example.com',
      External_Auth_Id__c = 'digital-card-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    return member;
  }

  @IsTest
  static void issueAndConsumeCardTokenOnce() {
    Member__c member = createMember();
    String sessionToken = LibraryMemberSessionService.create(
      member,
      null,
      'card-test'
    );
    LibraryDigitalMemberCardService.CardDTO issued = LibraryDigitalMemberCardService.issue(
      sessionToken
    );
    System.assertEquals(true, issued.valid);
    System.assertEquals('Digital Card', issued.memberName);
    System.assertNotEquals(null, issued.token);

    Test.startTest();
    LibraryDigitalMemberCardService.CardDTO validated = LibraryDigitalMemberCardService.validate(
      issued.token
    );
    Test.stopTest();
    System.assertEquals(true, validated.valid);
    System.assertNotEquals(null, validated.memberNumber);

    LibraryDigitalMemberCardService.CardDTO replay = LibraryDigitalMemberCardService.validate(
      issued.token
    );
    System.assertEquals(false, replay.valid);
    System.assertEquals(
      'This member card is invalid or expired.',
      replay.message
    );
  }

  @IsTest
  static void expiredOrUnknownTokensAreRejected() {
    System.assertEquals(
      false,
      LibraryDigitalMemberCardService.validate('not-a-real-card').valid
    );
    Member__c member = createMember();
    String sessionToken = LibraryMemberSessionService.create(
      member,
      null,
      'card-expiry-test'
    );
    LibraryDigitalMemberCardService.CardDTO issued = LibraryDigitalMemberCardService.issue(
      sessionToken
    );
    Library_Scan_Transaction__c row = [
      SELECT Id, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = 'Member Card' AND Member__c = :member.Id
      LIMIT 1
    ];
    row.Created_At__c = System.now().addMinutes(-11);
    update row;
    System.assertEquals(
      false,
      LibraryDigitalMemberCardService.validate(issued.token).valid
    );
  }
}
