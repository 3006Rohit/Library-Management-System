public without sharing class LibraryMemberNotificationService {
  public class NotificationInput {
    public Id memberId;
    public String type;
    public String subject;
    public String message;
    public Id relatedId;
    public String dedupKey;
    public String emailAddress;
    public Id notificationId;
    public Id emailDeliveryId;
    public Integer emailDeliveryAttempt;
    public Integer emailDeliveryMaxAttempts;

    public NotificationInput(
      Id memberId,
      String type,
      String subject,
      String message,
      Id relatedId,
      String dedupKey,
      String emailAddress
    ) {
      this.memberId = memberId;
      this.type = type;
      this.subject = subject;
      this.message = message;
      this.relatedId = relatedId;
      this.dedupKey = dedupKey;
      this.emailAddress = emailAddress;
    }
  }

  public static void create(
    Id memberId,
    String type,
    String subject,
    String message,
    Id relatedId,
    String dedupKey,
    String emailAddress
  ) {
    createAll(
      new List<NotificationInput>{
        new NotificationInput(
          memberId,
          type,
          subject,
          message,
          relatedId,
          dedupKey,
          emailAddress
        )
      }
    );
  }

  public static void createAll(List<NotificationInput> inputs) {
    if (inputs == null || inputs.isEmpty())
      return;
    Set<String> keys = new Set<String>();
    for (NotificationInput input : inputs) {
      if (
        input != null &&
        input.memberId != null &&
        !String.isBlank(input.dedupKey)
      )
        keys.add(input.dedupKey);
    }
    Set<String> existingKeys = new Set<String>();
    if (!keys.isEmpty()) {
      for (Member_Notification__c row : [
        SELECT Dedup_Key__c
        FROM Member_Notification__c
        WHERE Dedup_Key__c IN :keys
        WITH SYSTEM_MODE
      ])
        existingKeys.add(row.Dedup_Key__c);
    }
    Set<Id> memberIds = new Set<Id>();
    Set<String> notificationTypes = new Set<String>();
    for (NotificationInput input : inputs) {
      if (input != null && input.memberId != null) {
        memberIds.add(input.memberId);
        if (!String.isBlank(input.type))
          notificationTypes.add(input.type);
      }
    }
    Map<String, Boolean> emailDecisions = LibraryNotificationPreferenceService.emailDecisions(
      memberIds,
      notificationTypes
    );
    List<Member_Notification__c> records = new List<Member_Notification__c>();
    List<NotificationInput> deliver = new List<NotificationInput>();
    List<NotificationInput> recordInputs = new List<NotificationInput>();
    Set<String> pendingKeys = new Set<String>();
    for (NotificationInput input : inputs) {
      if (input == null || input.memberId == null)
        continue;
      if (
        !String.isBlank(input.dedupKey) &&
        (existingKeys.contains(input.dedupKey) ||
        pendingKeys.contains(input.dedupKey))
      )
        continue;
      records.add(
        new Member_Notification__c(
          Member__c = input.memberId,
          Type__c = input.type,
          Subject__c = input.subject,
          Message__c = input.message,
          Related_Record__c = input.relatedId == null
            ? null
            : String.valueOf(input.relatedId),
          Dedup_Key__c = input.dedupKey,
          Status__c = 'Unread',
          Email_Status__c = String.isBlank(input.emailAddress) ||
            emailDecisions.containsKey(
              String.valueOf(input.memberId) + '|Email|' + input.type
            ) &&
            !emailDecisions.get(
              String.valueOf(input.memberId) + '|Email|' + input.type
            )
            ? 'Not Applicable'
            : 'Pending'
        )
      );
      recordInputs.add(input);
      if (!String.isBlank(input.dedupKey))
        pendingKeys.add(input.dedupKey);
    }
    if (!records.isEmpty())
      Database.insert(records, AccessLevel.SYSTEM_MODE);
    createDeliveryAttempts(records, recordInputs, emailDecisions);
    for (Integer index = 0; index < records.size(); index++) {
      NotificationInput input = recordInputs[index];
      Boolean emailEnabled =
        !emailDecisions.containsKey(
          String.valueOf(input.memberId) + '|Email|' + input.type
        ) ||
        emailDecisions.get(
          String.valueOf(input.memberId) + '|Email|' + input.type
        );
      if (
        !Test.isRunningTest() &&
        emailEnabled &&
        !String.isBlank(input.emailAddress)
      ) {
        input.notificationId = records[index].Id;
        deliver.add(input);
      }
    }
    if (!deliver.isEmpty())
      System.enqueueJob(new LibraryNotificationEmailQueueable(deliver));
  }

  private static void createDeliveryAttempts(
    List<Member_Notification__c> records,
    List<NotificationInput> inputs,
    Map<String, Boolean> emailDecisions
  ) {
    if (records == null || records.isEmpty())
      return;
    List<Notification_Delivery__c> deliveries = new List<Notification_Delivery__c>();
    List<NotificationInput> emailInputs = new List<NotificationInput>();
    Datetime now = System.now();
    for (Integer index = 0; index < records.size(); index++) {
      Member_Notification__c notification = records[index];
      NotificationInput input = inputs[index];
      deliveries.add(
        new Notification_Delivery__c(
          Member_Notification__c = notification.Id,
          Channel__c = 'In-App',
          Status__c = 'Delivered',
          Attempt__c = 1,
          Attempted_At__c = now,
          Delivered_At__c = now,
          Idempotency_Key__c = String.valueOf(notification.Id) + '|In-App'
        )
      );
      Boolean emailEnabled =
        !emailDecisions.containsKey(
          String.valueOf(input.memberId) + '|Email|' + input.type
        ) ||
        emailDecisions.get(
          String.valueOf(input.memberId) + '|Email|' + input.type
        );
      Boolean hasAddress = !String.isBlank(input.emailAddress);
      Notification_Delivery__c emailDelivery = new Notification_Delivery__c(
        Member_Notification__c = notification.Id,
        Channel__c = 'Email',
        Status__c = emailEnabled && hasAddress ? 'Pending' : 'Skipped',
        Attempt__c = 0,
        Max_Attempts__c = 3,
        Next_Attempt_At__c = emailEnabled && hasAddress ? now : null,
        Idempotency_Key__c = String.valueOf(notification.Id) + '|Email'
      );
      if (!emailEnabled || !hasAddress)
        emailDelivery.Error_Code__c = emailEnabled
          ? 'NO_ADDRESS'
          : 'PREFERENCE_DISABLED';
      deliveries.add(emailDelivery);
      emailInputs.add(input);
    }
    try {
      Database.SaveResult[] results = Database.insert(
        deliveries,
        false,
        AccessLevel.SYSTEM_MODE
      );
      Integer emailIndex = 0;
      for (Integer index = 1; index < results.size(); index += 2) {
        if (results[index].isSuccess()) {
          emailInputs[emailIndex].emailDeliveryId = results[index].getId();
          emailInputs[emailIndex].emailDeliveryMaxAttempts = 3;
        }
        emailIndex++;
      }
    } catch (Exception error) {
      System.debug(
        LoggingLevel.WARN,
        'LIBRARY_NOTIFICATION_DELIVERY_LEDGER_FAILED'
      );
    }
  }

  public static void notifyActiveMembersForBook(
    Id bookId,
    String type,
    String subject,
    String message,
    String keyPrefix
  ) {
    List<Book__c> books = [
      SELECT Id, Name
      FROM Book__c
      WHERE Id = :bookId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (books.isEmpty())
      return;
    List<NotificationInput> inputs = new List<NotificationInput>();
    for (Member__c member : [
      SELECT Id, Email__c
      FROM Member__c
      WHERE Status__c = 'Active' AND Email__c != NULL WITH SYSTEM_MODE LIMIT 500
    ]) {
      inputs.add(
        new NotificationInput(
          member.Id,
          type,
          subject,
          message.replace('{BOOK}', books[0].Name),
          bookId,
          keyPrefix + '-' + bookId + '-' + member.Id,
          member.Email__c
        )
      );
    }
    createAll(inputs);
  }

  public static void markRead(Id notificationId, Id memberId) {
    List<Member_Notification__c> rows = [
      SELECT Id, Status__c
      FROM Member_Notification__c
      WHERE Id = :notificationId AND Member__c = :memberId WITH SYSTEM_MODE LIMIT 1
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('Notification was not found.');
    rows[0].Status__c = 'Read';
    rows[0].Read_At__c = System.now();
    Database.update(rows[0], AccessLevel.SYSTEM_MODE);
  }
}
