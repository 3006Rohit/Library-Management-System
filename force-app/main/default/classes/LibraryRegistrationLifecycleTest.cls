@IsTest
private class LibraryRegistrationLifecycleTest {
  @IsTest
  static void runtimeFieldsAndSubmissionStateAreCorrect() {
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Lifecycle Plan');
    LibraryRegistrationController.RegistrationInput input = new LibraryRegistrationController.RegistrationInput();
    input.firstName = ' Test ';
    input.lastName = ' Member ';
    input.email = '  LIFECYCLE@example.com  ';
    input.requestedPlanId = plan.Id;

    String id = LibraryRegistrationService.submit(input);
    Library_Registration__c value = [
      SELECT Registration_Email_Key__c, Provisioning_State__c, Status__c
      FROM Library_Registration__c
      WHERE Id = :id
    ];
    System.assertEquals(
      'lifecycle@example.com',
      value.Registration_Email_Key__c
    );
    System.assertEquals('Not Started', value.Provisioning_State__c);
    System.assertEquals('Pending', value.Status__c);
    System.assertEquals(
      true,
      Schema.getGlobalDescribe()
        .get('Library_Registration__c')
        .getDescribe()
        .fields.getMap()
        .containsKey('External_User__c')
    );
  }

  @IsTest
  static void missingSharedAccountFailsSafely() {
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Failure Plan');
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'missing-account@example.com',
      'Queued'
    );
    Test.startTest();
    System.enqueueJob(new LibraryRegistrationProvisioningQueueable(value.Id));
    Test.stopTest();

    value = [
      SELECT Provisioning_State__c, Provisioning_Message__c
      FROM Library_Registration__c
      WHERE Id = :value.Id
    ];
    System.assertEquals('Failed', value.Provisioning_State__c);
    System.assert(
      value.Provisioning_Message__c.contains('Contact library administration')
    );
    System.assertEquals(
      false,
      value.Provisioning_Message__c.contains('Class.')
    );
  }

  @IsTest
  static void finalizationIsIdempotentAndCompletesRegistration() {
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Finalize Plan');
    Account account = LibraryTestDataFactory.communityAccount();
    Contact contact = LibraryTestDataFactory.contact(
      account,
      'finalize@example.com'
    );
    Member__c member = LibraryTestDataFactory.member(
      contact,
      plan,
      'finalize@example.com'
    );
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'finalize@example.com',
      'Processing'
    );
    value.Created_Contact__c = contact.Id;
    value.Created_Member__c = member.Id;
    update value;

    Test.startTest();
    System.enqueueJob(
      new LibraryRegistrationFinalizeQueueable(
        value.Id,
        member.Id,
        UserInfo.getUserId()
      )
    );
    Test.stopTest();
    value = [
      SELECT
        Status__c,
        Provisioning_State__c,
        Provisioning_Message__c,
        External_User__c,
        Created_Contact__c,
        Created_Member__c
      FROM Library_Registration__c
      WHERE Id = :value.Id
    ];
    System.assertEquals('Approved', value.Status__c);
    System.assertEquals('Completed', value.Provisioning_State__c);
    System.assertEquals(null, value.Provisioning_Message__c);
    System.assertEquals(UserInfo.getUserId(), value.External_User__c);
    System.assertEquals(contact.Id, value.Created_Contact__c);
    System.assertEquals(member.Id, value.Created_Member__c);
  }

  @IsTest
  static void retryOnlyAllowsFailedState() {
    LibraryRegistrationService.testLibrarianAuthorized = true;
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Retry Plan');
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'retry@example.com',
      'Not Started'
    );
    try {
      LibraryRegistrationService.retry(value.Id);
      System.assert(false, 'Retry should require Failed state.');
    } catch (AuraHandledException expected) {
      System.assertEquals(
        'Not Started',
        [
          SELECT Provisioning_State__c
          FROM Library_Registration__c
          WHERE Id = :value.Id
        ]
        .Provisioning_State__c
      );
    }
  }

  @IsTest
  static void controllerAndGuestSurfacesUseCanonicalFields() {
    LibraryRegistrationService.testLibrarianAuthorized = true;
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Controller Plan');
    LibraryRegistrationController.RegistrationInput input = new LibraryRegistrationController.RegistrationInput();
    input.firstName = 'Controller';
    input.lastName = 'Member';
    input.email = 'controller@example.com';
    input.requestedPlanId = plan.Id;
    System.assertEquals(
      1,
      LibraryRegistrationGuestController.getActivePlans().size()
    );
    String id = LibraryRegistrationGuestController.submitRegistration(input);
    System.assertEquals(
      false,
      LibraryRegistrationController.getRegistrations().isEmpty()
    );
    Library_Registration__c review = LibraryRegistrationController.getRegistrationForReview(
      id
    );
    System.assertEquals('Not Started', review.Provisioning_State__c);
    System.assertEquals(
      'controller@example.com',
      review.Registration_Email_Key__c
    );
  }

  @IsTest
  static void guestCatalogReturnsActiveBooksAndSupportsSearch() {
    insert new List<Book__c>{
      new Book__c(
        Name = 'Public Catalog Book',
        ISBN__c = 'PUBLIC-ISBN',
        Publisher__c = 'Library Press',
        Status__c = 'Active',
        Total_Copies__c = 3,
        Available_Copies__c = 2
      ),
      new Book__c(
        Name = 'Hidden Catalog Book',
        ISBN__c = 'HIDDEN-ISBN',
        Status__c = 'Inactive',
        Total_Copies__c = 1,
        Available_Copies__c = 1
      )
    };
    List<LibraryRegistrationGuestController.CatalogBook> books = LibraryRegistrationGuestController.searchPublicCatalog(
      'PUBLIC-ISBN'
    );
    System.assertEquals(1, books.size());
    System.assertEquals('Public Catalog Book', books[0].title);
    System.assertEquals(2, books[0].availableCopies);
    System.assertEquals(
      1,
      LibraryRegistrationGuestController.searchPublicCatalog(null).size()
    );
  }

  @IsTest
  static void approvalAndRejectionFollowStateRules() {
    LibraryRegistrationService.testLibrarianAuthorized = true;
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Decision Plan');
    Library_Registration__c approved = LibraryTestDataFactory.registration(
      plan,
      'approved@example.com',
      'Not Started'
    );
    Test.startTest();
    LibraryRegistrationController.approveRegistration(approved.Id);
    Test.stopTest();
    approved = [
      SELECT Status__c, Provisioning_State__c
      FROM Library_Registration__c
      WHERE Id = :approved.Id
    ];
    System.assertEquals('Approved', approved.Status__c);
    System.assertEquals('Completed', approved.Provisioning_State__c);

    Library_Registration__c rejected = LibraryTestDataFactory.registration(
      plan,
      'rejected@example.com',
      'Not Started'
    );
    LibraryRegistrationController.rejectRegistration(
      rejected.Id,
      'Duplicate application'
    );
    rejected = [
      SELECT Status__c, Provisioning_State__c, Rejection_Reason__c
      FROM Library_Registration__c
      WHERE Id = :rejected.Id
    ];
    System.assertEquals('Rejected', rejected.Status__c);
    System.assertEquals('Not Started', rejected.Provisioning_State__c);
    System.assertEquals('Duplicate application', rejected.Rejection_Reason__c);
  }

  @IsTest
  static void provisioningReusesExistingContactAndMember() {
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Reuse Plan');
    Account account = LibraryTestDataFactory.communityAccount();
    Contact contact = LibraryTestDataFactory.contact(
      account,
      'reuse@example.com'
    );
    Member__c member = LibraryTestDataFactory.member(
      contact,
      plan,
      'reuse@example.com'
    );
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'reuse@example.com',
      'Queued'
    );
    value.Approved_Date__c = System.now();
    value.Approved_By__c = UserInfo.getUserId();
    update value;
    Test.startTest();
    System.enqueueJob(new LibraryRegistrationProvisioningQueueable(value.Id));
    Test.stopTest();
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Contact WHERE Id = :contact.Id]
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Member__c WHERE Id = :member.Id]
    );
    value = [
      SELECT Created_Contact__c, Created_Member__c, Provisioning_State__c
      FROM Library_Registration__c
      WHERE Id = :value.Id
    ];
    System.assertEquals(null, value.Created_Contact__c);
    System.assertEquals(member.Id, value.Created_Member__c);
    System.assertEquals('Completed', value.Provisioning_State__c);
  }

  @IsTest
  static void configurationAndNormalizationHelpersAreSafe() {
    System.assertEquals(
      'sample@example.com',
      LibraryRegistrationService.normalizeEmail('  SAMPLE@example.com ')
    );
    System.assertEquals(null, LibraryRegistrationService.normalizeEmail(null));
    System.assertEquals(
      'Library Community Members',
      LibraryRegistrationService.accountName()
    );
    System.assertEquals(
      'Customer Community User',
      LibraryRegistrationService.profileName()
    );
    System.assertEquals(
      'Library_Member',
      LibraryRegistrationService.permissionSetName()
    );
  }

  @IsTest
  static void failedProvisioningCanBeRetriedSafely() {
    LibraryRegistrationService.testLibrarianAuthorized = true;
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Retryable Plan');
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'retryable@example.com',
      'Failed'
    );
    value.Provisioning_Message__c = 'Previous failure';
    update value;
    Test.startTest();
    LibraryRegistrationController.retryProvisioning(value.Id);
    Test.stopTest();
    value = [
      SELECT Provisioning_State__c, Provisioning_Message__c
      FROM Library_Registration__c
      WHERE Id = :value.Id
    ];
    System.assertEquals('Failed', value.Provisioning_State__c);
    System.assert(
      value.Provisioning_Message__c.contains('Contact library administration')
    );
  }

  @IsTest
  static void completedRegistrationCannotBeApprovedAgain() {
    LibraryRegistrationService.testLibrarianAuthorized = true;
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Completed Plan');
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'completed@example.com',
      'Completed'
    );
    value.Status__c = 'Approved';
    value.Approved_By__c = UserInfo.getUserId();
    value.Approved_Date__c = System.now();
    update value;
    try {
      LibraryRegistrationController.approveRegistration(value.Id);
      System.assert(
        false,
        'Completed registrations must not be approved again.'
      );
    } catch (AuraHandledException expected) {
      System.assertEquals(
        'Approved',
        [SELECT Status__c FROM Library_Registration__c WHERE Id = :value.Id]
        .Status__c
      );
    }
  }

  @IsTest
  static void inputValidationRejectsUnsafeValues() {
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Validation Plan');
    LibraryRegistrationController.RegistrationInput input = new LibraryRegistrationController.RegistrationInput();
    input.firstName = 'Valid';
    input.lastName = 'Member';
    input.email = 'valid@example.com';
    input.requestedPlanId = plan.Id;
    input.phone = 'not-a-phone';
    try {
      LibraryRegistrationService.submit(input);
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    input.phone = null;
    input.dateOfBirth = Date.today().addDays(1);
    try {
      LibraryRegistrationService.submit(input);
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    input.dateOfBirth = null;
    input.firstName = '';
    for (Integer i = 0; i < 81; i++)
      input.firstName += 'x';
    try {
      LibraryRegistrationService.submit(input);
      System.assert(false);
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
  }

  @IsTest
  static void queuedFailureHandlerStoresSafeMessage() {
    Membership_Plan__c plan = LibraryTestDataFactory.plan(
      'Queued Failure Plan'
    );
    Library_Registration__c value = LibraryTestDataFactory.registration(
      plan,
      'queued-failure@example.com',
      'Processing'
    );
    Test.startTest();
    LibraryRegistrationFailureQueueable.record(
      value.Id,
      'internal exception details must not be exposed'
    );
    Test.stopTest();
    value = [
      SELECT Provisioning_State__c, Provisioning_Message__c
      FROM Library_Registration__c
      WHERE Id = :value.Id
    ];
    System.assertEquals('Failed', value.Provisioning_State__c);
    System.assertEquals(
      'Provisioning could not be completed. Contact library administration.',
      value.Provisioning_Message__c
    );
  }
}
