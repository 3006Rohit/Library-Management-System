global with sharing class LibraryAgentMyLoansAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
  }
  global class LoanResult {
    @InvocableVariable
    public String loanId;
    @InvocableVariable
    public String bookTitle;
    @InvocableVariable
    public Datetime borrowDate;
    @InvocableVariable
    public Datetime dueDate;
    @InvocableVariable
    public Datetime returnDate;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public Decimal renewalCount;
  }

  @InvocableMethod(
    label='Get My Loans'
    description='Use only when the currently authenticated member asks about their own loans. Invoke this action before answering; identity is derived from the server-validated session token and never accepts a Member ID.'
  )
  global static List<LoanResult> execute(List<Request> requests) {
    String token = requests == null || requests.isEmpty()
      ? null
      : requests[0].sessionToken;
    List<LoanResult> output = new List<LoanResult>();
    for (
      LibraryMemberSessionController.LoanDTO loan : LibraryMemberSessionController.getMyBorrowings(
        token
      )
    ) {
      LoanResult result = new LoanResult();
      result.loanId = String.valueOf(loan.id);
      result.bookTitle = loan.bookTitle;
      result.borrowDate = loan.borrowDate;
      result.dueDate = loan.dueDate;
      result.returnDate = loan.returnDate;
      result.status = loan.status;
      result.renewalCount = loan.renewalCount;
      output.add(result);
    }
    return output;
  }
}
