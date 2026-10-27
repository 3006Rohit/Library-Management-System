public without sharing class LibraryNotificationEmailQueueable implements Queueable {
  private List<LibraryMemberNotificationService.NotificationInput> inputs;

  public LibraryNotificationEmailQueueable(
    List<LibraryMemberNotificationService.NotificationInput> inputs
  ) {
    this.inputs = inputs == null
      ? new List<LibraryMemberNotificationService.NotificationInput>()
      : inputs;
  }

  public void execute(QueueableContext context) {
    if (inputs.isEmpty())
      return;
    Integer count = Math.min(10, inputs.size());
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    for (Integer index = 0; index < count; index++) {
      LibraryMemberNotificationService.NotificationInput input = inputs[index];
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ input.emailAddress });
      email.setSubject(input.subject);
      email.setPlainTextBody(input.message);
      email.setSaveAsActivity(false);
      emails.add(email);
    }
    Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
    List<Member_Notification__c> updates = new List<Member_Notification__c>();
    List<Notification_Delivery__c> deliveryUpdates = new List<Notification_Delivery__c>();
    Datetime attemptedAt = System.now();
    for (Integer index = 0; index < count; index++) {
      LibraryMemberNotificationService.NotificationInput input = inputs[index];
      if (input.notificationId == null)
        continue;
      Boolean success = results[index].isSuccess();
      Integer previousAttempt = input.emailDeliveryAttempt == null
        ? 0
        : input.emailDeliveryAttempt;
      Integer attempt = previousAttempt + 1;
      updates.add(
        new Member_Notification__c(
          Id = input.notificationId,
          Email_Status__c = success ? 'Sent' : 'Failed'
        )
      );
      if (input.emailDeliveryId != null) {
        Datetime nextAttempt = null;
        Integer maxAttempts = input.emailDeliveryMaxAttempts == null
          ? 3
          : input.emailDeliveryMaxAttempts;
        if (!success && attempt < maxAttempts)
          nextAttempt = attemptedAt.addMinutes(attempt * 5);
        deliveryUpdates.add(
          new Notification_Delivery__c(
            Id = input.emailDeliveryId,
            Status__c = success ? 'Sent' : 'Failed',
            Attempt__c = attempt,
            Attempted_At__c = attemptedAt,
            Delivered_At__c = success ? attemptedAt : null,
            Error_Code__c = success ? null : 'PROVIDER_REJECTED',
            Next_Attempt_At__c = nextAttempt
          )
        );
      }
    }
    if (!updates.isEmpty())
      Database.update(updates, AccessLevel.SYSTEM_MODE);
    if (!deliveryUpdates.isEmpty())
      Database.update(deliveryUpdates, AccessLevel.SYSTEM_MODE);
    if (inputs.size() > count) {
      List<LibraryMemberNotificationService.NotificationInput> remaining = new List<LibraryMemberNotificationService.NotificationInput>();
      for (Integer index = count; index < inputs.size(); index++)
        remaining.add(inputs[index]);
      System.enqueueJob(new LibraryNotificationEmailQueueable(remaining));
    }
  }
}
