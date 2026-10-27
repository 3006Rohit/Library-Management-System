@IsTest
private class LibraryMemberEngagementServiceTest {
  private class Fixture {
    Member__c member;
    Book__c book;
    String token;
  }
  private static Fixture fixture(String suffix) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Engagement ' + suffix,
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
      First_Name__c = 'Engage',
      Last_Name__c = suffix,
      Email__c = 'engage-' + suffix + '@example.com',
      Normalized_Email__c = 'engage-' + suffix + '@example.com',
      External_Auth_Id__c = 'engage-' + suffix,
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Book__c book = new Book__c(
      Name = 'Engagement Book ' + suffix,
      ISBN__c = 'ENG-' + suffix,
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    Fixture f = new Fixture();
    f.member = member;
    f.book = book;
    f.token = LibraryMemberSessionService.create(
      member,
      null,
      'engagement-test'
    );
    return f;
  }
  @IsTest
  static void saveUpdatesOnePrivateEntryAndListsIt() {
    Fixture f = fixture('One');
    LibraryMemberEngagementService.EngagementDTO saved = LibraryMemberEngagementService.save(
      f.token,
      f.book.Id,
      'Want to Read',
      'Read this next',
      4,
      true
    );
    System.assertEquals('Want to Read', saved.state);
    LibraryMemberEngagementService.EngagementDTO updated = LibraryMemberEngagementService.save(
      f.token,
      f.book.Id,
      'Completed',
      'Finished it',
      5,
      false
    );
    System.assertEquals(saved.id, updated.id);
    System.assertEquals(
      1,
      LibraryMemberEngagementService.getAll(f.token).size()
    );
    System.assertEquals(
      'Completed',
      LibraryMemberEngagementService.getAll(f.token)[0].state
    );
  }
  @IsTest
  static void memberCannotDeleteAnotherMembersEntry() {
    Fixture owner = fixture('Owner');
    Fixture other = fixture('Other');
    LibraryMemberEngagementService.EngagementDTO row = LibraryMemberEngagementService.save(
      owner.token,
      owner.book.Id,
      'Currently Reading',
      null,
      null,
      false
    );
    Boolean blocked = false;
    try {
      LibraryMemberEngagementService.remove(other.token, row.id);
    } catch (Exception error) {
      blocked = true;
    }
    System.assertEquals(true, blocked);
    System.assertEquals(
      1,
      LibraryMemberEngagementService.getAll(owner.token).size()
    );
  }
}
