/**
 * Guest-facing entry point for the signed-out library assistant.
 *
 * Runs `without sharing` on purpose: guests cannot see the private
 * Library_Public_Chat_Session__c ledger, and this class only reads and writes
 * that ledger. It exposes no other data. Every send/end call must present the
 * secret token issued by startSession, so a session id alone is useless.
 */
public without sharing class LibraryPublicAgentController {
  // Abuse and cost limits. Guests have no reliable client identity, so the
  // caps are per session and global.
  @TestVisible
  private static Integer maxMessagesPerSession = 30;
  @TestVisible
  private static Integer maxSessionsPerHour = 60;
  @TestVisible
  private static Integer maxMessagesPerDay = 1500;
  private static final Integer SESSION_TTL_MINUTES = 120;
  private static final Integer TOKEN_MIN_LENGTH = 32;
  private static final String BUSY_MESSAGE = 'The assistant is very busy right now. Please try again later or contact the library desk.';
  private static final String INVALID_MESSAGE = 'The chat session is invalid.';

  public class PublicSession {
    @AuraEnabled
    public String sessionId;
    @AuraEnabled
    public String token;
  }

  @AuraEnabled
  public static PublicSession startSession() {
    // Guests cannot query the BotDefinition setup object, so the published
    // agent's id lives in a custom label (update it if the agent is recreated).
    String agentId = System.Label.Library_Public_Agent_Id;
    if (String.isBlank(agentId)) {
      throw fail('The public assistant has not been published yet.');
    }
    enforceStartLimits();

    // Callout first: no DML may precede it in this transaction.
    LibraryAgentApiController.SessionResponse opened = LibraryAgentApiController.openSession(
      agentId
    );
    String token = newToken();
    Database.insert(
      new Library_Public_Chat_Session__c(
        Session_Id__c = opened.sessionId,
        Token_Hash__c = hash(token),
        Message_Count__c = 0,
        Ended__c = false
      ),
      AccessLevel.SYSTEM_MODE
    );
    PublicSession result = new PublicSession();
    result.sessionId = opened.sessionId;
    result.token = token;
    return result;
  }

  @AuraEnabled
  public static LibraryAgentApiController.MessageResponse sendMessage(
    String sessionId,
    String token,
    Integer sequenceId,
    String text
  ) {
    Library_Public_Chat_Session__c session = authorize(sessionId, token);
    if (session.Ended__c) {
      throw fail('This chat has ended. Start a new one.');
    }
    if (session.Message_Count__c >= maxMessagesPerSession) {
      throw fail(
        'This chat reached its message limit. Start a new chat or contact the library desk.'
      );
    }
    if (dailyMessageCount() >= maxMessagesPerDay) {
      throw fail(BUSY_MESSAGE);
    }
    try {
      return LibraryAgentApiController.sendMessage(sessionId, sequenceId, text);
    } finally {
      // Count the attempt even if the callout failed, so errors cannot be used
      // to bypass the cap. DML after the callout is allowed.
      session.Message_Count__c = session.Message_Count__c + 1;
      Database.update(session, AccessLevel.SYSTEM_MODE);
    }
  }

  @AuraEnabled
  public static void endSession(String sessionId, String token) {
    Library_Public_Chat_Session__c session = authorize(sessionId, token);
    if (session.Ended__c) {
      return;
    }
    try {
      LibraryAgentApiController.endSession(sessionId);
    } finally {
      session.Ended__c = true;
      Database.update(session, AccessLevel.SYSTEM_MODE);
    }
  }

  // setMessage makes the text visible to Apex getMessage() as well as to LWC.
  private static AuraHandledException fail(String message) {
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(message);
    return ex;
  }

  private static Library_Public_Chat_Session__c authorize(
    String sessionId,
    String token
  ) {
    if (
      String.isBlank(sessionId) ||
      String.isBlank(token) ||
      token.length() < TOKEN_MIN_LENGTH
    ) {
      throw fail(INVALID_MESSAGE);
    }
    List<Library_Public_Chat_Session__c> rows = [
      SELECT Id, Token_Hash__c, Message_Count__c, Ended__c, CreatedDate
      FROM Library_Public_Chat_Session__c
      WHERE Session_Id__c = :sessionId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    // One generic message for unknown session, wrong token and expiry, so a
    // caller cannot probe which session ids exist.
    if (
      rows.isEmpty() ||
      !constantTimeEquals(rows[0].Token_Hash__c, hash(token)) ||
      rows[0].CreatedDate < System.now().addMinutes(-SESSION_TTL_MINUTES)
    ) {
      throw fail(INVALID_MESSAGE);
    }
    if (rows[0].Message_Count__c == null) {
      rows[0].Message_Count__c = 0;
    }
    return rows[0];
  }

  private static void enforceStartLimits() {
    Datetime since = System.now().addHours(-1);
    Integer recent = [
      SELECT COUNT()
      FROM Library_Public_Chat_Session__c
      WHERE CreatedDate >= :since
      WITH SYSTEM_MODE
    ];
    if (recent >= maxSessionsPerHour) {
      throw fail(BUSY_MESSAGE);
    }
  }

  private static Integer dailyMessageCount() {
    Datetime since = System.now().addDays(-1);
    AggregateResult[] totals = [
      SELECT SUM(Message_Count__c) total
      FROM Library_Public_Chat_Session__c
      WHERE CreatedDate >= :since
      WITH SYSTEM_MODE
    ];
    Decimal total = (Decimal) totals[0].get('total');
    return total == null ? 0 : total.intValue();
  }

  private static String newToken() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
  }

  private static String hash(String token) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(token))
    );
  }

  private static Boolean constantTimeEquals(String a, String b) {
    if (a == null || b == null || a.length() != b.length()) {
      return false;
    }
    Integer diff = 0;
    for (Integer i = 0; i < a.length(); i++) {
      diff |= a.charAt(i) ^ b.charAt(i);
    }
    return diff == 0;
  }
}
