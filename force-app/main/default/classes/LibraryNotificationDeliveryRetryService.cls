public without sharing class LibraryNotificationDeliveryRetryService {
  public static Integer retryFailedDeliveries(Integer requestedLimit) {
    return claimAndEnqueue(requestedLimit, false);
  }

  public static Integer processDueRetries(Integer requestedLimit) {
    return claimAndEnqueue(requestedLimit, true);
  }

  private static Integer claimAndEnqueue(
    Integer requestedLimit,
    Boolean dueOnly
  ) {
    Integer limitSize = requestedLimit == null ||
      requestedLimit < 1
      ? 10
      : Math.min(requestedLimit, 10);
    Datetime now = System.now();
    List<Notification_Delivery__c> candidates = [
      SELECT
        Id,
        Attempt__c,
        Max_Attempts__c,
        Next_Attempt_At__c,
        Member_Notification__c,
        Member_Notification__r.Member__c,
        Member_Notification__r.Type__c,
        Member_Notification__r.Subject__c,
        Member_Notification__r.Message__c,
        Member_Notification__r.Related_Record__c,
        Member_Notification__r.Dedup_Key__c,
        Member_Notification__r.Member__r.Email__c
      FROM Notification_Delivery__c
      WHERE Channel__c = 'Email' AND Status__c = 'Failed'
      WITH SYSTEM_MODE
      LIMIT 100
      FOR UPDATE
    ];
    List<Notification_Delivery__c> updates = new List<Notification_Delivery__c>();
    List<LibraryMemberNotificationService.NotificationInput> inputs = new List<LibraryMemberNotificationService.NotificationInput>();
    for (Notification_Delivery__c delivery : candidates) {
      if (inputs.size() >= limitSize)
        break;
      Integer attempt = delivery.Attempt__c == null
        ? 0
        : Integer.valueOf(delivery.Attempt__c);
      Integer maxAttempts = delivery.Max_Attempts__c == null
        ? 3
        : Integer.valueOf(delivery.Max_Attempts__c);
      if (attempt >= maxAttempts)
        continue;
      if (
        dueOnly &&
        delivery.Next_Attempt_At__c != null &&
        delivery.Next_Attempt_At__c > now
      )
        continue;
      String email = delivery.Member_Notification__r == null ||
        delivery.Member_Notification__r.Member__r == null
        ? null
        : delivery.Member_Notification__r.Member__r.Email__c;
      if (String.isBlank(email)) {
        updates.add(
          new Notification_Delivery__c(
            Id = delivery.Id,
            Status__c = 'Skipped',
            Error_Code__c = 'NO_ADDRESS',
            Next_Attempt_At__c = null
          )
        );
        continue;
      }
      LibraryMemberNotificationService.NotificationInput input = new LibraryMemberNotificationService.NotificationInput(
        delivery.Member_Notification__r.Member__c,
        delivery.Member_Notification__r.Type__c,
        delivery.Member_Notification__r.Subject__c,
        delivery.Member_Notification__r.Message__c,
        parseId(delivery.Member_Notification__r.Related_Record__c),
        delivery.Member_Notification__r.Dedup_Key__c,
        email
      );
      input.notificationId = delivery.Member_Notification__c;
      input.emailDeliveryId = delivery.Id;
      input.emailDeliveryAttempt = attempt;
      input.emailDeliveryMaxAttempts = maxAttempts;
      inputs.add(input);
      updates.add(
        new Notification_Delivery__c(
          Id = delivery.Id,
          Status__c = 'Pending',
          Error_Code__c = null,
          Next_Attempt_At__c = null
        )
      );
    }
    if (!updates.isEmpty())
      Database.update(updates, AccessLevel.SYSTEM_MODE);
    if (!inputs.isEmpty() && !Test.isRunningTest())
      System.enqueueJob(new LibraryNotificationEmailQueueable(inputs));
    return inputs.size();
  }

  private static Id parseId(String value) {
    try {
      return String.isBlank(value) ? null : Id.valueOf(value);
    } catch (Exception ignored) {
      return null;
    }
  }
}
