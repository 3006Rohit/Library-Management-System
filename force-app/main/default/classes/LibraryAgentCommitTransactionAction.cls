global with sharing class LibraryAgentCommitTransactionAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
    @InvocableVariable(required=false)
    global String confirmationToken;
  }

  global class Response {
    @InvocableVariable
    global Boolean committed;
    @InvocableVariable
    global String resultRecordId;
    @InvocableVariable
    global String message;
  }

  @InvocableMethod(
    label='Commit Confirmed Member Transaction'
    description='Step 2 of 2. Carries out a transaction that was prepared earlier. Call only after the member has explicitly said yes in their own message. It confirms the most recent prepared request for the authenticated member, so no code needs to be passed.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      if (requests == null || requests.isEmpty())
        throw new AuraHandledException('A request is required.');
      LibraryAgentConfirmationService.CommitResult result = LibraryAgentConfirmationService.commitConfirmed(
        requests[0].sessionToken,
        requests[0].confirmationToken
      );
      output.committed = true;
      output.resultRecordId = String.valueOf(result.recordId);
      output.message = result.message;
    } catch (Exception error) {
      output.committed = false;
      String text = error.getMessage();
      output.message = String.isBlank(text) || text == 'Script-thrown exception'
        ? 'That could not be completed right now. Prepare it again.'
        : text;
    }
    return new List<Response>{ output };
  }
}
