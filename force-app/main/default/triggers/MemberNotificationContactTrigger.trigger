trigger MemberNotificationContactTrigger on Member_Notification__c(
  before insert,
  before update
) {
  LibraryTransactionContactService.syncMemberNotifications(Trigger.new);
}
