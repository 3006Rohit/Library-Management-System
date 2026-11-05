@IsTest
private class LibraryPublicAgentControllerTest {
  private static final String SESSION_ID = 'sess-abc-123';

  private static String goodToken() {
    return 'a'.repeat(64);
  }

  private static Library_Public_Chat_Session__c seed() {
    Library_Public_Chat_Session__c row = new Library_Public_Chat_Session__c(
      Session_Id__c = SESSION_ID,
      Token_Hash__c = EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(goodToken()))
      ),
      Message_Count__c = 0
    );
    insert row;
    return row;
  }

  private static void expectSendError(
    String sessionId,
    String token,
    String expectedFragment
  ) {
    try {
      LibraryPublicAgentController.sendMessage(sessionId, token, 1, 'hi');
      System.assert(false, 'Expected an error containing ' + expectedFragment);
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains(expectedFragment),
        'Unexpected message: ' + e.getMessage()
      );
    }
  }

  @IsTest
  static void rejectsMissingUnknownAndWrongTokens() {
    seed();
    expectSendError(SESSION_ID, null, 'invalid');
    expectSendError(SESSION_ID, 'short', 'invalid');
    expectSendError(SESSION_ID, 'b'.repeat(64), 'invalid');
    expectSendError('unknown-session', goodToken(), 'invalid');
    expectSendError(null, goodToken(), 'invalid');
  }

  private class AgentApiMock implements HttpCalloutMock {
    public Integer calls = 0;
    public HTTPResponse respond(HTTPRequest req) {
      calls++;
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        req.getMethod() == 'DELETE'
          ? '{}'
          : '{"messages":[{"type":"Inform","message":"3 of 5 copies available"}]}'
      );
      return res;
    }
  }

  @IsTest
  static void validTokenSendsAndCountsTheMessage() {
    Library_Public_Chat_Session__c row = seed();
    AgentApiMock mock = new AgentApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    LibraryAgentApiController.MessageResponse reply = LibraryPublicAgentController.sendMessage(
      SESSION_ID,
      goodToken(),
      1,
      'Which books are available?'
    );
    Test.stopTest();
    System.assertEquals('3 of 5 copies available', reply.message);
    System.assertEquals(1, mock.calls);
    System.assertEquals(
      1,
      [
        SELECT Message_Count__c
        FROM Library_Public_Chat_Session__c
        WHERE Id = :row.Id
      ]
      .Message_Count__c
    );
  }

  @IsTest
  static void validTokenEndsSessionOnce() {
    Library_Public_Chat_Session__c row = seed();
    AgentApiMock mock = new AgentApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    LibraryPublicAgentController.endSession(SESSION_ID, goodToken());
    LibraryPublicAgentController.endSession(SESSION_ID, goodToken());
    Test.stopTest();
    System.assertEquals(1, mock.calls, 'second end must not call out again');
    System.assertEquals(
      true,
      [SELECT Ended__c FROM Library_Public_Chat_Session__c WHERE Id = :row.Id]
      .Ended__c
    );
  }

  @IsTest
  static void endedSessionCannotBeReused() {
    Library_Public_Chat_Session__c row = seed();
    row.Ended__c = true;
    update row;
    expectSendError(SESSION_ID, goodToken(), 'ended');
  }

  @IsTest
  static void enforcesPerSessionMessageCap() {
    Library_Public_Chat_Session__c row = seed();
    row.Message_Count__c = 30;
    update row;
    expectSendError(SESSION_ID, goodToken(), 'message limit');
  }

  @IsTest
  static void enforcesDailyGlobalCap() {
    seed();
    LibraryPublicAgentController.maxMessagesPerDay = 0;
    expectSendError(SESSION_ID, goodToken(), 'very busy');
  }

  @IsTest
  static void wrongTokenCannotEndSession() {
    Library_Public_Chat_Session__c row = seed();
    try {
      LibraryPublicAgentController.endSession(SESSION_ID, 'b'.repeat(64));
      System.assert(false, 'Expected invalid-session error');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().contains('invalid'));
    }
    System.assertEquals(
      false,
      [SELECT Ended__c FROM Library_Public_Chat_Session__c WHERE Id = :row.Id]
      .Ended__c
    );
  }

  @IsTest
  static void expiredSessionIsRejected() {
    Library_Public_Chat_Session__c row = seed();
    Test.setCreatedDate(row.Id, System.now().addHours(-3));
    expectSendError(SESSION_ID, goodToken(), 'invalid');
  }

  @IsTest
  static void startSessionNeverOpensPastHourlyCap() {
    seed();
    LibraryPublicAgentController.maxSessionsPerHour = 1;
    try {
      LibraryPublicAgentController.startSession();
      System.assert(false, 'Expected an error');
    } catch (AuraHandledException e) {
      // "not published" (no bot in a test org) or "very busy": either way no
      // Agentforce session is opened.
      System.assert(
        e.getMessage().contains('very busy') ||
        e.getMessage().contains('not been published')
      );
    }
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Library_Public_Chat_Session__c]
    );
  }
}
