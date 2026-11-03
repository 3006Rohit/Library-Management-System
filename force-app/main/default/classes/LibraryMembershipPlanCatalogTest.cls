@IsTest
private class LibraryMembershipPlanCatalogTest {
  private static Membership_Plan__c plan(
    String name,
    Decimal fee,
    Decimal limitValue
  ) {
    Membership_Plan__c value = new Membership_Plan__c(
      Name = name,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = limitValue,
      Fee__c = fee
    );
    insert value;
    return value;
  }

  @IsTest
  static void catalogListsEveryActivePlanAndFlagsWhatCanBeBought() {
    Membership_Plan__c basic = plan('Basic', 50, 3);
    Membership_Plan__c standard = plan('Standard', 100, 5);
    Membership_Plan__c premium = plan('Premium', 300, 10);
    Membership_Plan__c retired = plan('Retired', 400, 20);
    retired.Active__c = false;
    update retired;
    Member__c member = new Member__c(
      First_Name__c = 'Plan',
      Last_Name__c = 'Holder',
      Email__c = 'catalog@example.com',
      Normalized_Email__c = 'catalog@example.com',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = standard.Id
    );
    insert member;

    List<LibraryMembershipPaymentService.UpgradePlan> catalog = LibraryMembershipPaymentService.getPlanCatalog(
      member.Id
    );
    System.assertEquals(3, catalog.size());
    System.assertEquals('Basic', catalog[0].name);
    System.assertEquals(false, catalog[0].current);
    System.assertEquals(false, catalog[0].upgradeAllowed);
    System.assertEquals('Standard', catalog[1].name);
    System.assertEquals(true, catalog[1].current);
    System.assertEquals(false, catalog[1].upgradeAllowed);
    System.assertEquals('Premium', catalog[2].name);
    System.assertEquals(false, catalog[2].current);
    System.assertEquals(true, catalog[2].upgradeAllowed);
    System.assertEquals(premium.Id, catalog[2].id);
    System.assertEquals(10, catalog[2].borrowLimit);
    System.assertNotEquals(basic.Id, catalog[2].id);
  }

  @IsTest
  static void catalogRequiresAKnownMember() {
    try {
      LibraryMembershipPaymentService.getPlanCatalog(null);
      System.assert(false, 'Expected an unknown member to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }
}
