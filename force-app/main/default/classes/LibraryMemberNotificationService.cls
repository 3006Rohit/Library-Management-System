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
      ])
        existingKeys.add(row.Dedup_Key__c);
    }
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
          Email_Status__c = String.isBlank(input.emailAddress)
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
    for (Integer index = 0; index < records.size(); index++) {
      NotificationInput input = recordInputs[index];
      if (!Test.isRunningTest() && !String.isBlank(input.emailAddress)) {
        input.notificationId = records[index].Id;
        deliver.add(input);
      }
    }
    if (!deliver.isEmpty())
      System.enqueueJob(new LibraryNotificationEmailQueueable(deliver));
  }

  public static void markRead(Id notificationId, Id memberId) {
    List<Member_Notification__c> rows = [
      SELECT Id, Status__c
      FROM Member_Notification__c
      WHERE Id = :notificationId AND Member__c = :memberId
      LIMIT 1
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('Notification was not found.');
    rows[0].Status__c = 'Read';
    rows[0].Read_At__c = System.now();
    Database.update(rows[0], AccessLevel.SYSTEM_MODE);
  }
}
