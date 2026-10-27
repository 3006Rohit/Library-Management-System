@IsTest
private class LibraryPaymentOperationsServiceTest {
  @IsTest
  static void receiptIsIdempotentAndPendingPaymentCanBeReconciled() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Fines');
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Receipt Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fee__c = 100
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Receipt',
      Last_Name__c = 'Member',
      Email__c = 'receipt-member@example.com',
      Normalized_Email__c = 'receipt-member@example.com',
      External_Auth_Id__c = 'receipt-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 5
    );
    insert member;
    Membership_Payment__c payment = new Membership_Payment__c(
      Member__c = member.Id,
      Previous_Plan__c = plan.Id,
      New_Plan__c = plan.Id,
      Amount__c = 100,
      Status__c = 'Paid',
      Payment_Method__c = 'Demo Payment',
      Payment_Date__c = System.now(),
      Transaction_Reference__c = 'RECEIPT-REF',
      Reconciliation_Status__c = 'Pending',
      Idempotency_Key__c = 'RECEIPT-TEST'
    );
    insert payment;
    LibraryPaymentOperationsService.ReceiptDTO first = LibraryPaymentOperationsService.createReceipt(
      payment.Id
    );
    LibraryPaymentOperationsService.ReceiptDTO second = LibraryPaymentOperationsService.createReceipt(
      payment.Id
    );
    System.assertEquals(first.downloadUrl, second.downloadUrl);
    System.assert(
      first.downloadUrl.contains('/sfc/servlet.shepherd/version/download/')
    );
    System.assertEquals(
      1,
      LibraryPaymentOperationsService.getExceptions().size()
    );
    LibraryPaymentOperationsService.reconcile(
      payment.Id,
      'Reconciled',
      'Gateway settlement matched the bank statement.'
    );
    System.assertEquals(
      0,
      LibraryPaymentOperationsService.getExceptions().size()
    );
  }
}
