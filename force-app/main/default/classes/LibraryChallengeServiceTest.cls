@IsTest
private class LibraryChallengeServiceTest {
  @IsTest
  static void challengeEnrollmentIsIdempotentAndTracksBorrowProgress() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Challenge Plan',
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
      First_Name__c = 'Challenge',
      Last_Name__c = 'Member',
      Email__c = 'challenge-member@example.com',
      Normalized_Email__c = 'challenge-member@example.com',
      External_Auth_Id__c = 'challenge-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'challenge-test'
    );
    Id challengeId = LibraryChallengeService.create(
      'Read Two',
      'Read two books this month',
      System.now().addDays(-1),
      System.now().addDays(20),
      2
    );
    LibraryChallengeService.ChallengeDTO first = LibraryChallengeService.enroll(
      token,
      challengeId
    );
    LibraryChallengeService.ChallengeDTO second = LibraryChallengeService.enroll(
      token,
      challengeId
    );
    System.assertEquals('Enrolled', first.enrollmentStatus);
    System.assertEquals(first.enrollmentStatus, second.enrollmentStatus);
    insert new List<Borrow_Record__c>{
      new Borrow_Record__c(
        Member__c = member.Id,
        Borrow_Date__c = System.now().addDays(-1),
        Status__c = 'Active',
        Renewal_Count__c = 0
      ),
      new Borrow_Record__c(
        Member__c = member.Id,
        Borrow_Date__c = System.now(),
        Status__c = 'Active',
        Renewal_Count__c = 0
      )
    };
    System.assertEquals(
      1,
      LibraryChallengeService.syncAchievements(token).size()
    );
    LibraryChallengeService.setLeaderboardOptIn(token, true);
    System.assertEquals(
      1,
      LibraryChallengeService.getAchievements(token).size()
    );
    System.assertEquals(
      1,
      LibraryChallengeService.getLeaderboard(token, challengeId).size()
    );
    System.assertEquals(
      'Completed',
      LibraryChallengeService.getAvailable(token)[0].enrollmentStatus
    );
    System.assertEquals(1, LibraryChallengeService.getAvailable(token).size());
    LibraryChallengeService.leave(token, challengeId);
    System.assertEquals(
      null,
      LibraryChallengeService.getAvailable(token)[0].enrollmentStatus
    );
  }
}
