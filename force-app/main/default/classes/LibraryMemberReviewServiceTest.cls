@IsTest
private class LibraryMemberReviewServiceTest {
  @IsTest
  static void reviewIsPendingAndMemberScoped() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Review Plan',
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
      First_Name__c = 'Review',
      Last_Name__c = 'Member',
      Email__c = 'review@example.com',
      Normalized_Email__c = 'review@example.com',
      External_Auth_Id__c = 'review-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Book__c book = new Book__c(
      Name = 'Review Book',
      ISBN__c = 'REV-1',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'review-test'
    );
    LibraryMemberReviewService.ReviewDTO dto = LibraryMemberReviewService.submit(
      token,
      book.Id,
      5,
      'A thoughtful library review.'
    );
    System.assertEquals('Pending', dto.status);
    System.assertEquals(1, LibraryMemberReviewService.getMine(token).size());
  }
}
