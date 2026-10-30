public with sharing class LibraryMemberAgentController {
  private static final String MEMBER_AGENT_ID = '0XxgK000002SVqvSAG';

  @AuraEnabled
  public static LibraryAgentApiController.SessionResponse startSession(
    String sessionToken
  ) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    return LibraryAgentApiController.openSession(
      MEMBER_AGENT_ID,
      new List<Object>{
        new Map<String, Object>{
          'name' => 'SessionToken',
          'type' => 'Text',
          'value' => sessionToken
        }
      }
    );
  }

  @AuraEnabled
  public static LibraryAgentApiController.MessageResponse sendMessage(
    String sessionToken,
    String sessionId,
    Integer sequenceId,
    String text
  ) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    return LibraryAgentApiController.sendMessage(sessionId, sequenceId, text);
  }

  @AuraEnabled
  public static void endSession(String sessionToken, String sessionId) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    LibraryAgentApiController.endSession(sessionId);
  }
}
