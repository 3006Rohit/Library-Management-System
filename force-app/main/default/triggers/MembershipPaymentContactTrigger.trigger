trigger MembershipPaymentContactTrigger on Membership_Payment__c(
  before insert,
  before update
) {
  LibraryTransactionContactService.syncMembershipPayments(Trigger.new);
}
