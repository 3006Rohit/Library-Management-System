public without sharing class LibraryPublicAgentController {
  private static final String PUBLIC_AGENT_NAME = 'Library_Public_Assistant';

  @AuraEnabled
  public static LibraryAgentApiController.SessionResponse startSession() {
    List<BotDefinition> agents = [
      SELECT Id
      FROM BotDefinition
      WHERE DeveloperName = :PUBLIC_AGENT_NAME
      LIMIT 1
    ];
    if (agents.isEmpty()) {
      throw new AuraHandledException(
        'The public assistant has not been published yet.'
      );
    }
    return LibraryAgentApiController.openSession(agents[0].Id);
  }

  @AuraEnabled
  public static LibraryAgentApiController.MessageResponse sendMessage(
    String sessionId,
    Integer sequenceId,
    String text
  ) {
    return LibraryAgentApiController.sendMessage(sessionId, sequenceId, text);
  }

  @AuraEnabled
  public static void endSession(String sessionId) {
    LibraryAgentApiController.endSession(sessionId);
  }
}
