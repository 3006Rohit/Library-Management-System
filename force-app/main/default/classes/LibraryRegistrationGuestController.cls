public with sharing class LibraryRegistrationGuestController {
    @AuraEnabled(cacheable=true)
    public static List<Membership_Plan__c> getActivePlans() {
        return [SELECT Id, Name, Description__c, Duration_Days__c, Borrow_Limit__c
                FROM Membership_Plan__c WHERE Active__c = true ORDER BY Name];
    }

    @AuraEnabled
    public static String submitRegistration(LibraryRegistrationController.RegistrationInput input) {
        return LibraryRegistrationService.submitGuest(input);
    }
}
