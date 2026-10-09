trigger MemberContactSyncTrigger on Member__c (after update) {
    LibraryTransactionContactService.syncTransactionsForChangedMembers(Trigger.new, Trigger.oldMap);
}
