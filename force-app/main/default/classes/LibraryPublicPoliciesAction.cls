global with sharing class LibraryPublicPoliciesAction {
  global class Request {
    @InvocableVariable(label='Optional topic (unused)')
    public String topic;
  }
  global class PolicyResult {
    @InvocableVariable
    public String planName;
    @InvocableVariable
    public Decimal loanDurationDays;
    @InvocableVariable
    public Decimal borrowLimit;
    @InvocableVariable
    public Decimal renewalLimit;
    @InvocableVariable
    public Decimal reservationLimit;
    @InvocableVariable
    public Decimal finePerDay;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Get Library Policies'
    description='Use for public questions about loan periods, borrowing limits, renewal rules, reservation limits and fine rates. Returns the published rules per membership plan; never returns member, loan or fine records.'
  )
  global static List<PolicyResult> execute(List<Request> requests) {
    try {
      List<PolicyResult> output = new List<PolicyResult>();
      for (Membership_Plan__c plan : [
        SELECT
          Name,
          Loan_Duration_Days__c,
          Borrow_Limit__c,
          Renewal_Limit__c,
          Reservation_Limit__c,
          Fine_Per_Day__c
        FROM Membership_Plan__c
        WHERE Active__c = TRUE
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 20
      ]) {
        PolicyResult result = new PolicyResult();
        result.planName = plan.Name;
        result.loanDurationDays = plan.Loan_Duration_Days__c;
        result.borrowLimit = plan.Borrow_Limit__c;
        result.renewalLimit = plan.Renewal_Limit__c;
        result.reservationLimit = plan.Reservation_Limit__c;
        result.finePerDay = plan.Fine_Per_Day__c;
        output.add(result);
      }
      if (output.isEmpty())
        output.add(
          messageOnly(
            'Library policies are not published yet; please contact the library desk.'
          )
        );
      return output;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_PUBLIC_POLICIES_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
      return new List<PolicyResult>{
        messageOnly('Library policies are temporarily unavailable.')
      };
    }
  }

  private static PolicyResult messageOnly(String message) {
    PolicyResult result = new PolicyResult();
    result.message = message;
    return result;
  }
}
