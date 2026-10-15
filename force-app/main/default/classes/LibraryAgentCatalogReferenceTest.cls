@IsTest
private class LibraryAgentCatalogReferenceTest {
  @IsTest
  static void authorFilterUsesIsolatedReferenceData() {
    Author__c author = new Author__c(Name = 'Reference Author');
    insert author;
    Book__c book = new Book__c(
      Name = 'Reference Book',
      ISBN__c = 'REFERENCE-ISBN',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    insert new Book_Author__c(Book__c = book.Id, Author__c = author.Id);
    LibraryAgentCatalogAction.Request request = new LibraryAgentCatalogAction.Request();
    request.author = author.Name;
    List<LibraryAgentCatalogAction.BookResult> results = LibraryAgentCatalogAction.execute(
      new List<LibraryAgentCatalogAction.Request>{ request }
    );
    System.assertEquals(1, results.size());
    System.assertEquals(book.Id, (Id) results[0].bookId);
  }
}
