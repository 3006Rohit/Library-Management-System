global with sharing class LibraryAgentLibrarianPrepareAction {
  global class Request {
    @InvocableVariable(required=true)
    global String action;
    @InvocableVariable(required=false)
    global String memberLookup;
    @InvocableVariable(required=false)
    global String bookLookup;
    @InvocableVariable(required=false)
    global String loanId;
    @InvocableVariable(required=false)
    global String firstName;
    @InvocableVariable(required=false)
    global String lastName;
    @InvocableVariable(required=false)
    global String email;
    @InvocableVariable(required=false)
    global String phone;
    @InvocableVariable(required=false)
    global String title;
    @InvocableVariable(required=false)
    global String publisher;
    @InvocableVariable(required=false)
    global String edition;
    @InvocableVariable(required=false)
    global String language;
    @InvocableVariable(required=false)
    global String description;
  }

  global class Response {
    @InvocableVariable
    global Boolean prepared;
    @InvocableVariable
    global String preview;
    @InvocableVariable
    global String message;
  }

  @InvocableMethod(
    label='Prepare Librarian Change'
    description='Step 1 of 2. Checks a librarian change (edit a member or book, check a book out to a member, reserve a book for a member, or approve a pending borrowing request) and returns a plain-language preview. Writes nothing; the librarian must confirm before the commit action is called.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      if (requests == null || requests.isEmpty())
        throw new AuraHandledException('A request is required.');
      Request input = requests[0];
      LibraryAgentLibrarianWriteService.WriteRequest request = new LibraryAgentLibrarianWriteService.WriteRequest();
      request.action = input.action;
      request.memberLookup = input.memberLookup;
      request.bookLookup = input.bookLookup;
      request.loanId = input.loanId;
      request.firstName = input.firstName;
      request.lastName = input.lastName;
      request.email = input.email;
      request.phone = input.phone;
      request.title = input.title;
      request.publisher = input.publisher;
      request.edition = input.edition;
      request.language = input.language;
      request.description = input.description;
      LibraryAgentLibrarianWriteService.PreviewResult preview = LibraryAgentLibrarianWriteService.prepare(
        request
      );
      output.prepared = true;
      output.preview = preview.preview;
      output.message = 'Nothing has been changed yet. Ask the librarian to confirm, then commit.';
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
