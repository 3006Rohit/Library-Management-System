@IsTest
private class LibraryRegistrationPaymentTest {
  private static LibraryRegistrationController.RegistrationInput input(
    Id planId,
    String email
  ) {
    LibraryRegistrationController.RegistrationInput value = new LibraryRegistrationController.RegistrationInput();
    value.firstName = 'Pay';
    value.lastName = 'Tester';
    value.email = email;
    value.requestedPlanId = planId;
    return value;
  }

  private static Membership_Plan__c paidPlan(Decimal fee) {
    Membership_Plan__c plan = LibraryTestDataFactory.plan('Paid Plan');
    plan.Fee__c = fee;
    update plan;
    return plan;
  }

  @IsTest
  static void quoteComesFromThePlanFee() {
    Membership_Plan__c plan = paidPlan(499);
    LibraryRegistrationGuestController.PaymentQuote quote = LibraryRegistrationGuestController.getPaymentQuote(
      plan.Id
    );
    System.assertEquals(499, quote.amount);
    System.assertEquals(true, quote.paymentRequired);
    System.assertEquals('INR', quote.currencyCode);
  }

  @IsTest
  static void displayCurrencyComesFromTheGatewayConfiguration() {
    System.assertEquals(
      'INR',
      LibraryRegistrationGuestController.getDisplayCurrency()
    );
  }

  @IsTest
  static void freePlanRegistersWithoutPayment() {
    Membership_Plan__c plan = paidPlan(0);
    String id = LibraryRegistrationGuestController.submitRegistrationWithPayment(
      input(plan.Id, 'free@example.com'),
      null,
      null
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Membership_Payment__c WITH SYSTEM_MODE]
    );
    System.assertEquals(
      null,
      [
        SELECT Payment_Status__c
        FROM Library_Registration__c
        WHERE Id = :id
        WITH SYSTEM_MODE
      ]
      .Payment_Status__c
    );
  }

  @IsTest
  static void paidPlanRecordsDemoPaymentWithRegistration() {
    Membership_Plan__c plan = paidPlan(250);
    String id = LibraryRegistrationGuestController.submitRegistrationWithPayment(
      input(plan.Id, 'paid@example.com'),
      'UPI',
      'key-paid-1'
    );
    Library_Registration__c registration = [
      SELECT
        Status__c,
        Payment_Status__c,
        Payment_Reference__c,
        Payment_Amount__c,
        Payment_Method_Used__c
      FROM Library_Registration__c
      WHERE Id = :id
      WITH SYSTEM_MODE
    ];
    System.assertEquals('Pending', registration.Status__c);
    System.assertEquals('Paid', registration.Payment_Status__c);
    System.assertEquals(250, registration.Payment_Amount__c);
    System.assertEquals('UPI', registration.Payment_Method_Used__c);
    Membership_Payment__c payment = [
      SELECT Amount__c, Status__c, Payment_Method__c, Transaction_Reference__c
      FROM Membership_Payment__c
      WITH SYSTEM_MODE
    ];
    System.assertEquals(250, payment.Amount__c);
    System.assertEquals('Paid', payment.Status__c);
    System.assertEquals('Demo Payment', payment.Payment_Method__c);
    System.assertEquals(
      registration.Payment_Reference__c,
      payment.Transaction_Reference__c
    );
  }

  @IsTest
  static void paidPlanRejectsMissingOrUnknownPaymentOption() {
    Membership_Plan__c plan = paidPlan(250);
    for (String method : new List<String>{ null, '', 'Cash' }) {
      try {
        LibraryRegistrationGuestController.submitRegistrationWithPayment(
          input(plan.Id, 'nopay@example.com'),
          method,
          'key-x'
        );
        System.assert(false, 'Expected rejection for method ' + method);
      } catch (AuraHandledException expected) {
        System.assertNotEquals(null, expected);
      }
    }
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Library_Registration__c WITH SYSTEM_MODE]
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Membership_Payment__c WITH SYSTEM_MODE]
    );
  }

  @IsTest
  static void duplicatePaymentKeyRollsBackTheRegistration() {
    Membership_Plan__c plan = paidPlan(250);
    LibraryRegistrationGuestController.submitRegistrationWithPayment(
      input(plan.Id, 'first@example.com'),
      'Card',
      'same-key'
    );
    try {
      LibraryRegistrationGuestController.submitRegistrationWithPayment(
        input(plan.Id, 'second@example.com'),
        'Card',
        'same-key'
      );
      System.assert(false, 'Expected the reused key to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Membership_Payment__c WITH SYSTEM_MODE]
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Library_Registration__c WITH SYSTEM_MODE]
    );
  }

  @IsTest
  static void inactivePlanIsRejected() {
    Membership_Plan__c plan = paidPlan(100);
    plan.Active__c = false;
    update plan;
    try {
      LibraryRegistrationGuestController.submitRegistrationWithPayment(
        input(plan.Id, 'inactive@example.com'),
        'Card',
        'key-inactive'
      );
      System.assert(false, 'Expected an inactive plan to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }
}
