public without sharing class LibraryCatalogService {
  public static Id addBook(
    String title,
    String isbn,
    String publisher,
    Decimal publicationYear,
    String edition,
    String language,
    String description,
    String coverUrl,
    List<Id> authorIds,
    List<Id> categoryIds
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(title) || String.isBlank(isbn))
      throw new AuraHandledException('Title and ISBN are required.');
    if ([SELECT COUNT() FROM Book__c WHERE ISBN__c = :isbn.trim() WITH SYSTEM_MODE] > 0)
      throw new AuraHandledException('A book with this ISBN already exists.');
    Book__c book = new Book__c(
      Name = title.trim(),
      ISBN__c = isbn.trim(),
      Publisher__c = publisher,
      Publication_Year__c = publicationYear,
      Edition__c = edition,
      Language__c = language,
      Description__c = description,
      Cover_Image_URL__c = coverUrl,
      Status__c = 'Active',
      Total_Copies__c = 0,
      Available_Copies__c = 0
    );
    insert book;
    createLinks(book.Id, authorIds, categoryIds);
    LibraryMemberNotificationService.notifyActiveMembersForBook(book.Id, 'New Book', 'New book added to the library', 'A new book, {BOOK}, has been added to the catalog.', 'NEW-BOOK');
    return book.Id;
  }
  public static Id addCopy(
    Id bookId,
    String barcode,
    String shelf,
    Date acquisitionDate,
    String condition,
    Decimal price
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (bookId == null || String.isBlank(barcode))
      throw new AuraHandledException('Book and barcode are required.');
    Book__c book = [SELECT Id FROM Book__c WHERE Id = :bookId WITH SYSTEM_MODE FOR UPDATE];
    if (
      [SELECT COUNT() FROM Book_Copy__c WHERE Barcode__c = :barcode.trim() WITH SYSTEM_MODE] > 0
    )
      throw new AuraHandledException(
        'A copy with this barcode already exists.'
      );
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = bookId,
      Barcode__c = barcode.trim(),
      Status__c = 'Available',
      Shelf_Location__c = shelf,
      Acquisition_Date__c = acquisitionDate == null
        ? Date.today()
        : acquisitionDate,
      Condition__c = String.isBlank(condition) ? 'Good' : condition,
      Price__c = price
    );
    insert copy;
    LibraryMemberNotificationService.notifyActiveMembersForBook(bookId, 'Book Available', 'A book is now available to borrow', '{BOOK} now has a copy available to borrow. Sign in to request it.', 'BOOK-AVAILABLE');
    return copy.Id;
  }
  public static void retireCopy(Id copyId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Book_Copy__c copy = [
      SELECT Id, Status__c
      FROM Book_Copy__c
      WHERE Id = :copyId
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    if (copy.Status__c == 'Borrowed')
      throw new AuraHandledException('A borrowed copy cannot be retired.');
    update new Book_Copy__c(Id = copy.Id, Status__c = 'Retired');
  }
  public static void updateBook(
    Id bookId,
    String title,
    String isbn,
    String publisher,
    Decimal publicationYear,
    String edition,
    String language,
    String description,
    String coverUrl,
    List<Id> authorIds,
    List<Id> categoryIds
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (bookId == null || String.isBlank(title) || String.isBlank(isbn))
      throw new AuraHandledException('Book, title, and ISBN are required.');
    if (
      [
        SELECT COUNT()
        FROM Book__c
        WHERE ISBN__c = :isbn.trim() AND Id != :bookId
        WITH SYSTEM_MODE
      ] > 0
    )
      throw new AuraHandledException('A book with this ISBN already exists.');
    update new Book__c(
      Id = bookId,
      Name = title.trim(),
      ISBN__c = isbn.trim(),
      Publisher__c = publisher,
      Publication_Year__c = publicationYear,
      Edition__c = edition,
      Language__c = language,
      Description__c = description,
      Cover_Image_URL__c = coverUrl
    );
    delete [SELECT Id FROM Book_Author__c WHERE Book__c = :bookId WITH SYSTEM_MODE];
    delete [SELECT Id FROM Book_Category_Link__c WHERE Book__c = :bookId WITH SYSTEM_MODE];
    createLinks(bookId, authorIds, categoryIds);
  }
  public static void updateCopy(
    Id copyId,
    String shelf,
    Date acquisitionDate,
    String condition,
    Decimal price,
    String status
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Book_Copy__c copy = [
      SELECT Id, Book__c, Status__c
      FROM Book_Copy__c
      WHERE Id = :copyId
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    Set<String> allowed = new Set<String>{
      'Available',
      'Borrowed',
      'Reserved',
      'Lost',
      'Damaged',
      'Maintenance',
      'Retired'
    };
    if (String.isBlank(status) || !allowed.contains(status))
      throw new AuraHandledException('Invalid copy status.');
    if (copy.Status__c == 'Borrowed' && status != 'Borrowed')
      throw new AuraHandledException(
        'A borrowed copy must be returned through circulation before its status changes.'
      );
    if (
      status == 'Available' &&
      [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE
          Book_Copy__c = :copyId
          AND Return_Date__c = NULL
          AND Status__c IN ('Active', 'Overdue')
        WITH SYSTEM_MODE
      ] > 0
    )
      throw new AuraHandledException(
        'An actively borrowed copy cannot be made Available.'
      );
    update new Book_Copy__c(
      Id = copyId,
      Shelf_Location__c = shelf,
      Acquisition_Date__c = acquisitionDate,
      Condition__c = condition,
      Price__c = price,
      Status__c = status
    );
    if (status == 'Available')
      LibraryCirculationService.notifyReplacementMembers(copy.Book__c);
  }
  private static void createLinks(
    Id bookId,
    List<Id> authorIds,
    List<Id> categoryIds
  ) {
    List<SObject> links = new List<SObject>();
    if (authorIds != null)
      for (Id authorId : authorIds)
        links.add(new Book_Author__c(Book__c = bookId, Author__c = authorId));
    if (categoryIds != null)
      for (Id categoryId : categoryIds)
        links.add(
          new Book_Category_Link__c(
            Book__c = bookId,
            Book_Category__c = categoryId
          )
        );
    if (!links.isEmpty())
      insert links;
  }
}
