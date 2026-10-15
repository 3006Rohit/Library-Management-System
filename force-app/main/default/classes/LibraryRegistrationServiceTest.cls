@IsTest
private class LibraryRegistrationServiceTest {
    @TestSetup static void setupData() {
        insert new Membership_Plan__c(Name='Test Plan', Active__c=true, Duration_Days__c=30, Borrow_Limit__c=5);
    }
    @IsTest static void validSubmissionAndNormalizedDuplicate() {
        Membership_Plan__c plan=[SELECT Id FROM Membership_Plan__c LIMIT 1]; LibraryRegistrationController.RegistrationInput input=new LibraryRegistrationController.RegistrationInput();
        input.firstName='Test'; input.lastName='Member'; input.email='  Test.Member@example.com '; input.phone='+91 9876543210'; input.requestedPlanId=plan.Id;
        Test.startTest(); String id=LibraryRegistrationService.submit(input); Test.stopTest();
        Library_Registration__c r=[SELECT Email__c, Normalized_Email__c, Provisioning_Status__c, Status__c FROM Library_Registration__c WHERE Id=:id];
        System.assertEquals('test.member@example.com',r.Email__c); System.assertEquals('test.member@example.com', r.Normalized_Email__c); System.assertEquals('Not Started', r.Provisioning_Status__c); System.assertEquals('Pending',r.Status__c);
        input.email='TEST.MEMBER@EXAMPLE.COM'; try { LibraryRegistrationService.submit(input); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
    }
    @IsTest static void invalidInputAndInactivePlan() {
        LibraryRegistrationController.RegistrationInput input=new LibraryRegistrationController.RegistrationInput(); input.firstName='A'; input.lastName='B'; input.email='bad';
        try { LibraryRegistrationService.submit(input); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        Membership_Plan__c plan=[SELECT Id FROM Membership_Plan__c LIMIT 1]; plan.Active__c=false; update plan; input.email='valid@example.com'; input.requestedPlanId=plan.Id;
        try { LibraryRegistrationService.submit(input); System.assert(false); } catch (Exception e) { System.assert(true); }
    }
}
