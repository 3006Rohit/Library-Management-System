trigger FineContactTrigger on Fine__c (before insert, before update) {
    LibraryTransactionContactService.syncFines(Trigger.new);
}
