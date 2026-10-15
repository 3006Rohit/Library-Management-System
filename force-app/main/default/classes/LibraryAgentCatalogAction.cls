global with sharing class LibraryAgentCatalogAction {
  global class Request {
    @InvocableVariable
    public String title;
    @InvocableVariable
    public String author;
    @InvocableVariable
    public String category;
    @InvocableVariable
    public Boolean availableOnly;
  }
  global class BookResult {
    @InvocableVariable
    public String bookId;
    @InvocableVariable
    public String title;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public Decimal totalCopies;
    @InvocableVariable
    public Decimal availableCopies;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Search Library Catalog'
    description='Use this action for live catalog searches by title, author, category, or availability. Invoke it before answering current catalog facts; never returns member or authentication data.'
  )
  global static List<BookResult> execute(List<Request> requests) {
    try {
      return executeInternal(requests);
    } catch (Exception ex) {
      BookResult result = new BookResult();
      result.status = 'ERROR';
      result.message = 'The library catalog is temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_CATALOG_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
      return new List<BookResult>{ result };
    }
  }

  private static List<BookResult> executeInternal(List<Request> requests) {
    Request request = requests == null || requests.isEmpty()
      ? new Request()
      : requests[0];
    String titleTerm = String.isBlank(request.title)
      ? null
      : '%' + request.title.trim() + '%';
    String authorTerm = String.isBlank(request.author)
      ? null
      : '%' + request.author.trim() + '%';
    String categoryTerm = String.isBlank(request.category)
      ? null
      : '%' + request.category.trim() + '%';
    Set<Id> bookIds = new Set<Id>();
    if (authorTerm != null) {
      Set<Id> authorIds = new Map<Id, Author__c>(
          [SELECT Id FROM Author__c WHERE Name LIKE :authorTerm LIMIT 200]
        )
        .keySet();
      if (!authorIds.isEmpty())
        for (Book_Author__c link : [
          SELECT Book__c
          FROM Book_Author__c
          WHERE Author__c IN :authorIds
          LIMIT 200
        ])
          bookIds.add(link.Book__c);
    }
    if (categoryTerm != null) {
      Set<Id> categoryIds = new Map<Id, Book_Category__c>(
          [
            SELECT Id
            FROM Book_Category__c
            WHERE Name LIKE :categoryTerm
            LIMIT 200
          ]
        )
        .keySet();
      if (!categoryIds.isEmpty())
        for (Book_Category_Link__c link : [
          SELECT Book__c
          FROM Book_Category_Link__c
          WHERE Book_Category__c IN :categoryIds
          LIMIT 200
        ])
          bookIds.add(link.Book__c);
    }
    List<Book__c> books;
    // Keep this action on static SOQL. Agentforce executes invocable actions in
    // a separate action runtime where dynamic SOQL binds can fail with opaque
    // UNKNOWN_EXCEPTION/tmpVar errors even though the same query passes in Apex
    // tests. Static branches also keep the catalog query bounded and auditable.
    if (authorTerm != null || categoryTerm != null) {
      if (bookIds.isEmpty())
        return new List<BookResult>();
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Id IN :bookIds
        ORDER BY Name
        LIMIT 50
      ];
      for (Integer index = books.size() - 1; index >= 0; index--) {
        Book__c book = books[index];
        if (
          titleTerm != null &&
          (book.Name == null ||
          !book.Name.toLowerCase().contains(request.title.trim().toLowerCase()))
        ) {
          books.remove(index);
        } else if (
          request.availableOnly == true &&
          (book.Available_Copies__c == null ||
          book.Available_Copies__c <= 0)
        ) {
          books.remove(index);
        }
      }
    } else if (titleTerm != null && request.availableOnly == true) {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Name LIKE :titleTerm AND Available_Copies__c > 0
        ORDER BY Name
        LIMIT 50
      ];
    } else if (titleTerm != null) {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Name LIKE :titleTerm
        ORDER BY Name
        LIMIT 50
      ];
    } else if (request.availableOnly == true) {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Available_Copies__c > 0
        ORDER BY Name
        LIMIT 50
      ];
    } else {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        ORDER BY Name
        LIMIT 50
      ];
    }
    List<BookResult> output = new List<BookResult>();
    for (Book__c book : books) {
      BookResult result = new BookResult();
      result.bookId = String.valueOf(book.Id);
      result.title = book.Name;
      result.status = book.Status__c;
      result.totalCopies = book.Total_Copies__c;
      result.availableCopies = book.Available_Copies__c;
      output.add(result);
    }
    return output;
  }
}
