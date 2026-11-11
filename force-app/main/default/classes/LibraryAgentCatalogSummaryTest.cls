@IsTest
private class LibraryAgentCatalogSummaryTest {
  @TestSetup
  static void setup() {
    List<Book__c> books = new List<Book__c>();
    for (Integer i = 1; i <= 12; i++) {
      books.add(
        new Book__c(
          Name = 'Summary Book ' + String.valueOf(100 + i),
          Status__c = 'Active',
          Total_Copies__c = 3,
          Available_Copies__c = i == 12 ? 0 : 2
        )
      );
    }
    insert books;
  }

  private static List<LibraryAgentCatalogAction.BookResult> search(
    Boolean availableOnly
  ) {
    LibraryAgentCatalogAction.Request req = new LibraryAgentCatalogAction.Request();
    req.title = 'Summary Book';
    req.availableOnly = availableOnly;
    return LibraryAgentCatalogAction.execute(
      new List<LibraryAgentCatalogAction.Request>{ req }
    );
  }

  private static User publicAgentUser() {
    Profile standard = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', 'n');
    User u = new User(
      Alias = 'pubag',
      Email = 'pubag' + unique + '@example.com',
      Username = 'pubag' + unique + '@example.com',
      LastName = 'PublicAgent',
      ProfileId = standard.Id,
      TimeZoneSidKey = 'GMT',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    // Setup objects (User, PermissionSetAssignment) cannot be mixed with
    // non-setup DML in one transaction, so run them as a separate context.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
      insert new PermissionSetAssignment(
        AssigneeId = u.Id,
        PermissionSetId = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = 'Library_Public_Agent_Access'
          LIMIT 1
        ]
        .Id
      );
    }
    return u;
  }

  @IsTest
  static void ordinaryCallersKeepOneRowPerBook() {
    System.assertEquals(12, search(false).size());
  }

  @IsTest
  static void publicAgentGetsOneRowListingEightBooks() {
    User agent = publicAgentUser();
    System.runAs(agent) {
      List<LibraryAgentCatalogAction.BookResult> rows = search(true);
      System.assertEquals(1, rows.size());
      System.assertEquals('OK', rows[0].status);
      System.assertEquals(8, rows[0].title.split('\n').size());
      System.assert(rows[0].title.contains('Available (2 of 3 copies)'));
      System.assertEquals(11, rows[0].totalCopies);
      System.assert(rows[0].message.contains('first 8 of 11'));
    }
  }

  @IsTest
  static void publicAgentSeesOnLoanAndNoMatchStates() {
    User agent = publicAgentUser();
    System.runAs(agent) {
      LibraryAgentCatalogAction.Request req = new LibraryAgentCatalogAction.Request();
      req.title = 'Summary Book 112';
      List<LibraryAgentCatalogAction.BookResult> rows = LibraryAgentCatalogAction.execute(
        new List<LibraryAgentCatalogAction.Request>{ req }
      );
      System.assert(rows[0].title.contains('All copies on loan'));
      req.title = 'zzzz qqqq nothing';
      rows = LibraryAgentCatalogAction.execute(
        new List<LibraryAgentCatalogAction.Request>{ req }
      );
      System.assertEquals('NONE', rows[0].status);
    }
  }

  private static Book__c seedDetailedBook() {
    Book__c book = new Book__c(
      Name = 'Detailed Tale',
      Status__c = 'Active',
      Total_Copies__c = 4,
      Available_Copies__c = 1,
      ISBN__c = '9781234567890',
      Publisher__c = 'Test House',
      Publication_Year__c = 2019,
      Edition__c = 'Second',
      Language__c = 'English',
      Description__c = 'A long story about testing.'
    );
    insert book;
    Author__c author = new Author__c(Name = 'Asha Rao');
    insert author;
    insert new Book_Author__c(
      Book__c = book.Id,
      Author__c = author.Id,
      Book_Author_Key__c = book.Id + ':' + author.Id
    );
    Book_Category__c category = new Book_Category__c(Name = 'Mystery');
    insert category;
    insert new Book_Category_Link__c(
      Book__c = book.Id,
      Book_Category__c = category.Id,
      Book_Category_Key__c = book.Id + ':' + category.Id
    );
    return book;
  }

  @IsTest
  static void singleBookSearchReturnsFullDetails() {
    seedDetailedBook();
    User agent = publicAgentUser();
    System.runAs(agent) {
      LibraryAgentCatalogAction.Request req = new LibraryAgentCatalogAction.Request();
      req.title = 'Detailed Tale';
      String text = LibraryAgentCatalogAction.execute(
          new List<LibraryAgentCatalogAction.Request>{ req }
        )[0]
        .title;
      System.assert(text.contains('by Asha Rao'), text);
      System.assert(text.contains('Genre: Mystery'), text);
      System.assert(text.contains('Test House, 2019'), text);
      System.assert(text.contains('Edition: Second'), text);
      System.assert(text.contains('Language: English'), text);
      System.assert(text.contains('ISBN: 9781234567890'), text);
      System.assert(text.contains('About: A long story'), text);
      System.assert(text.contains('Available (1 of 4 copies)'), text);
    }
  }

  @IsTest
  static void genreListShowsGenresWithCounts() {
    seedDetailedBook();
    User agent = publicAgentUser();
    System.runAs(agent) {
      LibraryAgentCatalogAction.Request req = new LibraryAgentCatalogAction.Request();
      req.category = '*';
      LibraryAgentCatalogAction.BookResult result = LibraryAgentCatalogAction.execute(
        new List<LibraryAgentCatalogAction.Request>{ req }
      )[0];
      System.assertEquals('OK', result.status);
      System.assert(result.title.contains('Mystery (1 books)'), result.title);
    }
  }
}
