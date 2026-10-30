public without sharing class LibraryPaymentOperationsService {
  private static final String RECEIPT_OPERATION = 'Payment Receipt';

  public class ReceiptDTO {
    @AuraEnabled
    public Id paymentId;
    @AuraEnabled
    public String paymentName;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public Datetime paidAt;
    @AuraEnabled
    public String reference;
    @AuraEnabled
    public String downloadUrl;
  }

  public class ReconciliationDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String paymentName;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String reference;
    @AuraEnabled
    public Datetime paidAt;
  }

  public static ReceiptDTO createReceipt(Id paymentId) {
    LibraryPolicyService.require('Manage_Library_Fines');
    Membership_Payment__c payment = [
      SELECT
        Id,
        Name,
        Member__c,
        Member__r.Name,
        Amount__c,
        Status__c,
        Payment_Date__c,
        Transaction_Reference__c,
        Reconciliation_Status__c
      FROM Membership_Payment__c
      WHERE Id = :paymentId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (payment.Status__c != 'Paid')
      throw new AuraHandledException(
        'Only paid membership transactions can receive a receipt.'
      );
    String key = 'RECEIPT:' + String.valueOf(payment.Id);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :RECEIPT_OPERATION AND Idempotency_Key__c = :key
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Library_Scan_Transaction__c row;
    if (!existing.isEmpty()) {
      row = existing[0];
    } else {
      ContentVersion file = new ContentVersion(
        Title = 'library-receipt-' + String.valueOf(payment.Name),
        PathOnClient = 'library-receipt-' +
          String.valueOf(payment.Name) +
          '.txt',
        VersionData = Blob.valueOf(receiptBody(payment)),
        IsMajorVersion = true
      );
      Database.insert(file, AccessLevel.SYSTEM_MODE);
      row = new Library_Scan_Transaction__c(
        Idempotency_Key__c = key,
        Operation__c = RECEIPT_OPERATION,
        Member__c = payment.Member__c,
        Status__c = 'Completed',
        Created_At__c = System.now(),
        Result_Message__c = JSON.serialize(
            new Map<String, Object>{ 'cv' => file.Id }
          )
          .left(255)
      );
      Database.insert(row, AccessLevel.SYSTEM_MODE);
      LibraryOperationAuditService.record(
        'Payment Receipt Created',
        'Manage_Library_Fines',
        payment.Member__c,
        key,
        'Receipt generated from a paid membership transaction.',
        'Completed',
        null,
        new Map<String, Object>{ 'paymentId' => payment.Id }
      );
    }
    Map<String, Object> payload = parse(row.Result_Message__c);
    String versionId = payload.get('cv') == null
      ? null
      : String.valueOf(payload.get('cv'));
    ReceiptDTO result = new ReceiptDTO();
    result.paymentId = payment.Id;
    result.paymentName = payment.Name;
    result.memberName = payment.Member__r == null
      ? null
      : payment.Member__r.Name;
    result.amount = payment.Amount__c;
    result.paidAt = payment.Payment_Date__c;
    result.reference = payment.Transaction_Reference__c;
    result.downloadUrl = String.isBlank(versionId)
      ? null
      : '/sfc/servlet.shepherd/version/download/' + versionId;
    return result;
  }

  public static List<ReconciliationDTO> getExceptions() {
    LibraryPolicyService.require('Manage_Library_Fines');
    List<ReconciliationDTO> result = new List<ReconciliationDTO>();
    for (Membership_Payment__c payment : [
      SELECT
        Id,
        Name,
        Member__r.Name,
        Amount__c,
        Status__c,
        Payment_Date__c,
        Transaction_Reference__c,
        Reconciliation_Status__c
      FROM Membership_Payment__c
      WHERE
        Status__c = 'Paid'
        AND (Reconciliation_Status__c = 'Pending'
        OR Reconciliation_Status__c = 'Exception')
      WITH SYSTEM_MODE
      ORDER BY Payment_Date__c DESC
      LIMIT 200
    ])
      result.add(toDto(payment));
    return result;
  }

  public static void reconcile(Id paymentId, String status, String reason) {
    LibraryPolicyService.require('Manage_Library_Fines');
    if (
      !new Set<String>{ 'Reconciled', 'Exception' }.contains(status) ||
      String.isBlank(reason) ||
      reason.trim().length() < 10
    )
      throw new AuraHandledException(
        'Choose Reconciled or Exception and provide at least 10 characters.'
      );
    Membership_Payment__c payment = [
      SELECT Id, Member__c, Status__c, Reconciliation_Status__c
      FROM Membership_Payment__c
      WHERE Id = :paymentId
      WITH SYSTEM_MODE
      LIMIT 1
      FOR UPDATE
    ];
    if (payment.Status__c != 'Paid')
      throw new AuraHandledException(
        'Only paid transactions can be reconciled.'
      );
    String beforeStatus = payment.Reconciliation_Status__c;
    payment.Reconciliation_Status__c = status;
    update payment;
    LibraryOperationAuditService.record(
      'Payment Reconciliation',
      'Manage_Library_Fines',
      payment.Member__c,
      String.valueOf(payment.Id),
      reason,
      status,
      new Map<String, Object>{ 'reconciliationStatus' => beforeStatus },
      new Map<String, Object>{ 'reconciliationStatus' => status }
    );
  }

  private static ReconciliationDTO toDto(Membership_Payment__c payment) {
    ReconciliationDTO dto = new ReconciliationDTO();
    dto.id = payment.Id;
    dto.paymentName = payment.Name;
    dto.memberName = payment.Member__r == null ? null : payment.Member__r.Name;
    dto.amount = payment.Amount__c;
    dto.status = payment.Reconciliation_Status__c;
    dto.reference = payment.Transaction_Reference__c;
    dto.paidAt = payment.Payment_Date__c;
    return dto;
  }
  private static String receiptBody(Membership_Payment__c payment) {
    return 'Library payment receipt\n' +
      'Transaction: ' +
      payment.Name +
      '\n' +
      'Member: ' +
      (payment.Member__r == null ? '—' : payment.Member__r.Name) +
      '\n' +
      'Amount: ' +
      String.valueOf(payment.Amount__c) +
      '\n' +
      'Paid at: ' +
      String.valueOf(payment.Payment_Date__c) +
      '\n' +
      'Reference: ' +
      String.valueOf(payment.Transaction_Reference__c);
  }
  private static Map<String, Object> parse(String raw) {
    if (String.isBlank(raw))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }
}
