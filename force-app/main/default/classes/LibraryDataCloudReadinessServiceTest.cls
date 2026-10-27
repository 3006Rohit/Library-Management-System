@IsTest
private class LibraryDataCloudReadinessServiceTest {
  @IsTest
  static void reportsProductionIsolationAndEmailWarnings() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Data Cloud Readiness Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert plan;
    insert new List<Member__c>{
      new Member__c(
        First_Name__c = 'Production',
        Last_Name__c = 'Ready',
        Email__c = 'readiness@example.com',
        Normalized_Email__c = 'readiness@example.com',
        External_Auth_Id__c = 'readiness-production',
        Status__c = 'Active',
        Account_Status__c = 'Active',
        Member_Type__c = 'Production',
        Membership_Plan__c = plan.Id,
        Membership_Start_Date__c = Date.today(),
        Membership_End_Date__c = Date.today().addDays(365),
        Max_Borrow_Limit__c = 3
      ),
      new Member__c(
        First_Name__c = 'Demo',
        Last_Name__c = 'Member',
        Email__c = 'demo@example.com',
        Normalized_Email__c = 'demo@example.com',
        External_Auth_Id__c = 'readiness-demo',
        Status__c = 'Active',
        Account_Status__c = 'Active',
        Member_Type__c = 'Demo',
        Membership_Plan__c = plan.Id,
        Membership_Start_Date__c = Date.today(),
        Membership_End_Date__c = Date.today().addDays(365),
        Max_Borrow_Limit__c = 3
      )
    };

    Test.startTest();
    LibraryDataCloudReadinessService.StatusDTO status = LibraryDataCloudReadinessService.getStatus();
    Test.stopTest();

    System.assertEquals(2, status.totalMembers);
    System.assertEquals(1, status.productionMembers);
    System.assertEquals(0, status.unclassifiedMembers);
    System.assertEquals(0, status.nonProductionLoans);
    System.assertEquals(0, status.nonProductionReservations);
    System.assertEquals(0, status.nonProductionFines);
    System.assertEquals(0, status.orphanLoans);
    System.assertEquals(0, status.orphanReservations);
    System.assertEquals(0, status.orphanFines);
    System.assertEquals(0, status.productionLoans);
    System.assertEquals(0, status.productionReservations);
    System.assertEquals(0, status.productionFines);
    System.assertEquals('2026-10-17-v1', status.handoffVersion);
    System.assertEquals(
      'Member_Type__c = Production',
      status.productionMemberFilter
    );
    System.assertEquals(
      'Member__r.Member_Type__c = Production',
      status.productionChildFilter
    );
    System.assert(status.governedSources.contains('Borrow_Record__c'));
    System.assert(status.deferredSources.contains('Member_Session__c'));
    System.assertEquals(
      'Ready for setup review',
      status.calculatedInsightStatus
    );
    System.assertEquals(5, status.calculatedInsights.size());
    System.assertEquals('Active loan count', status.calculatedInsights[0].name);
    System.assertEquals(
      'Ready for setup review',
      status.calculatedInsights[0].status
    );
    System.assertEquals(true, status.ready);
    System.assertEquals(1, status.productionMembersMissingEmail);
    System.assertEquals('Ready with warnings', status.status);
    System.assertEquals(false, status.warnings.isEmpty());
  }

  @IsTest
  static void reportsOrphanedInsightRelationshipsAsBlockers() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    Book__c book = new Book__c(
      Name = 'Readiness Orphan Book',
      ISBN__c = 'READINESS-ORPHAN',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 0
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'READINESS-ORPHAN-COPY',
      Status__c = 'Borrowed',
      Condition__c = 'Good'
    );
    insert copy;
    insert new Borrow_Record__c(
      Book_Copy__c = copy.Id,
      Borrow_Date__c = System.now().addDays(-2),
      Due_Date__c = System.now().addDays(12),
      Status__c = 'Active',
      Renewal_Count__c = 0
    );
    insert new Reservation__c(
      Book__c = book.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 1
    );
    insert new Fine__c(
      Fine_Type__c = 'Other',
      Amount__c = 10,
      Paid_Amount__c = 0,
      Status__c = 'Unpaid',
      Generated_Date__c = Date.today()
    );

    Test.startTest();
    LibraryDataCloudReadinessService.StatusDTO status = LibraryDataCloudReadinessService.getStatus();
    Test.stopTest();

    System.assertEquals(1, status.orphanLoans);
    System.assertEquals(1, status.orphanReservations);
    System.assertEquals(1, status.orphanFines);
    System.assertEquals(false, status.ready);
    System.assertEquals('Blocked', status.status);
    System.assertEquals(4, status.blockers.size());
    System.assertEquals(
      'Blocked by source quality',
      status.calculatedInsightStatus
    );
    System.assertEquals(5, status.calculatedInsights.size());
    System.assertEquals(
      'Blocked by source quality',
      status.calculatedInsights[0].status
    );
  }
}
