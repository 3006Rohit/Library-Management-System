@IsTest
private class LibraryAgentApiControllerTest {
  private static String startEndpoint;

  private class AgentApiMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(request.getMethod() == 'DELETE' ? 204 : 200);
      if (
        request.getMethod() == 'POST' &&
        request.getEndpoint().contains('/agents/')
      ) {
        LibraryAgentApiControllerTest.startEndpoint = request.getEndpoint();
        response.setBody('{"sessionId":"session-1"}');
      } else if (request.getMethod() == 'POST') {
        response.setBody(
          '{"messages":[{"type":"Inform","message":"There are 350 copies available."}]}'
        );
      }
      return response;
    }
  }

  @IsTest
  static void startsSendsAndEndsSession() {
    Test.setMock(HttpCalloutMock.class, new AgentApiMock());
    Test.startTest();
    LibraryAgentApiController.SessionResponse session = LibraryAgentApiController.startSession();
    LibraryAgentApiController.MessageResponse message = LibraryAgentApiController.sendMessage(
      session.sessionId,
      1,
      'How many copies are available?'
    );
    LibraryAgentApiController.endSession(session.sessionId);
    Test.stopTest();

    System.assertEquals('session-1', session.sessionId);
    System.assert(
      startEndpoint.contains('0XxgK000002QwOz'),
      'The workspace must use the activated librarian Agentforce agent.'
    );
    System.assertEquals('There are 350 copies available.', message.message);
    System.assertEquals('Inform', message.messageType);
  }

  @IsTest
  static void rejectsInvalidMessage() {
    Boolean rejected = false;
    try {
      LibraryAgentApiController.sendMessage(null, 0, '');
    } catch (AuraHandledException ex) {
      rejected = true;
    }
    System.assert(rejected, 'Expected an invalid-session error.');
  }
}
