@IsTest
private class LibraryBookInventoryServiceTest {
  @IsTest
  static void countsStayCorrectAcrossBulkCopyLifecycle() {
    Book__c first = new Book__c(
      Name = 'Inventory One',
      ISBN__c = 'INV-ONE',
      Status__c = 'Active',
      Total_Copies__c = 0,
      Available_Copies__c = 0
    );
    Book__c second = new Book__c(
      Name = 'Inventory Two',
      ISBN__c = 'INV-TWO',
      Status__c = 'Active',
      Total_Copies__c = 0,
      Available_Copies__c = 0
    );
    insert new List<Book__c>{ first, second };
    Book_Copy__c available = new Book_Copy__c(
      Book__c = first.Id,
      Barcode__c = 'INV-A',
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    Book_Copy__c borrowed = new Book_Copy__c(
      Book__c = first.Id,
      Barcode__c = 'INV-B',
      Status__c = 'Borrowed',
      Condition__c = 'Good'
    );
    Book_Copy__c other = new Book_Copy__c(
      Book__c = second.Id,
      Barcode__c = 'INV-C',
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    insert new List<Book_Copy__c>{ available, borrowed, other };
    Map<Id, Book__c> books = new Map<Id, Book__c>(
      [
        SELECT Id, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Id IN :new Set<Id>{ first.Id, second.Id }
      ]
    );
    System.assertEquals(2, books.get(first.Id).Total_Copies__c);
    System.assertEquals(1, books.get(first.Id).Available_Copies__c);
    System.assertEquals(1, books.get(second.Id).Available_Copies__c);
    update new Book_Copy__c(Id = available.Id, Status__c = 'Borrowed');
    System.assertEquals(
      0,
      [SELECT Available_Copies__c FROM Book__c WHERE Id = :first.Id]
      .Available_Copies__c
    );
    delete borrowed;
    Book__c afterDelete = [
      SELECT Total_Copies__c, Available_Copies__c
      FROM Book__c
      WHERE Id = :first.Id
    ];
    System.assertEquals(1, afterDelete.Total_Copies__c);
    System.assertEquals(0, afterDelete.Available_Copies__c);
    undelete borrowed;
    Book__c afterUndelete = [
      SELECT Total_Copies__c, Available_Copies__c
      FROM Book__c
      WHERE Id = :first.Id
    ];
    System.assertEquals(2, afterUndelete.Total_Copies__c);
    System.assertEquals(0, afterUndelete.Available_Copies__c);
  }
}
