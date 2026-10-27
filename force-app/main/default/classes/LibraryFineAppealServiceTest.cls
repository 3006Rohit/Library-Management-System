@IsTest
private class LibraryFineAppealServiceTest {
  @IsTest
  static void memberSubmitsIdempotentAppealAndLibrarianDecides() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Fines');
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Appeal Plan',
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
      First_Name__c = 'Appeal',
      Last_Name__c = 'Member',
      Email__c = 'appeal-member@example.com',
      Normalized_Email__c = 'appeal-member@example.com',
      External_Auth_Id__c = 'appeal-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Fine__c fine = new Fine__c(
      Member__c = member.Id,
      Fine_Type__c = 'Late Return',
      Amount__c = 25,
      Paid_Amount__c = 0,
      Status__c = 'Unpaid',
      Generated_Date__c = Date.today()
    );
    insert fine;
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'appeal-test'
    );
    LibraryFineAppealService.AppealDTO first = LibraryFineAppealService.submit(
      token,
      fine.Id,
      'The item was returned before the due date.'
    );
    LibraryFineAppealService.AppealDTO second = LibraryFineAppealService.submit(
      token,
      fine.Id,
      'A different reason that should remain idempotent.'
    );
    System.assertEquals(first.id, second.id);
    System.assertEquals('Pending', first.status);
    LibraryFineAppealService.decide(
      first.id,
      'Rejected',
      'The return timestamp confirms the charge.'
    );
    System.assertEquals(
      'Rejected',
      LibraryFineAppealService.getMine(token)[0].status
    );
  }
}
