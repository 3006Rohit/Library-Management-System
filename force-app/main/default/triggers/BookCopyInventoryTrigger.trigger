trigger BookCopyInventoryTrigger on Book_Copy__c(
  after insert,
  after update,
  after delete,
  after undelete
) {
  Set<Id> bookIds = new Set<Id>();
  if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete)
    for (Book_Copy__c copy : Trigger.new)
      bookIds.add(copy.Book__c);
  if (Trigger.isUpdate || Trigger.isDelete)
    for (Book_Copy__c copy : Trigger.old)
      bookIds.add(copy.Book__c);
  LibraryBookInventoryService.recalculate(bookIds);
}
