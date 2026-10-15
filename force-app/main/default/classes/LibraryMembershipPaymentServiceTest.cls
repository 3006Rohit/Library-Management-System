@IsTest
private class LibraryMembershipPaymentServiceTest {
  @IsTest
  static void upgradePreservesRemainingMembershipTime() {
    Membership_Plan__c currentPlan = new Membership_Plan__c(
      Name = 'Payment Current',
      Active__c = true,
      Duration_Days__c = 30,
      Borrow_Limit__c = 2,
      Loan_Duration_Days__c = 7,
      Reservation_Limit__c = 1,
      Renewal_Limit__c = 0,
      Fine_Per_Day__c = 5,
      Fee__c = 100
    );
    Membership_Plan__c upgradePlan = new Membership_Plan__c(
      Name = 'Payment Upgrade',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 2,
      Fine_Per_Day__c = 2,
      Fee__c = 500
    );
    insert new List<Membership_Plan__c>{ currentPlan, upgradePlan };
    Account account = new Account(Name = 'Payment Test Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Payment',
      LastName = 'Member',
      Email = 'payment-' + DateTime.now().getTime() + '@example.com',
      AccountId = account.Id
    );
    insert contact;
    Date existingEnd = Date.today().addDays(20);
    Member__c member = new Member__c(
      First_Name__c = 'Payment',
      Last_Name__c = 'Member',
      Email__c = contact.Email,
      Contact__c = contact.Id,
      Membership_Plan__c = currentPlan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today().addDays(-10),
      Membership_End_Date__c = existingEnd,
      Max_Borrow_Limit__c = 2,
      Status__c = 'Active'
    );
    insert member;
    Test.startTest();
    Id paymentId = LibraryMembershipPaymentService.payAndUpgrade(
      member.Id,
      upgradePlan.Id
    );
    Test.stopTest();
    Member__c updated = [
      SELECT
        Membership_Plan__c,
        Membership_Start_Date__c,
        Membership_End_Date__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    Membership_Payment__c payment = [
      SELECT Id, Status__c, Amount__c, Previous_Plan__c, New_Plan__c
      FROM Membership_Payment__c
      WHERE Id = :paymentId
    ];
    System.assertEquals(upgradePlan.Id, updated.Membership_Plan__c);
    System.assertEquals(Date.today(), updated.Membership_Start_Date__c);
    System.assertEquals(
      existingEnd.addDays(365),
      updated.Membership_End_Date__c
    );
    System.assertEquals('Paid', payment.Status__c);
    System.assertEquals(500, payment.Amount__c);
    System.assertEquals(currentPlan.Id, payment.Previous_Plan__c);
    System.assertEquals(upgradePlan.Id, payment.New_Plan__c);
  }
  @IsTest
  static void invalidUpgradePlanReturnsControlledError() {
    Membership_Plan__c currentPlan = new Membership_Plan__c(
      Name = 'Invalid Plan Current',
      Active__c = true,
      Duration_Days__c = 30,
      Borrow_Limit__c = 2,
      Loan_Duration_Days__c = 7,
      Reservation_Limit__c = 1,
      Renewal_Limit__c = 0,
      Fine_Per_Day__c = 5,
      Fee__c = 100
    );
    insert currentPlan;
    Account account = new Account(Name = 'Invalid Plan Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Invalid',
      LastName = 'Plan',
      Email = 'invalid-plan-' + DateTime.now().getTime() + '@example.com',
      AccountId = account.Id
    );
    insert contact;
    Member__c member = new Member__c(
      First_Name__c = 'Invalid',
      Last_Name__c = 'Plan',
      Email__c = contact.Email,
      Contact__c = contact.Id,
      Membership_Plan__c = currentPlan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(30),
      Max_Borrow_Limit__c = 2,
      Status__c = 'Active'
    );
    insert member;
    Boolean failed = false;
    try {
      LibraryMembershipPaymentService.payAndUpgrade(member.Id, null);
    } catch (AuraHandledException ex) {
      failed = true;
    }
    System.assert(failed, 'An invalid plan must return a controlled error.');
  }

  @IsTest
  static void upgradeOptionsAndRenewalUseResolvedMember() {
    Membership_Plan__c currentPlan = new Membership_Plan__c(
      Name = 'Renewal Current',
      Active__c = true,
      Duration_Days__c = 30,
      Borrow_Limit__c = 2,
      Loan_Duration_Days__c = 7,
      Reservation_Limit__c = 1,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5,
      Fee__c = 100
    );
    Membership_Plan__c upgradePlan = new Membership_Plan__c(
      Name = 'Renewal Upgrade',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 2,
      Fine_Per_Day__c = 2,
      Fee__c = 500
    );
    insert new List<Membership_Plan__c>{ currentPlan, upgradePlan };
    Account account = new Account(Name = 'Renewal Test Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Renewal',
      LastName = 'Member',
      Email = 'renewal-' + DateTime.now().getTime() + '@example.com',
      AccountId = account.Id
    );
    insert contact;
    Date existingEnd = Date.today().addDays(10);
    Member__c member = new Member__c(
      First_Name__c = 'Renewal',
      Last_Name__c = 'Member',
      Email__c = contact.Email,
      Contact__c = contact.Id,
      Membership_Plan__c = currentPlan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = existingEnd,
      Max_Borrow_Limit__c = 2,
      Status__c = 'Active'
    );
    insert member;

    Test.startTest();
    List<LibraryMembershipPaymentService.UpgradePlan> options = LibraryMembershipPaymentService.getUpgradePlans(
      member.Id
    );
    Id paymentId = LibraryMembershipPaymentService.renewMembership(member.Id);
    Test.stopTest();

    System.assertEquals(1, options.size());
    System.assertEquals(upgradePlan.Id, options[0].id);
    System.assertEquals(
      existingEnd.addDays(30),
      [SELECT Membership_End_Date__c FROM Member__c WHERE Id = :member.Id]
      .Membership_End_Date__c
    );
    System.assertEquals(
      'Paid',
      [SELECT Status__c FROM Membership_Payment__c WHERE Id = :paymentId]
      .Status__c
    );
  }
}
