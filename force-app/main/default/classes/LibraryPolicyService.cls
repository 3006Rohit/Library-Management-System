public with sharing class LibraryPolicyService {
  @TestVisible
  private static Set<String> testGrantedPermissions = new Set<String>();
  public class PolicyResult {
    @AuraEnabled
    public Boolean allowed { get; set; }
    @AuraEnabled
    public String message { get; set; }
    public PolicyResult(Boolean allowed, String message) {
      this.allowed = allowed;
      this.message = message;
    }
  }

  public static void require(String permission) {
    Boolean authorized = Test.isRunningTest()
      ? testGrantedPermissions.contains(permission)
      : FeatureManagement.checkPermission(permission);
    if (!authorized)
      throw new AuraHandledException(
        'You are not authorized to perform this library operation.'
      );
  }

  public static PolicyResult canBorrow(
    Member__c member,
    Membership_Plan__c plan,
    Integer activeLoans,
    Decimal outstandingFine,
    Book_Copy__c copy,
    Reservation__c blockingReservation
  ) {
    if (member == null)
      return new PolicyResult(false, 'Member was not found.');
    if (member.Status__c != 'Active')
      return new PolicyResult(false, 'Member is not Active.');
    if (
      member.Membership_End_Date__c == null ||
      member.Membership_End_Date__c < Date.today()
    )
      return new PolicyResult(false, 'Membership has expired.');
    if (plan == null || plan.Active__c != true)
      return new PolicyResult(false, 'Member membership plan is not active.');
    if (
      plan.Borrow_Limit__c == null ||
      activeLoans >= Integer.valueOf(plan.Borrow_Limit__c)
    )
      return new PolicyResult(false, 'Member has reached the borrowing limit.');
    if (outstandingFine != null && outstandingFine > 0)
      return new PolicyResult(false, 'Outstanding fines prevent checkout.');
    Boolean reservedForMember =
      blockingReservation != null &&
      blockingReservation.Status__c == 'Ready' &&
      blockingReservation.Member__c == member.Id &&
      blockingReservation.Book_Copy__c == copy.Id;
    if (copy == null || (copy.Status__c != 'Available' && !reservedForMember))
      return new PolicyResult(false, 'Book copy is not Available.');
    if (
      blockingReservation != null &&
      blockingReservation.Status__c == 'Ready' &&
      blockingReservation.Member__c != member.Id
    )
      return new PolicyResult(
        false,
        'Book copy is reserved for another member.'
      );
    if (plan.Loan_Duration_Days__c == null || plan.Loan_Duration_Days__c <= 0)
      return new PolicyResult(
        false,
        'Membership plan has no valid loan duration.'
      );
    return new PolicyResult(true, null);
  }

  public static Integer holdDurationDays() {
    Library_Experience_Config__mdt config = Library_Experience_Config__mdt.getInstance(
      'Default'
    );
    return config == null ||
      config.Hold_Duration_Days__c == null
      ? 3
      : Integer.valueOf(config.Hold_Duration_Days__c);
  }
}
