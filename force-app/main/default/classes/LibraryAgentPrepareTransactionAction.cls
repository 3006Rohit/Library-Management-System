global with sharing class LibraryAgentPrepareTransactionAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
    @InvocableVariable(required=true)
    global String action;
    @InvocableVariable(required=false)
    global String targetName;
    @InvocableVariable(required=false)
    global String targetId;
    @InvocableVariable(required=false)
    global Integer seatNumber;
    @InvocableVariable(required=false)
    global String startTime;
    @InvocableVariable(required=false)
    global Integer durationHours;
    @InvocableVariable(required=false)
    global String purpose;
  }

  global class Response {
    @InvocableVariable
    global Boolean prepared;
    @InvocableVariable
    global String confirmationToken;
    @InvocableVariable
    global String preview;
    @InvocableVariable
    global String message;
  }

  @InvocableMethod(
    label='Prepare Member Transaction'
    description='Step 1 of 2. Checks a borrow request, reservation or study room seat booking for the authenticated member and returns a plain-language preview plus a single-use confirmation token. Writes nothing; the member must confirm before the commit action is called.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      if (requests == null || requests.isEmpty())
        throw new AuraHandledException('A request is required.');
      Request input = requests[0];
      LibraryAgentConfirmationService.PreviewRequest request = new LibraryAgentConfirmationService.PreviewRequest();
      request.sessionToken = input.sessionToken;
      request.action = input.action;
      request.targetName = input.targetName;
      request.targetId = String.isBlank(input.targetId)
        ? null
        : (Id) input.targetId;
      request.seatNumber = input.seatNumber;
      request.startTime = input.startTime;
      request.durationHours = input.durationHours;
      request.purpose = input.purpose;
      LibraryAgentConfirmationService.PreviewDTO preview = LibraryAgentConfirmationService.preview(
        request
      );
      output.prepared = true;
      output.confirmationToken = preview.token;
      output.preview = preview.preview;
      output.message = 'Nothing has been done yet. Ask the member to confirm, then commit.';
    } catch (Exception error) {
      output.prepared = false;
      String text = error.getMessage();
      output.message = String.isBlank(text) || text == 'Script-thrown exception'
        ? 'That could not be prepared right now.'
        : text;
    }
    return new List<Response>{ output };
  }
}
