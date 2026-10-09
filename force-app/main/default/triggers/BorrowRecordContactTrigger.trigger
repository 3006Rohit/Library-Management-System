trigger BorrowRecordContactTrigger on Borrow_Record__c (before insert, before update) {
    LibraryTransactionContactService.syncBorrowRecords(Trigger.new);
}
