global with sharing class LibraryAgentConfirmationAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
    @InvocableVariable(required=true)
    global String action;
    @InvocableVariable
    global String targetId;
    @InvocableVariable
    global String confirmationToken;
  }
  global class Response {
    @InvocableVariable
    global Boolean requiresConfirmation;
    @InvocableVariable
    global String confirmationToken;
    @InvocableVariable
    global String preview;
    @InvocableVariable
    global String resultRecordId;
    @InvocableVariable
    global String message;
  }
  @InvocableMethod(
    label='Preview or Confirm Member Transaction'
    description='Preview a supported member renewal or reservation cancellation first. Execute only when the member supplies the exact single-use confirmation token returned by the preview.'
  )
  global static List<Response> execute(List<Request> requests) {
    List<Response> output = new List<Response>();
    if (requests == null || requests.isEmpty())
      return output;
    Request request = requests[0];
    Response response = new Response();
    try {
      if (String.isBlank(request.confirmationToken)) {
        LibraryAgentConfirmationService.PreviewDTO preview = LibraryAgentConfirmationService.preview(
          request.sessionToken,
          request.action,
          (Id) request.targetId
        );
        response.requiresConfirmation = true;
        response.confirmationToken = preview.token;
        response.preview = preview.preview;
        response.message = 'Explicit confirmation is required before execution.';
      } else {
        Id resultId = LibraryAgentConfirmationService.confirm(
          request.sessionToken,
          request.confirmationToken
        );
        response.requiresConfirmation = false;
        response.resultRecordId = String.valueOf(resultId);
        response.message = 'The requested transaction was committed.';
      }
    } catch (Exception error) {
      response.requiresConfirmation = false;
      response.message = error.getMessage();
    }
    output.add(response);
    return output;
  }
}
