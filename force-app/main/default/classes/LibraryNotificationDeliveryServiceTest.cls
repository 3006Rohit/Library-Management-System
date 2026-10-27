@IsTest
private class LibraryNotificationDeliveryServiceTest {
  @IsTest
  static void summarizesAndListsDeliveryAttempts() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Delivery Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Delivery',
      Last_Name__c = 'Member',
      Email__c = 'delivery@example.com',
      Normalized_Email__c = 'delivery@example.com',
      External_Auth_Id__c = 'delivery-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Member_Notification__c notification = new Member_Notification__c(
      Member__c = member.Id,
      Type__c = 'Loan Due',
      Subject__c = 'Due soon',
      Message__c = 'Your loan is due soon.',
      Status__c = 'Unread',
      Dedup_Key__c = 'delivery-test'
    );
    insert notification;
    insert new List<Notification_Delivery__c>{
      new Notification_Delivery__c(
        Member_Notification__c = notification.Id,
        Channel__c = 'In-App',
        Status__c = 'Delivered',
        Attempt__c = 1
      ),
      new Notification_Delivery__c(
        Member_Notification__c = notification.Id,
        Channel__c = 'Email',
        Status__c = 'Failed',
        Attempt__c = 1,
        Error_Code__c = 'PROVIDER_REJECTED'
      )
    };

    LibraryNotificationDeliveryService.SummaryDTO summary = LibraryNotificationDeliveryService.getSummary();
    System.assertEquals(2, summary.total);
    System.assertEquals(1, summary.delivered);
    System.assertEquals(1, summary.failed);
    List<LibraryNotificationDeliveryService.DeliveryDTO> recent = LibraryNotificationDeliveryService.getRecent(
      10
    );
    System.assertEquals(2, recent.size());
  }

  @IsTest
  static void notificationCreationWritesInAppAndEmailAttempts() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Delivery Integration Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Delivery',
      Last_Name__c = 'Integration',
      Email__c = 'delivery-integration@example.com',
      Normalized_Email__c = 'delivery-integration@example.com',
      External_Auth_Id__c = 'delivery-integration-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    LibraryNotificationPreferenceService.getForMember(member.Id);

    LibraryMemberNotificationService.create(
      member.Id,
      'Loan Due',
      'Due soon',
      'Your loan is due soon.',
      null,
      'delivery-integration-key',
      member.Email__c
    );

    List<Notification_Delivery__c> deliveries = [
      SELECT Channel__c, Status__c, Attempt__c
      FROM Notification_Delivery__c
      WHERE Member_Notification__r.Member__c = :member.Id
    ];
    System.assertEquals(2, deliveries.size());
    Set<String> channels = new Set<String>();
    for (Notification_Delivery__c delivery : deliveries)
      channels.add(delivery.Channel__c);
    System.assertEquals(new Set<String>{ 'In-App', 'Email' }, channels);
  }

  @IsTest
  static void dueFailedEmailDeliveryCanBeClaimedForRetry() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Retry Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Retry',
      Last_Name__c = 'Member',
      Email__c = 'retry@example.com',
      Normalized_Email__c = 'retry@example.com',
      External_Auth_Id__c = 'retry-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    Member_Notification__c notification = new Member_Notification__c(
      Member__c = member.Id,
      Type__c = 'Loan Due',
      Subject__c = 'Retry this message',
      Message__c = 'Please retry this message.',
      Status__c = 'Unread',
      Dedup_Key__c = 'retry-test'
    );
    insert notification;
    Notification_Delivery__c delivery = new Notification_Delivery__c(
      Member_Notification__c = notification.Id,
      Channel__c = 'Email',
      Status__c = 'Failed',
      Attempt__c = 1,
      Max_Attempts__c = 3,
      Next_Attempt_At__c = System.now().addMinutes(-1),
      Error_Code__c = 'PROVIDER_REJECTED'
    );
    insert delivery;

    Test.startTest();
    Integer claimed = LibraryNotificationDeliveryRetryService.processDueRetries(
      10
    );
    Test.stopTest();

    Notification_Delivery__c refreshed = [
      SELECT Status__c, Attempt__c, Next_Attempt_At__c, Error_Code__c
      FROM Notification_Delivery__c
      WHERE Id = :delivery.Id
    ];
    System.assertEquals(1, claimed);
    System.assertEquals('Pending', refreshed.Status__c);
    System.assertEquals(1, refreshed.Attempt__c);
    System.assertEquals(null, refreshed.Next_Attempt_At__c);
    System.assertEquals(null, refreshed.Error_Code__c);
  }
}
