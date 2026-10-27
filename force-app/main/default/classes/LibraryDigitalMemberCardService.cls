public without sharing class LibraryDigitalMemberCardService {
  private static final String OPERATION = 'Member Card';
  private static final Integer TOKEN_MINUTES = 10;

  public class CardDTO {
    @AuraEnabled
    public Boolean valid;
    @AuraEnabled
    public String token;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public String memberNumber;
    @AuraEnabled
    public String membershipPlan;
    @AuraEnabled
    public String membershipStatus;
    @AuraEnabled
    public Datetime expiresAt;
    @AuraEnabled
    public String message;
  }

  public static CardDTO issue(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String rawToken = LibraryMemberPasswordService.token();
    Datetime expiresAt = System.now().addMinutes(TOKEN_MINUTES);
    insert new Library_Scan_Transaction__c(
      Idempotency_Key__c = LibraryMemberPasswordService.tokenHash(rawToken),
      Operation__c = OPERATION,
      Member__c = member.Id,
      Status__c = 'Issued',
      Created_At__c = System.now(),
      Result_Message__c = String.valueOf(expiresAt)
    );
    CardDTO result = card(member);
    result.valid = true;
    result.token = rawToken;
    result.expiresAt = expiresAt;
    result.message = 'Show this card at a library kiosk or service desk.';
    return result;
  }

  public static CardDTO validate(String rawToken) {
    if (String.isBlank(rawToken))
      return invalid('This member card is invalid or expired.');
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Member__c, Status__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :LibraryMemberPasswordService.tokenHash(
          rawToken.trim()
        )
        AND Operation__c = :OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (
      rows.isEmpty() ||
      rows[0].Status__c != 'Issued' ||
      rows[0].Created_At__c == null ||
      rows[0].Created_At__c.addMinutes(TOKEN_MINUTES) <= System.now()
    )
      return invalid('This member card is invalid or expired.');
    Datetime expiresAt = rows[0].Created_At__c.addMinutes(TOKEN_MINUTES);
    List<Member__c> members = [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Membership_Plan__r.Name,
        Status__c
      FROM Member__c
      WHERE Id = :rows[0].Member__c
      LIMIT 1
    ];
    if (members.isEmpty() || members[0].Status__c != 'Active')
      return invalid('This member card is invalid or expired.');
    rows[0].Status__c = 'Consumed';
    rows[0].Result_Message__c = 'Validated at ' + String.valueOf(System.now());
    update rows[0];
    CardDTO result = card(members[0]);
    result.valid = true;
    result.message = 'Member card validated.';
    result.expiresAt = expiresAt;
    return result;
  }

  private static CardDTO card(Member__c member) {
    CardDTO result = new CardDTO();
    result.memberName = String.join(
        new List<String>{ member.First_Name__c, member.Last_Name__c },
        ' '
      )
      .trim();
    result.memberNumber = member.Name;
    result.membershipPlan = member.Membership_Plan__r == null
      ? null
      : member.Membership_Plan__r.Name;
    result.membershipStatus = member.Status__c;
    return result;
  }

  private static CardDTO invalid(String message) {
    CardDTO result = new CardDTO();
    result.valid = false;
    result.message = message;
    return result;
  }
}
