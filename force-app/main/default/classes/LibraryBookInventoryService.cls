public without sharing class LibraryBookInventoryService {
  public static void recalculate(Set<Id> bookIds) {
    if (bookIds == null || bookIds.isEmpty())
      return;
    Map<Id, Integer> totalByBook = new Map<Id, Integer>();
    Map<Id, Integer> availableByBook = new Map<Id, Integer>();
    Map<String, Object> binds = new Map<String, Object>{
      'targetBookIds' => bookIds
    };
    for (
      AggregateResult row : (List<AggregateResult>) Database.queryWithBinds(
        'SELECT Book__c bookId, COUNT(Id) total FROM Book_Copy__c WHERE Book__c IN :targetBookIds GROUP BY Book__c',
        binds,
        AccessLevel.SYSTEM_MODE
      )
    )
      totalByBook.put(
        (Id) row.get('bookId'),
        Integer.valueOf(row.get('total'))
      );
    for (
      AggregateResult row : (List<AggregateResult>) Database.queryWithBinds(
        'SELECT Book__c bookId, COUNT(Id) total FROM Book_Copy__c WHERE Book__c IN :targetBookIds AND Status__c = \'Available\' GROUP BY Book__c',
        binds,
        AccessLevel.SYSTEM_MODE
      )
    )
      availableByBook.put(
        (Id) row.get('bookId'),
        Integer.valueOf(row.get('total'))
      );
    List<Book__c> updates = new List<Book__c>();
    for (Id bookId : bookIds)
      if (bookId != null)
        updates.add(
          new Book__c(
            Id = bookId,
            Total_Copies__c = totalByBook.containsKey(bookId)
              ? totalByBook.get(bookId)
              : 0,
            Available_Copies__c = availableByBook.containsKey(bookId)
              ? availableByBook.get(bookId)
              : 0
          )
        );
    if (!updates.isEmpty())
      Database.update(updates, AccessLevel.SYSTEM_MODE);
  }
}
