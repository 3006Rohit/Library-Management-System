global with sharing class LibraryPublicMembershipPlansAction {
  global class Request {
    @InvocableVariable(label='Optional topic (unused)')
    public String topic;
  }
  global class PlanResult {
    @InvocableVariable
    public String planName;
    @InvocableVariable
    public Decimal fee;
    @InvocableVariable
    public Decimal durationDays;
    @InvocableVariable
    public Decimal borrowLimit;
    @InvocableVariable
    public Decimal loanDurationDays;
    @InvocableVariable
    public String joiningSteps;
    @InvocableVariable
    public String message;
  }

  private static final String JOINING_STEPS = 'Choose a plan, then register through the sign-up page of the library member portal. A librarian can help if you need assistance.';

  @InvocableMethod(
    label='Get Membership Plans'
    description='Use for public questions about membership plans, fees, durations, benefits and how to join. Returns plan catalog data only; never returns member records.'
  )
  global static List<PlanResult> execute(List<Request> requests) {
    try {
      List<PlanResult> output = new List<PlanResult>();
      for (Membership_Plan__c plan : [
        SELECT
          Name,
          Fee__c,
          Duration_Days__c,
          Borrow_Limit__c,
          Loan_Duration_Days__c
        FROM Membership_Plan__c
        WHERE Active__c = TRUE
        WITH SYSTEM_MODE
        ORDER BY Fee__c ASC, Name ASC
        LIMIT 20
      ]) {
        PlanResult result = new PlanResult();
        result.planName = plan.Name;
        result.fee = plan.Fee__c;
        result.durationDays = plan.Duration_Days__c;
        result.borrowLimit = plan.Borrow_Limit__c;
        result.loanDurationDays = plan.Loan_Duration_Days__c;
        result.joiningSteps = JOINING_STEPS;
        output.add(result);
      }
      if (output.isEmpty())
        output.add(
          messageOnly(
            'No membership plans are published right now; please contact the library desk.'
          )
        );
      return output;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_PUBLIC_PLANS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
      return new List<PlanResult>{
        messageOnly('Membership information is temporarily unavailable.')
      };
    }
  }

  private static PlanResult messageOnly(String message) {
    PlanResult result = new PlanResult();
    result.message = message;
    return result;
  }
}
