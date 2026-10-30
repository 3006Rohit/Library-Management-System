public without sharing class LibraryAgentConfirmationService {
  // Confirmation records bind a one-time token to the authenticated member and target.
  public class PreviewDTO {
    @AuraEnabled
    public String token;
    @AuraEnabled
    public String action;
    @AuraEnabled
    public Id targetId;
    @AuraEnabled
    public String preview;
    @AuraEnabled
    public Datetime expiresAt;
  }

  public static PreviewDTO preview(
    String sessionToken,
    String action,
    Id targetId
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String normalizedAction = normalizeAction(action);
    if (targetId == null)
      throw new AuraHandledException('A target record is required.');
    String previewText;
    if (normalizedAction == 'RENEW_LOAN') {
      Borrow_Record__c loan = [
        SELECT
          Id,
          Member__c,
          Book_Copy__r.Book__r.Name,
          Due_Date__c,
          Renewal_Count__c
        FROM Borrow_Record__c
        WHERE Id = :targetId AND Member__c = :member.Id
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      previewText =
        'Renew ' +
        loan.Book_Copy__r.Book__r.Name +
        ' through the member renewal policy. Current due date: ' +
        String.valueOf(loan.Due_Date__c) +
        '.';
    } else {
      Reservation__c reservation = [
        SELECT Id, Member__c, Book__r.Name, Status__c
        FROM Reservation__c
        WHERE Id = :targetId AND Member__c = :member.Id
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      previewText =
        'Cancel the ' +
        reservation.Status__c.toLowerCase() +
        ' reservation for ' +
        reservation.Book__r.Name +
        '.';
    }
    String rawToken = EncodingUtil.convertToHex(
      Crypto.generateDigest(
        'SHA-256',
        Blob.valueOf(
          UserInfo.getOrganizationId() +
            ':' +
            member.Id +
            ':' +
            Datetime.now().getTime() +
            ':' +
            Crypto.getRandomInteger()
        )
      )
    );
    String tokenHash = hash(rawToken);
    Datetime expires = System.now().addMinutes(5);
    String parameterHash = hash(
      normalizedAction + ':' + targetId + ':' + member.Id
    );
    Library_Scan_Transaction__c confirmation = new Library_Scan_Transaction__c(
      Member__c = member.Id,
      Operation__c = normalizedAction,
      Borrow_Record__c = normalizedAction == 'RENEW_LOAN' ? targetId : null,
      Idempotency_Key__c = tokenHash,
      Status__c = 'Pending',
      Result_Message__c = parameterHash + '|' + String.valueOf(targetId),
      Created_At__c = System.now()
    );
    Database.insert(confirmation, AccessLevel.SYSTEM_MODE);
    PreviewDTO result = new PreviewDTO();
    result.token = rawToken;
    result.action = normalizedAction;
    result.targetId = targetId;
    result.preview = previewText;
    result.expiresAt = expires;
    return result;
  }

  public static Id confirm(String sessionToken, String token) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    if (String.isBlank(token))
      throw new AuraHandledException('A confirmation token is required.');
    String tokenHash = hash(token.trim());
    Library_Scan_Transaction__c confirmation = [
      SELECT
        Id,
        Operation__c,
        Borrow_Record__c,
        Result_Message__c,
        Status__c,
        Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :tokenHash
        AND Member__c = :member.Id
        AND Operation__c IN ('RENEW_LOAN', 'CANCEL_RESERVATION')
      WITH SYSTEM_MODE
      LIMIT 1
      FOR UPDATE
    ];
    List<String> binding = confirmation.Result_Message__c == null
      ? new List<String>()
      : confirmation.Result_Message__c.split('\\|');
    if (
      binding.size() != 2 ||
      binding[0] !=
      hash(confirmation.Operation__c + ':' + binding[1] + ':' + member.Id)
    )
      throw new AuraHandledException(
        'This confirmation does not belong to the authenticated member.'
      );
    if (
      confirmation.Status__c != 'Pending' ||
      confirmation.Created_At__c == null ||
      confirmation.Created_At__c.addMinutes(5) <= System.now()
    )
      throw new AuraHandledException(
        'This confirmation has expired or was already used.'
      );
    confirmation.Status__c = 'Used';
    update confirmation;
    Id targetId = (Id) binding[1];
    if (confirmation.Operation__c == 'RENEW_LOAN') {
      LibraryCirculationService.renewLoanForMember(targetId, member.Id);
    } else {
      LibraryCirculationService.cancelReservationForMember(targetId, member.Id);
    }
    return targetId;
  }

  private static String normalizeAction(String action) {
    String value = action == null ? '' : action.trim().toUpperCase();
    if (value != 'RENEW_LOAN' && value != 'CANCEL_RESERVATION')
      throw new AuraHandledException('That assistant action is not enabled.');
    return value;
  }

  private static String hash(String value) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(value))
    );
  }
}
