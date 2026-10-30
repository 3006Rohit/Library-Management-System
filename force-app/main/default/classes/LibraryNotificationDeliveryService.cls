public with sharing class LibraryNotificationDeliveryService {
  public class SummaryDTO {
    @AuraEnabled
    public Integer total;
    @AuraEnabled
    public Integer pending;
    @AuraEnabled
    public Integer sent;
    @AuraEnabled
    public Integer delivered;
    @AuraEnabled
    public Integer failed;
    @AuraEnabled
    public Integer skipped;
    @AuraEnabled
    public Datetime lastUpdated;
  }

  public class DeliveryDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id notificationId;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public String subject;
    @AuraEnabled
    public String channel;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer attempt;
    @AuraEnabled
    public Datetime attemptedAt;
    @AuraEnabled
    public Datetime deliveredAt;
    @AuraEnabled
    public String errorCode;
  }

  public static SummaryDTO getSummary() {
    SummaryDTO result = new SummaryDTO();
    result.total = 0;
    result.pending = 0;
    result.sent = 0;
    result.delivered = 0;
    result.failed = 0;
    result.skipped = 0;
    for (AggregateResult row : [
      SELECT
        Status__c status,
        COUNT(Id) total,
        MAX(LastModifiedDate) lastUpdated
      FROM Notification_Delivery__c
      WITH SYSTEM_MODE
      GROUP BY Status__c
    ]) {
      Integer count = Integer.valueOf(row.get('total'));
      String status = String.valueOf(row.get('status'));
      result.total += count;
      if (status == 'Pending')
        result.pending += count;
      else if (status == 'Sent')
        result.sent += count;
      else if (status == 'Delivered')
        result.delivered += count;
      else if (status == 'Failed')
        result.failed += count;
      else if (status == 'Skipped')
        result.skipped += count;
      Datetime updated = (Datetime) row.get('lastUpdated');
      if (
        updated != null &&
        (result.lastUpdated == null ||
        updated > result.lastUpdated)
      )
        result.lastUpdated = updated;
    }
    return result;
  }

  public static List<DeliveryDTO> getRecent(Integer requestedLimit) {
    Integer limitSize = requestedLimit == null ||
      requestedLimit < 1
      ? 25
      : Math.min(requestedLimit, 100);
    List<DeliveryDTO> result = new List<DeliveryDTO>();
    for (Notification_Delivery__c row : [
      SELECT
        Id,
        Member_Notification__c,
        Member_Notification__r.Subject__c,
        Member_Notification__r.Member__r.Name,
        Channel__c,
        Status__c,
        Attempt__c,
        Attempted_At__c,
        Delivered_At__c,
        Error_Code__c
      FROM Notification_Delivery__c
      WITH SYSTEM_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT :limitSize
    ]) {
      DeliveryDTO item = new DeliveryDTO();
      item.id = row.Id;
      item.notificationId = row.Member_Notification__c;
      item.subject = row.Member_Notification__r == null
        ? null
        : row.Member_Notification__r.Subject__c;
      item.memberName = row.Member_Notification__r == null ||
        row.Member_Notification__r.Member__r == null
        ? null
        : row.Member_Notification__r.Member__r.Name;
      item.channel = row.Channel__c;
      item.status = row.Status__c;
      item.attempt = row.Attempt__c == null
        ? 0
        : Integer.valueOf(row.Attempt__c);
      item.attemptedAt = row.Attempted_At__c;
      item.deliveredAt = row.Delivered_At__c;
      item.errorCode = row.Error_Code__c;
      result.add(item);
    }
    return result;
  }
}
