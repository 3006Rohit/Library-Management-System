public without sharing class LibraryPaymentGatewayService {
  private static final String WEBHOOK_OPERATION = 'Payment Webhook';
  private static final String REFUND_OPERATION = 'Payment Refund';

  public class PaymentDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String idempotencyKey;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String currencyCode;
    @AuraEnabled
    public String gatewayPaymentId;
    @AuraEnabled
    public String checkoutUrl;
  }
  public class WebhookDTO {
    @AuraEnabled
    public String eventId;
    @AuraEnabled
    public String eventType;
    @AuraEnabled
    public String paymentStatus;
    @AuraEnabled
    public Boolean duplicate;
  }
  public class RefundDTO {
    @AuraEnabled
    public Id paymentId;
    @AuraEnabled
    public Id refundRequestId;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String status;
  }

  public class ConfigurationDTO {
    @AuraEnabled
    public Boolean ready;
    @AuraEnabled
    public Boolean enabled;
    @AuraEnabled
    public String providerName;
    @AuraEnabled
    public String currencyCode;
    @AuraEnabled
    public Boolean checkoutCredentialConfigured;
    @AuraEnabled
    public Boolean webhookConfigured;
    @AuraEnabled
    public String message;
  }

  public static ConfigurationDTO getConfigurationStatus() {
    LibraryPolicyService.require('Manage_Library_Fines');
    ConfigurationDTO result = new ConfigurationDTO();
    result.ready = false;
    result.enabled = false;
    result.currencyCode = 'INR';
    result.checkoutCredentialConfigured = false;
    result.webhookConfigured = false;
    List<Payment_Gateway_Config__mdt> rows = [
      SELECT
        Enabled__c,
        Provider_Name__c,
        Checkout_Named_Credential__c,
        Default_Currency__c,
        Webhook_Secret__c
      FROM Payment_Gateway_Config__mdt
      WHERE DeveloperName = 'Default'
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      result.message = 'No default payment gateway configuration is present.';
      return result;
    }
    Payment_Gateway_Config__mdt config = rows[0];
    result.enabled = config.Enabled__c == true;
    result.providerName = String.isBlank(config.Provider_Name__c)
      ? null
      : config.Provider_Name__c.trim();
    if (!String.isBlank(config.Default_Currency__c))
      result.currencyCode = normalizeCurrency(config.Default_Currency__c);
    result.checkoutCredentialConfigured = !String.isBlank(
      config.Checkout_Named_Credential__c
    );
    result.webhookConfigured = !String.isBlank(config.Webhook_Secret__c);
    result.ready =
      result.enabled &&
      !String.isBlank(result.providerName) &&
      result.checkoutCredentialConfigured &&
      result.webhookConfigured;
    result.message = result.ready
      ? 'Payment gateway configuration is ready for provider validation.'
      : 'Payment gateway configuration is incomplete; hosted checkout remains unavailable until all required settings are configured.';
    return result;
  }

  public static PaymentDTO initiate(
    Id memberId,
    Id planId,
    Decimal amount,
    String currencyCode,
    String idempotencyKey
  ) {
    LibraryPolicyService.require('Manage_Library_Fines');
    if (
      memberId == null ||
      amount == null ||
      amount <= 0 ||
      String.isBlank(idempotencyKey)
    )
      throw new AuraHandledException(
        'Member, amount, and a unique idempotency key are required.'
      );
    if (idempotencyKey.trim().length() > 80)
      throw new AuraHandledException(
        'The payment idempotency key is too long.'
      );
    List<Membership_Payment__c> existing = [
      SELECT
        Id,
        Status__c,
        Amount__c,
        Currency__c,
        Idempotency_Key__c,
        Gateway_Payment_Id__c
      FROM Membership_Payment__c
      WHERE Idempotency_Key__c = :idempotencyKey.trim()
      LIMIT 1
    ];
    Membership_Payment__c payment;
    if (!existing.isEmpty())
      payment = existing[0];
    else {
      payment = new Membership_Payment__c(
        Member__c = memberId,
        New_Plan__c = planId,
        Amount__c = amount,
        Currency__c = normalizeCurrency(currencyCode),
        Status__c = 'Initiated',
        Payment_Method__c = 'Hosted Checkout',
        Gateway_Status__c = 'initiated',
        Idempotency_Key__c = idempotencyKey.trim(),
        Reconciliation_Status__c = 'Pending'
      );
      Database.insert(payment, AccessLevel.SYSTEM_MODE);
      LibraryOperationAuditService.record(
        'Payment Initiated',
        'Manage_Library_Fines',
        memberId,
        String.valueOf(payment.Id),
        'Hosted checkout transaction created.',
        'Initiated',
        null,
        new Map<String, Object>{
          'amount' => amount,
          'currency' => payment.Currency__c
        }
      );
    }
    return toPaymentDto(payment);
  }

  public static WebhookDTO processWebhook(String payload, String signature) {
    if (String.isBlank(payload) || String.isBlank(signature))
      throw new AuraHandledException('A signed payment webhook is required.');
    String secret = webhookSecret();
    if (String.isBlank(secret) || !verifySignature(payload, signature, secret))
      throw new AuraHandledException(
        'The payment webhook signature is invalid.'
      );
    Map<String, Object> body;
    try {
      body = (Map<String, Object>) JSON.deserializeUntyped(payload);
    } catch (Exception ex) {
      throw new AuraHandledException('The payment webhook payload is invalid.');
    }
    String eventId = stringValue(body.get('id'));
    String eventType = stringValue(body.get('type'));
    String gatewayPaymentId = stringValue(body.get('payment_id'));
    if (
      String.isBlank(eventId) ||
      String.isBlank(eventType) ||
      String.isBlank(gatewayPaymentId)
    )
      throw new AuraHandledException(
        'The payment webhook is missing required identifiers.'
      );
    List<Library_Scan_Transaction__c> processed = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = :WEBHOOK_OPERATION
        AND Idempotency_Key__c = :('PAYMENT-EVENT:' + eventId)
      LIMIT 1
    ];
    WebhookDTO result = new WebhookDTO();
    result.eventId = eventId;
    result.eventType = eventType;
    result.duplicate = !processed.isEmpty();
    if (result.duplicate) {
      result.paymentStatus = stringValue(
        parse(processed[0].Result_Message__c).get('s')
      );
      return result;
    }
    Membership_Payment__c payment = paymentForGateway(
      gatewayPaymentId,
      stringValue(body.get('idempotency_key'))
    );
    Decimal eventAmount = decimalValue(body.get('amount'));
    if (
      eventAmount != null &&
      eventType.startsWith('payment.') &&
      !eventType.contains('refunded') &&
      payment.Amount__c != null &&
      eventAmount != payment.Amount__c
    )
      throw new AuraHandledException(
        'Webhook amount does not match the initiated transaction.'
      );
    String eventCurrency = stringValue(body.get('currency'));
    if (
      !String.isBlank(eventCurrency) &&
      !String.isBlank(payment.Currency__c) &&
      normalizeCurrency(eventCurrency) != normalizeCurrency(payment.Currency__c)
    )
      throw new AuraHandledException(
        'Webhook currency does not match the initiated transaction.'
      );
    applyEvent(payment, eventType, body);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'PAYMENT-EVENT:' + eventId,
      Operation__c = WEBHOOK_OPERATION,
      Member__c = payment.Member__c,
      Status__c = 'Completed',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'e' => eventType,
            'p' => gatewayPaymentId,
            's' => payment.Status__c
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Payment Webhook Applied',
      'Manage_Library_Fines',
      payment.Member__c,
      eventId,
      'Verified payment provider webhook applied.',
      payment.Status__c,
      null,
      new Map<String, Object>{
        'eventType' => eventType,
        'paymentId' => payment.Id
      }
    );
    result.paymentStatus = payment.Status__c;
    return result;
  }

  public static RefundDTO requestRefund(
    Id paymentId,
    Decimal amount,
    String reason,
    String idempotencyKey
  ) {
    LibraryPolicyService.require('Manage_Library_Fines');
    if (
      paymentId == null ||
      amount == null ||
      amount <= 0 ||
      String.isBlank(reason) ||
      reason.trim().length() < 10 ||
      String.isBlank(idempotencyKey)
    )
      throw new AuraHandledException(
        'Payment, amount, reason, and a unique refund key are required.'
      );
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = :REFUND_OPERATION
        AND Idempotency_Key__c = :idempotencyKey.trim()
      LIMIT 1
    ];
    Library_Scan_Transaction__c row;
    if (!existing.isEmpty())
      row = existing[0];
    else {
      Membership_Payment__c payment = [
        SELECT Id, Member__c, Amount__c, Refund_Amount__c, Status__c
        FROM Membership_Payment__c
        WHERE Id = :paymentId
        LIMIT 1
        FOR UPDATE
      ];
      Decimal refunded = payment.Refund_Amount__c == null
        ? 0
        : payment.Refund_Amount__c;
      if (
        !new Set<String>{ 'Paid', 'Partially Refunded' }
          .contains(payment.Status__c) || amount > payment.Amount__c - refunded
      )
        throw new AuraHandledException(
          'The refund exceeds the settled refundable balance.'
        );
      row = new Library_Scan_Transaction__c(
        Idempotency_Key__c = idempotencyKey.trim(),
        Operation__c = REFUND_OPERATION,
        Member__c = payment.Member__c,
        Status__c = 'Pending',
        Created_At__c = System.now(),
        Result_Message__c = JSON.serialize(
            new Map<String, Object>{
              'p' => paymentId,
              'a' => amount,
              'r' => reason.trim().left(120)
            }
          )
          .left(255)
      );
      Database.insert(row, AccessLevel.SYSTEM_MODE);
      LibraryOperationAuditService.record(
        'Payment Refund Requested',
        'Manage_Library_Fines',
        payment.Member__c,
        String.valueOf(row.Id),
        reason,
        'Pending',
        null,
        new Map<String, Object>{ 'paymentId' => paymentId, 'amount' => amount }
      );
    }
    Map<String, Object> data = parse(row.Result_Message__c);
    RefundDTO result = new RefundDTO();
    result.paymentId = idValue(data.get('p'));
    result.refundRequestId = row.Id;
    result.amount = decimalValue(data.get('a'));
    result.status = row.Status__c;
    return result;
  }

  private static void applyEvent(
    Membership_Payment__c payment,
    String eventType,
    Map<String, Object> body
  ) {
    payment.Gateway_Payment_Id__c = stringValue(body.get('payment_id'));
    payment.Gateway_Status__c = eventType;
    if (eventType == 'payment.succeeded') {
      payment.Status__c = 'Paid';
      payment.Payment_Date__c = System.now();
      payment.Reconciliation_Status__c = 'Pending';
      payment.Transaction_Reference__c = stringValue(body.get('reference'));
    } else if (eventType == 'payment.failed')
      payment.Status__c = 'Failed';
    else if (eventType == 'payment.cancelled')
      payment.Status__c = 'Cancelled';
    else if (eventType == 'payment.disputed')
      payment.Status__c = 'Disputed';
    else if (
      eventType == 'refund.succeeded' ||
      eventType == 'payment.refunded' ||
      eventType == 'payment.partially_refunded'
    ) {
      Decimal refundAmount = decimalValue(body.get('refund_amount'));
      if (refundAmount == null)
        refundAmount = decimalValue(body.get('amount'));
      Decimal cumulative =
        (payment.Refund_Amount__c == null ? 0 : payment.Refund_Amount__c) +
        (refundAmount == null ? 0 : refundAmount);
      payment.Refund_Amount__c = cumulative;
      payment.Refund_Date__c = System.now();
      payment.Status__c = cumulative < payment.Amount__c
        ? 'Partially Refunded'
        : 'Refunded';
      payment.Reconciliation_Status__c = 'Refunded';
    } else
      throw new AuraHandledException('Unsupported payment webhook event.');
    update payment;
  }
  private static Membership_Payment__c paymentForGateway(
    String gatewayId,
    String idempotencyKey
  ) {
    List<Membership_Payment__c> rows = [
      SELECT
        Id,
        Member__c,
        Amount__c,
        Currency__c,
        Refund_Amount__c,
        Status__c,
        Gateway_Payment_Id__c,
        Gateway_Status__c,
        Payment_Date__c,
        Reconciliation_Status__c,
        Transaction_Reference__c
      FROM Membership_Payment__c
      WHERE Gateway_Payment_Id__c = :gatewayId
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty() && !String.isBlank(idempotencyKey))
      rows = [
        SELECT
          Id,
          Member__c,
          Amount__c,
          Currency__c,
          Refund_Amount__c,
          Status__c,
          Gateway_Payment_Id__c,
          Gateway_Status__c,
          Payment_Date__c,
          Reconciliation_Status__c,
          Transaction_Reference__c
        FROM Membership_Payment__c
        WHERE Idempotency_Key__c = :idempotencyKey
        LIMIT 1
        FOR UPDATE
      ];
    if (rows.isEmpty())
      throw new AuraHandledException(
        'The webhook does not match an initiated payment.'
      );
    return rows[0];
  }
  private static PaymentDTO toPaymentDto(Membership_Payment__c payment) {
    PaymentDTO dto = new PaymentDTO();
    dto.id = payment.Id;
    dto.status = payment.Status__c;
    dto.idempotencyKey = payment.Idempotency_Key__c;
    dto.amount = payment.Amount__c;
    dto.currencyCode = payment.Currency__c;
    dto.gatewayPaymentId = payment.Gateway_Payment_Id__c;
    return dto;
  }
  private static String webhookSecret() {
    List<Payment_Gateway_Config__mdt> rows = [
      SELECT Webhook_Secret__c
      FROM Payment_Gateway_Config__mdt
      WHERE DeveloperName = 'Default'
      LIMIT 1
    ];
    if (!rows.isEmpty() && !String.isBlank(rows[0].Webhook_Secret__c))
      return rows[0].Webhook_Secret__c;
    return Test.isRunningTest() ? 'test-secret' : null;
  }
  private static Boolean verifySignature(
    String payload,
    String signature,
    String secret
  ) {
    String supplied = signature.toLowerCase().replace('sha256=', '').trim();
    String expected = EncodingUtil.convertToHex(
        Crypto.generateMac(
          'HmacSHA256',
          Blob.valueOf(payload),
          Blob.valueOf(secret)
        )
      )
      .toLowerCase();
    return supplied == expected;
  }
  private static String normalizeCurrency(String value) {
    return String.isBlank(value) ? 'INR' : value.trim().toUpperCase().left(3);
  }
  private static Map<String, Object> parse(String raw) {
    try {
      return String.isBlank(raw)
        ? new Map<String, Object>()
        : (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
  private static Decimal decimalValue(Object value) {
    try {
      return value == null ? null : Decimal.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static Id idValue(Object value) {
    try {
      return value == null ? null : Id.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
}
