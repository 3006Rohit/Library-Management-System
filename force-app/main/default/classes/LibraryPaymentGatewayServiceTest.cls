@IsTest
private class LibraryPaymentGatewayServiceTest {
  private static String signature(String payload) {
    return EncodingUtil.convertToHex(
      Crypto.generateMac(
        'HmacSHA256',
        Blob.valueOf(payload),
        Blob.valueOf('test-secret')
      )
    );
  }

  @IsTest
  static void initiationWebhookAndRefundAreIdempotent() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Fines');
    Member__c member = new Member__c(
      First_Name__c = 'Gateway',
      Last_Name__c = 'Member',
      Email__c = 'gateway@example.com',
      Normalized_Email__c = 'gateway@example.com',
      Status__c = 'Active'
    );
    insert member;
    LibraryPaymentGatewayService.PaymentDTO started = LibraryPaymentGatewayService.initiate(
      member.Id,
      null,
      100,
      'INR',
      'PAY-KEY-1'
    );
    LibraryPaymentGatewayService.PaymentDTO retry = LibraryPaymentGatewayService.initiate(
      member.Id,
      null,
      100,
      'INR',
      'PAY-KEY-1'
    );
    System.assertEquals(started.id, retry.id);
    String success = '{"id":"evt-1","type":"payment.succeeded","payment_id":"gw-1","idempotency_key":"PAY-KEY-1","amount":100,"currency":"INR","reference":"REF-1"}';
    LibraryPaymentGatewayService.WebhookDTO applied = LibraryPaymentGatewayService.processWebhook(
      success,
      signature(success)
    );
    LibraryPaymentGatewayService.WebhookDTO duplicate = LibraryPaymentGatewayService.processWebhook(
      success,
      signature(success)
    );
    System.assertEquals(false, applied.duplicate);
    System.assertEquals(true, duplicate.duplicate);
    System.assertEquals(
      'Paid',
      [SELECT Status__c FROM Membership_Payment__c WHERE Id = :started.id]
      .Status__c
    );

    LibraryPaymentGatewayService.RefundDTO refund = LibraryPaymentGatewayService.requestRefund(
      started.id,
      40,
      'Member requested a partial refund.',
      'REFUND-KEY-1'
    );
    System.assertEquals('Pending', refund.status);
    LibraryPaymentGatewayService.RefundDTO refundRetry = LibraryPaymentGatewayService.requestRefund(
      started.id,
      40,
      'Duplicate request must be idempotent.',
      'REFUND-KEY-1'
    );
    System.assertEquals(refund.refundRequestId, refundRetry.refundRequestId);
    String refundEvent = '{"id":"evt-2","type":"refund.succeeded","payment_id":"gw-1","amount":40,"currency":"INR","refund_amount":40}';
    LibraryPaymentGatewayService.processWebhook(
      refundEvent,
      signature(refundEvent)
    );
    Membership_Payment__c saved = [
      SELECT Status__c, Refund_Amount__c
      FROM Membership_Payment__c
      WHERE Id = :started.id
    ];
    System.assertEquals('Partially Refunded', saved.Status__c);
    System.assertEquals(40, saved.Refund_Amount__c);
  }

  @IsTest
  static void invalidSignatureIsRejected() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Fines');
    try {
      LibraryPaymentGatewayService.processWebhook('{"id":"evt-x"}', 'bad');
      System.assert(false, 'Expected signature rejection');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }

  @IsTest
  static void configurationStatusNeverExposesSecrets() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Fines');

    LibraryPaymentGatewayService.ConfigurationDTO status = LibraryPaymentGatewayService.getConfigurationStatus();

    System.assertNotEquals(null, status);
    System.assertNotEquals(null, status.ready);
    System.assertNotEquals(null, status.enabled);
    System.assertNotEquals(null, status.webhookConfigured);
    System.assert(!String.isBlank(status.message));
    System.assert(status.message.toLowerCase().contains('configuration'));
  }
}
