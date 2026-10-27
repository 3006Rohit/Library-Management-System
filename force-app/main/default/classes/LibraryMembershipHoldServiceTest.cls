@IsTest
private class LibraryMembershipHoldServiceTest {
  private class Fixture {
    Member__c member;
    String token;
  }

  private static Fixture fixture() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Hold Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5,
      Fee__c = 20
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Hold',
      Last_Name__c = 'Member',
      Email__c = 'hold-member@example.com',
      Normalized_Email__c = 'hold-member@example.com',
      External_Auth_Id__c = 'hold-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 5
    );
    insert member;
    Fixture f = new Fixture();
    f.member = member;
    f.token = LibraryMemberSessionService.create(member, null, 'hold-test');
    return f;
  }

  @IsTest
  static void requestIsIdempotentAndApprovalExtendsMembership() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    Fixture f = fixture();
    Date start = Date.today().addDays(2);
    Date finish = Date.today().addDays(8);
    Date originalEnd = f.member.Membership_End_Date__c;
    LibraryMembershipHoldService.HoldDTO first = LibraryMembershipHoldService.submit(
      f.token,
      start,
      finish,
      'Travel during the requested period.'
    );
    LibraryMembershipHoldService.HoldDTO second = LibraryMembershipHoldService.submit(
      f.token,
      start,
      finish,
      'A different reason is ignored by idempotency.'
    );
    System.assertEquals(first.id, second.id);
    System.assertEquals('Pending', first.status);

    Test.startTest();
    LibraryMembershipHoldService.decide(
      first.id,
      'Approved',
      'Approved under the standard annual hold policy.'
    );
    Test.stopTest();
    Member__c updated = [
      SELECT Membership_End_Date__c
      FROM Member__c
      WHERE Id = :f.member.Id
    ];
    System.assertEquals(originalEnd.addDays(7), updated.Membership_End_Date__c);
    System.assertEquals(
      'Approved',
      LibraryMembershipHoldService.getMine(f.token)[0].status
    );
    System.assertEquals(
      updated.Membership_End_Date__c,
      LibraryMembershipHoldService.getMine(f.token)[0].adjustedEndDate
    );
  }

  @IsTest
  static void overlapAndCancellationAreProtected() {
    Fixture f = fixture();
    Date start = Date.today().addDays(3);
    Date finish = Date.today().addDays(5);
    LibraryMembershipHoldService.HoldDTO hold = LibraryMembershipHoldService.submit(
      f.token,
      start,
      finish,
      'Medical appointment requires a short hold.'
    );
    try {
      LibraryMembershipHoldService.submit(
        f.token,
        start.addDays(1),
        finish.addDays(1),
        'Overlapping dates should be rejected.'
      );
      System.assert(false, 'Expected overlap validation');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    LibraryMembershipHoldService.cancel(f.token, hold.id);
    System.assertEquals(
      'Cancelled',
      LibraryMembershipHoldService.getMine(f.token)[0].status
    );
  }

  @IsTest
  static void graceStatusIsReadOnlyAndExplicit() {
    Fixture f = fixture();
    f.member.Membership_Start_Date__c = Date.today().addDays(-365);
    f.member.Membership_End_Date__c = Date.today().addDays(-2);
    update f.member;
    LibraryMembershipHoldService.MembershipStatusDTO status = LibraryMembershipHoldService.getStatus(
      f.token
    );
    System.assertEquals(true, status.graceActive);
    System.assertEquals(false, status.borrowingAllowed);
    System.assertEquals(Date.today().addDays(5), status.gracePeriodEndsOn);
  }
}
