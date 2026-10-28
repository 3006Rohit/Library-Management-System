public with sharing class LibraryAgentApiController {
  private static final String NAMED_CREDENTIAL = 'Library_Agent_API';
  // Librarian agent for workspace (docs/agent-spec-librarian.yaml)
  private static final String LIBRARIAN_AGENT_ID = '0XxgK000002QwOz';
  // Member agent for member portal (docs/agent-spec-member.yaml)
  // This ID will be dynamically resolved from the activated agent
  private static final String MEMBER_AGENT_ID = 'Library_Member_Assistant';
  private static final String API_ROOT = '/einstein/ai-agent/v1';
  private static final Integer MAX_UTTERANCE_LENGTH = 2000;

  public class SessionResponse {
    @AuraEnabled
    public String sessionId;
  }

  public class MessageResponse {
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String messageType;
  }

  @AuraEnabled
  public static SessionResponse startSession(String agentName) {
    String agentId = agentName == 'librarian'
      ? LIBRARIAN_AGENT_ID
      : MEMBER_AGENT_ID;

    Map<String, Object> body = new Map<String, Object>{
      'externalSessionKey' => createExternalSessionKey(),
      'instanceConfig' => new Map<String, Object>{
        'endpoint' => Url.getOrgDomainUrl().toExternalForm()
      },
      'variables' => new List<Object>(),
      'featureSupport' => 'Sync',
      'bypassUser' => true
    };
    Map<String, Object> response = request(
      'POST',
      API_ROOT + '/agents/' + agentId + '/sessions',
      body
    );
    String sessionId = stringValue(response.get('sessionId'));
    if (String.isBlank(sessionId)) {
      throw new AuraHandledException('Agentforce did not return a session.');
    }
    SessionResponse result = new SessionResponse();
    result.sessionId = sessionId;
    return result;
  }

  @AuraEnabled
  public static MessageResponse sendMessage(
    String sessionId,
    Integer sequenceId,
    String text
  ) {
    if (String.isBlank(sessionId) || sequenceId == null || sequenceId < 1) {
      throw new AuraHandledException('The Agentforce session is invalid.');
    }
    if (String.isBlank(text) || text.trim().length() > MAX_UTTERANCE_LENGTH) {
      throw new AuraHandledException(
        'Enter a question up to 2,000 characters.'
      );
    }

    Map<String, Object> body = new Map<String, Object>{
      'message' => new Map<String, Object>{
        'type' => 'Text',
        'sequenceId' => sequenceId,
        'text' => text.trim()
      },
      'variables' => new List<Object>()
    };
    Map<String, Object> response = request(
      'POST',
      API_ROOT + '/sessions/' + sessionId + '/messages',
      body
    );
    MessageResponse result = extractMessage(response);
    if (String.isBlank(result.message)) {
      throw new AuraHandledException('Agentforce returned no message.');
    }
    return result;
  }

  @AuraEnabled
  public static void endSession(String sessionId) {
    if (String.isBlank(sessionId))
      return;
    request('DELETE', API_ROOT + '/sessions/' + sessionId, null);
  }

  private static Map<String, Object> request(
    String method,
    String path,
    Map<String, Object> body
  ) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:' + NAMED_CREDENTIAL + path);
    request.setMethod(method);
    request.setHeader('Accept', 'application/json');
    request.setTimeout(120000);
    if (method == 'DELETE') {
      request.setHeader('x-session-end-reason', 'UserRequest');
    }
    if (body != null) {
      request.setHeader('Content-Type', 'application/json');
      request.setBody(JSON.serialize(body));
    }

    HttpResponse response;
    try {
      response = new Http().send(request);
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Agentforce callout failed: ' + ex.getTypeName()
      );
      throw new AuraHandledException('Agentforce is temporarily unavailable.');
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      System.debug(
        LoggingLevel.ERROR,
        'Agentforce returned HTTP ' + response.getStatusCode()
      );
      throw new AuraHandledException(
        'Agentforce could not complete that request.'
      );
    }
    if (String.isBlank(response.getBody()))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Agentforce returned an invalid response.'
      );
    }
  }

  private static MessageResponse extractMessage(Map<String, Object> response) {
    MessageResponse result = new MessageResponse();
    List<Object> messages = (List<Object>) response.get('messages');
    if (messages == null)
      return result;
    for (Object item : messages) {
      Map<String, Object> message = (Map<String, Object>) item;
      String text = stringValue(message.get('message'));
      if (!String.isBlank(text)) {
        result.message = text;
        result.messageType = stringValue(message.get('type'));
        if (result.messageType == 'Inform')
          return result;
      }
    }
    return result;
  }

  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static String createExternalSessionKey() {
    Blob digest = Crypto.generateDigest(
      'SHA-256',
      Blob.valueOf(
        UserInfo.getOrganizationId() +
          ':' +
          UserInfo.getUserId() +
          ':' +
          Datetime.now().getTime() +
          ':' +
          Crypto.getRandomInteger()
      )
    );
    String hex = EncodingUtil.convertToHex(digest).substring(0, 32);
    return hex.substring(0, 8) +
      '-' +
      hex.substring(8, 12) +
      '-' +
      hex.substring(12, 16) +
      '-' +
      hex.substring(16, 20) +
      '-' +
      hex.substring(20, 32);
  }
}
