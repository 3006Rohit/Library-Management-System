@IsTest
private class LibraryMemberAuthorFollowServiceTest {
  private class Fixture {
    Member__c member;
    Author__c author;
    String token;
  }

  private static Fixture fixture(String suffix) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Author Follow ' + suffix,
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
      First_Name__c = 'Follow',
      Last_Name__c = suffix,
      Email__c = 'follow-' + suffix + '@example.com',
      Normalized_Email__c = 'follow-' + suffix + '@example.com',
      External_Auth_Id__c = 'follow-' + suffix,
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Author__c author = new Author__c(Name = 'Followed Author ' + suffix);
    insert author;
    Fixture f = new Fixture();
    f.member = member;
    f.author = author;
    f.token = LibraryMemberSessionService.create(member, null, 'follow-test');
    return f;
  }

  @IsTest
  static void followIsIdempotentAndCanBeRemoved() {
    Fixture f = fixture('One');
    LibraryMemberAuthorFollowService.FollowDTO first = LibraryMemberAuthorFollowService.follow(
      f.token,
      f.author.Id
    );
    LibraryMemberAuthorFollowService.FollowDTO second = LibraryMemberAuthorFollowService.follow(
      f.token,
      f.author.Id
    );
    System.assertEquals(first.id, second.id);
    System.assertEquals(
      1,
      LibraryMemberAuthorFollowService.getAll(f.token).size()
    );
    LibraryMemberAuthorFollowService.unfollow(f.token, first.id);
    System.assertEquals(
      0,
      LibraryMemberAuthorFollowService.getAll(f.token).size()
    );
  }
}
