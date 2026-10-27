@IsTest
private class LibraryRiskInsightServiceTest {
  @IsTest
  static void scansExplainableWaiverPatternAndSupportsReview() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Registrations'
    );
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Risk Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 10,
      Fee__c = 10
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Risk',
      Last_Name__c = 'Review',
      Email__c = 'risk-review@example.com',
      Normalized_Email__c = 'risk-review@example.com',
      External_Auth_Id__c = 'risk-review',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 5
    );
    insert member;
    List<Fine__c> fines = new List<Fine__c>();
    for (Integer i = 0; i < 3; i++) {
      fines.add(
        new Fine__c(
          Member__c = member.Id,
          Fine_Type__c = 'Other',
          Amount__c = 10,
          Paid_Amount__c = 0,
          Status__c = 'Waived',
          Generated_Date__c = Date.today()
        )
      );
    }
    insert fines;
    Test.startTest();
    LibraryRiskInsightService.RunDTO first = LibraryRiskInsightService.scan();
    LibraryRiskInsightService.RunDTO second = LibraryRiskInsightService.scan();
    Test.stopTest();
    System.assertEquals(1, first.created);
    System.assertEquals(1, second.existing);
    List<LibraryRiskInsightService.AlertDTO> alerts = LibraryRiskInsightService.getAll(
      'Open'
    );
    System.assertEquals(1, alerts.size());
    System.assertEquals('Frequent Fine Waivers', alerts[0].category);
    System.assertEquals(3, alerts[0].score / 20);
    LibraryRiskInsightService.decide(
      alerts[0].id,
      'False Positive',
      'Reviewed and explained by the finance librarian.'
    );
    System.assertEquals(
      1,
      LibraryRiskInsightService.getAll('False Positive').size()
    );
  }
}
