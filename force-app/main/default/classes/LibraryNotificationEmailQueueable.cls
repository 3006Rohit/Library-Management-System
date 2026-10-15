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
    for (Integer index = 0; index < count; index++) {
      LibraryMemberNotificationService.NotificationInput input = inputs[index];
      if (input.notificationId == null)
        continue;
      updates.add(
        new Member_Notification__c(
          Id = input.notificationId,
          Email_Status__c = results[index].isSuccess() ? 'Sent' : 'Failed'
        )
      );
    }
    if (!updates.isEmpty())
      Database.update(updates, AccessLevel.SYSTEM_MODE);
    if (inputs.size() > count) {
      List<LibraryMemberNotificationService.NotificationInput> remaining = new List<LibraryMemberNotificationService.NotificationInput>();
      for (Integer index = count; index < inputs.size(); index++)
        remaining.add(inputs[index]);
      System.enqueueJob(new LibraryNotificationEmailQueueable(remaining));
    }
  }
}
