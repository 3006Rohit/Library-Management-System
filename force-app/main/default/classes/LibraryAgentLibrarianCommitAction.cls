global with sharing class LibraryAgentLibrarianCommitAction {
  global class Request {
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
    label='Commit Confirmed Librarian Change'
    description='Step 2 of 2. Carries out the librarian change that was prepared earlier. Call only after the librarian has explicitly said yes in their own message. It confirms the most recent prepared change for the signed-in librarian, so no code needs to be passed.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      LibraryAgentLibrarianWriteService.CommitResult result = LibraryAgentLibrarianWriteService.commitChange(
        requests == null || requests.isEmpty()
          ? null
          : requests[0].confirmationToken
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
