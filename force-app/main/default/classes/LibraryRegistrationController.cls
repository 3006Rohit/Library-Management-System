public with sharing class LibraryRegistrationController {
  public class RegistrationInput {
    @AuraEnabled
    public String firstName { get; set; }
    @AuraEnabled
    public String lastName { get; set; }
    @AuraEnabled
    public String email { get; set; }
    @AuraEnabled
    public String phone { get; set; }
    @AuraEnabled
    public Date dateOfBirth { get; set; }
    @AuraEnabled
    public String address { get; set; }
    @AuraEnabled
    public String interests { get; set; }
    @AuraEnabled
    public Id requestedPlanId { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static List<Membership_Plan__c> getActivePlans() {
    return [
      SELECT Id, Name, Description__c, Duration_Days__c, Borrow_Limit__c
      FROM Membership_Plan__c
      WHERE Active__c = TRUE
      ORDER BY Name
    ];
  }

  @AuraEnabled
  public static String submitRegistration(RegistrationInput input) {
    return LibraryRegistrationService.submit(input);
  }

  @AuraEnabled(cacheable=true)
  public static List<Library_Registration__c> getRegistrations() {
    LibraryRegistrationService.requireLibrarian();
    return [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Phone__c,
        Date_of_Birth__c,
        Address__c,
        Interests__c,
        Requested_Plan__c,
        Requested_Plan__r.Name,
        Registration_Date__c,
        Status__c,
        Normalized_Email__c,
        Provisioning_Status__c,
        Provisioning_Error__c,
        Provisioned_User__c,
        Created_Contact__c,
        Created_Member__c
      FROM Library_Registration__c
      ORDER BY Registration_Date__c DESC
      LIMIT 200
    ];
  }

  @AuraEnabled
  public static void approveRegistration(Id registrationId) {
    LibraryRegistrationService.approve(registrationId);
  }

  @AuraEnabled
  public static void rejectRegistration(Id registrationId, String reason) {
    LibraryRegistrationService.reject(registrationId, reason);
  }

  @AuraEnabled
  public static void retryProvisioning(Id registrationId) {
    LibraryRegistrationService.retry(registrationId);
  }

  @AuraEnabled(cacheable=true)
  public static Library_Registration__c getRegistrationForReview(
    Id registrationId
  ) {
    LibraryRegistrationService.requireLibrarian();
    return [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Phone__c,
        Date_of_Birth__c,
        Address__c,
        Interests__c,
        Requested_Plan__c,
        Requested_Plan__r.Name,
        Registration_Date__c,
        Status__c,
        Approved_By__c,
        Approved_By__r.Name,
        Approved_Date__c,
        Rejection_Reason__c,
        Created_Contact__c,
        Created_Contact__r.Name,
        Created_Member__c,
        Created_Member__r.Name,
        Normalized_Email__c,
        Provisioning_Status__c,
        Provisioning_Error__c,
        Provisioned_User__c
      FROM Library_Registration__c
      WHERE Id = :registrationId
      LIMIT 1
    ];
  }
}
