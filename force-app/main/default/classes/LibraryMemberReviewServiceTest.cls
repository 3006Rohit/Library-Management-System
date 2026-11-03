@IsTest
private class LibraryMemberReviewServiceTest {
  private static Member__c member(String email) {
    Member__c value = new Member__c(
      First_Name__c = 'Rita',
      Last_Name__c = 'Reader',
      Email__c = email,
      Normalized_Email__c = email,
      Status__c = 'Active',
      Account_Status__c = 'Active'
    );
    insert value;
    return value;
  }

  private static Book__c book() {
    Book__c value = new Book__c(
      Name = 'Reviewed Book',
      ISBN__c = 'REVIEW-ISBN',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert value;
    return value;
  }

  @IsTest
  static void submittedReviewWaitsForModerationThenPublishes() {
    Member__c reader = member('reader@example.com');
    Book__c reviewed = book();
    String token = LibraryMemberSessionService.create(
      reader,
      '127.0.0.1',
      'test'
    );

    LibraryMemberReviewService.ReviewDTO saved = LibraryMemberReviewService.submit(
      token,
      reviewed.Id,
      5,
      'A wonderful and thoughtful read.'
    );
    System.assertEquals('Pending', saved.status);
    System.assertEquals(
      0,
      LibraryMemberReviewService.getPublished(token, reviewed.Id).size()
    );
    System.assertEquals(1, LibraryMemberReviewService.getMine(token).size());

    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    List<LibraryMemberReviewService.ReviewDTO> queue = LibraryMemberReviewService.getPending();
    System.assertEquals(1, queue.size());
    System.assertEquals('Rita Reader', queue[0].memberName);
    System.assertEquals(5, queue[0].rating);

    LibraryMemberReviewService.moderate(queue[0].id, 'Published');
    System.assertEquals(0, LibraryMemberReviewService.getPending().size());
    List<LibraryMemberReviewService.ReviewDTO> published = LibraryMemberReviewService.getPublished(
      token,
      reviewed.Id
    );
    System.assertEquals(1, published.size());
    System.assertEquals('Published', published[0].status);
    System.assertEquals(
      'Published',
      LibraryMemberReviewService.getMine(token)[0].status
    );
  }

  @IsTest
  static void rejectedReviewStaysOutOfThePublicList() {
    Member__c reader = member('reject@example.com');
    Book__c reviewed = book();
    String token = LibraryMemberSessionService.create(
      reader,
      '127.0.0.1',
      'test'
    );
    LibraryMemberReviewService.ReviewDTO saved = LibraryMemberReviewService.submit(
      token,
      reviewed.Id,
      1,
      'Not for me at all, sadly.'
    );
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    LibraryMemberReviewService.moderate(saved.id, 'Rejected');
    System.assertEquals(
      0,
      LibraryMemberReviewService.getPublished(token, reviewed.Id).size()
    );
    System.assertEquals(0, LibraryMemberReviewService.getPending().size());
    System.assertEquals(
      'Rejected',
      LibraryMemberReviewService.getMine(token)[0].status
    );
  }

  @IsTest
  static void resubmittingReplacesTheReviewAndRequeuesIt() {
    Member__c reader = member('again@example.com');
    Book__c reviewed = book();
    String token = LibraryMemberSessionService.create(
      reader,
      '127.0.0.1',
      'test'
    );
    LibraryMemberReviewService.ReviewDTO first = LibraryMemberReviewService.submit(
      token,
      reviewed.Id,
      3,
      'It was fine overall.'
    );
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    LibraryMemberReviewService.moderate(first.id, 'Published');
    LibraryMemberReviewService.submit(
      token,
      reviewed.Id,
      4,
      'Better on the second read.'
    );
    System.assertEquals(1, LibraryMemberReviewService.getMine(token).size());
    System.assertEquals(1, LibraryMemberReviewService.getPending().size());
    System.assertEquals(
      0,
      LibraryMemberReviewService.getPublished(token, reviewed.Id).size()
    );
  }

  @IsTest
  static void invalidSubmissionsAndUnauthorizedModerationAreRejected() {
    Member__c reader = member('invalid@example.com');
    Book__c reviewed = book();
    String token = LibraryMemberSessionService.create(
      reader,
      '127.0.0.1',
      'test'
    );
    try {
      LibraryMemberReviewService.submit(
        token,
        reviewed.Id,
        9,
        'Ratings only go to five.'
      );
      System.assert(false, 'Expected an invalid rating to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
    try {
      LibraryMemberReviewService.submit(token, reviewed.Id, 4, 'Too short');
      System.assert(false, 'Expected a short review to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
    try {
      LibraryMemberReviewService.getPending();
      System.assert(false, 'Expected moderation access to be required.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }
}
