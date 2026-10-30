public without sharing class LibraryMembershipPaymentService {
  private static void requireVerifiedPaymentGateway() {
    // The current implementation is a test/demo fixture only. Never create a
    // Paid payment or mutate membership dates in a real transaction until a
    // gateway has returned a verifiable success response.
    if (!Test.isRunningTest()) {
      throw new AuraHandledException(
        'Membership payments are unavailable until a verified payment gateway is configured.'
      );
    }
  }

  public class UpgradePlan {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public Decimal fee { get; set; }
    @AuraEnabled
    public Decimal durationDays { get; set; }
    @AuraEnabled
    public Decimal borrowLimit { get; set; }
    @AuraEnabled
    public Decimal loanDurationDays { get; set; }
    @AuraEnabled
    public Decimal reservationLimit { get; set; }
    @AuraEnabled
    public Decimal renewalLimit { get; set; }
  }

  private static List<Member__c> memberRows(Id memberId, Boolean lockRow) {
    if (memberId == null)
      return new List<Member__c>();
    String safeId = String.escapeSingleQuotes(String.valueOf(memberId));
    String queryText =
      'SELECT Id,Membership_Plan__c,Membership_Plan__r.Name,Membership_Plan__r.Fee__c,' +
      'Membership_Plan__r.Duration_Days__c,Membership_End_Date__c FROM Member__c WHERE Id=\'' +
      safeId +
      '\' LIMIT 1';
    if (lockRow)
      queryText += ' FOR UPDATE';
    return (List<Member__c>) Database.queryWithBinds(
      queryText,
      new Map<String, Object>(),
      AccessLevel.SYSTEM_MODE
    );
  }

  public static List<UpgradePlan> getUpgradePlans(Id memberId) {
    List<Member__c> members = memberRows(memberId, false);
    if (members.isEmpty())
      throw new AuraHandledException(
        'The current library member could not be found.'
      );
    Member__c member = members[0];
    Decimal currentFee = member.Membership_Plan__r == null ||
      member.Membership_Plan__r.Fee__c == null
      ? 0
      : member.Membership_Plan__r.Fee__c;
    List<UpgradePlan> result = new List<UpgradePlan>();
    String planQuery = 'SELECT Id,Name,Fee__c,Duration_Days__c,Borrow_Limit__c,Loan_Duration_Days__c,Reservation_Limit__c,Renewal_Limit__c FROM Membership_Plan__c WHERE Active__c=true ORDER BY Fee__c ASC, Name ASC';
    for (
      Membership_Plan__c plan : (List<Membership_Plan__c>) Database.queryWithBinds(
        planQuery,
        new Map<String, Object>(),
        AccessLevel.SYSTEM_MODE
      )
    ) {
      Decimal fee = plan.Fee__c == null ? 0 : plan.Fee__c;
      if (fee <= currentFee)
        continue;
      UpgradePlan value = new UpgradePlan();
      value.id = plan.Id;
      value.name = plan.Name;
      value.fee = fee;
      value.durationDays = plan.Duration_Days__c;
      value.borrowLimit = plan.Borrow_Limit__c;
      value.loanDurationDays = plan.Loan_Duration_Days__c;
      value.reservationLimit = plan.Reservation_Limit__c;
      value.renewalLimit = plan.Renewal_Limit__c;
      result.add(value);
    }
    return result;
  }

  public static Id payAndUpgrade(Id memberId, Id newPlanId) {
    requireVerifiedPaymentGateway();
    List<Member__c> members = memberRows(memberId, true);
    if (members.isEmpty())
      throw new AuraHandledException(
        'The current library member could not be found.'
      );
    Member__c member = members[0];
    if (newPlanId == null)
      throw new AuraHandledException('A membership plan must be selected.');
    List<Membership_Plan__c> plans = [
      SELECT Id, Name, Fee__c, Duration_Days__c
      FROM Membership_Plan__c
      WHERE Id = :newPlanId AND Active__c = TRUE
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (plans.isEmpty())
      throw new AuraHandledException(
        'The selected membership plan is not active or could not be found.'
      );
    Membership_Plan__c plan = plans[0];
    Decimal oldFee = member.Membership_Plan__r == null
      ? 0
      : (member.Membership_Plan__r.Fee__c == null
          ? 0
          : member.Membership_Plan__r.Fee__c);
    Decimal newFee = plan.Fee__c == null ? 0 : plan.Fee__c;
    if (plan.Id == member.Membership_Plan__c)
      throw new AuraHandledException(
        'You are already using this membership plan.'
      );
    if (newFee <= oldFee)
      throw new AuraHandledException(
        'Only a higher-priced membership plan can be purchased as an upgrade.'
      );
    if (
      [
        SELECT COUNT()
        FROM Membership_Payment__c
        WHERE
          Member__c = :member.Id
          AND New_Plan__c = :plan.Id
          AND Status__c = 'Paid' WITH SYSTEM_MODE ] > 0
    )
      throw new AuraHandledException(
        'A completed payment already exists for this membership upgrade.'
      );
    String reference =
      'DEMO-' +
      String.valueOf(DateTime.now().getTime()) +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
    Membership_Payment__c payment = new Membership_Payment__c(
      Member__c = member.Id,
      Previous_Plan__c = member.Membership_Plan__c,
      New_Plan__c = plan.Id,
      Amount__c = newFee,
      Status__c = 'Paid',
      Payment_Method__c = 'Demo Payment',
      Payment_Date__c = System.now(),
      Transaction_Reference__c = reference,
      Idempotency_Key__c = 'UPGRADE-' +
        String.valueOf(member.Id) +
        '-' +
        String.valueOf(plan.Id)
    );
    Database.insert(payment, AccessLevel.SYSTEM_MODE);
    Integer duration = plan.Duration_Days__c == null
      ? 0
      : Integer.valueOf(plan.Duration_Days__c);
    Date today = Date.today();
    Date currentEnd = member.Membership_End_Date__c != null &&
      member.Membership_End_Date__c > today
      ? member.Membership_End_Date__c
      : today;
    Database.update(
      new Member__c(
        Id = member.Id,
        Membership_Plan__c = plan.Id,
        Membership_Start_Date__c = today,
        Membership_End_Date__c = currentEnd.addDays(duration)
      ),
      AccessLevel.SYSTEM_MODE
    );
    return payment.Id;
  }
  public static Id renewMembership(Id memberId) {
    requireVerifiedPaymentGateway();
    List<Member__c> members = memberRows(memberId, true);
    if (members.isEmpty())
      throw new AuraHandledException(
        'The current library member could not be found.'
      );
    Member__c member = members[0];
    if (member.Membership_Plan__c == null || member.Membership_Plan__r == null)
      throw new AuraHandledException(
        'A membership plan is required before renewal.'
      );
    Integer duration = member.Membership_Plan__r.Duration_Days__c == null
      ? 0
      : Integer.valueOf(member.Membership_Plan__r.Duration_Days__c);
    Date start = member.Membership_End_Date__c != null &&
      member.Membership_End_Date__c > Date.today()
      ? member.Membership_End_Date__c
      : Date.today();
    String reference =
      'RENEWAL-DEMO-' +
      String.valueOf(DateTime.now().getTime()) +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
    Membership_Payment__c payment = new Membership_Payment__c(
      Member__c = member.Id,
      Previous_Plan__c = member.Membership_Plan__c,
      New_Plan__c = member.Membership_Plan__c,
      Amount__c = member.Membership_Plan__r.Fee__c,
      Status__c = 'Paid',
      Payment_Method__c = 'Demo Payment',
      Payment_Date__c = System.now(),
      Transaction_Reference__c = reference,
      Reconciliation_Status__c = 'Pending',
      Idempotency_Key__c = 'RENEWAL-' +
        String.valueOf(member.Id) +
        '-' +
        String.valueOf(Date.today())
    );
    Database.insert(payment, AccessLevel.SYSTEM_MODE);
    Database.update(
      new Member__c(
        Id = member.Id,
        Membership_Start_Date__c = Date.today(),
        Membership_End_Date__c = start.addDays(duration)
      ),
      AccessLevel.SYSTEM_MODE
    );
    return payment.Id;
  }
}
