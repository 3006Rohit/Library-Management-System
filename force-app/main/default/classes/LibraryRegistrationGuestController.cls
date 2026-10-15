public with sharing class LibraryRegistrationGuestController {
  public class CatalogBook {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String isbn { get; set; }
    @AuraEnabled
    public String publisher { get; set; }
    @AuraEnabled
    public Decimal publicationYear { get; set; }
    @AuraEnabled
    public String coverUrl { get; set; }
    @AuraEnabled
    public Decimal totalCopies { get; set; }
    @AuraEnabled
    public Decimal availableCopies { get; set; }
    @AuraEnabled
    public String authors { get; set; }
    @AuraEnabled
    public String categories { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static List<Membership_Plan__c> getActivePlans() {
    return [
      SELECT Id, Name, Description__c, Duration_Days__c, Borrow_Limit__c
      FROM Membership_Plan__c
      WHERE Active__c = TRUE
      ORDER BY Name
    ];
  }

  @AuraEnabled
  public static String submitRegistration(
    LibraryRegistrationController.RegistrationInput input
  ) {
    return LibraryRegistrationService.submitGuest(input);
  }

  @AuraEnabled(cacheable=true)
  public static List<CatalogBook> searchPublicCatalog(String searchTerm) {
    String normalized = String.isBlank(searchTerm) ? null : searchTerm.trim();
    String likeTerm = normalized == null ? null : '%' + normalized + '%';
    Set<Id> relatedBookIds = new Set<Id>();
    if (likeTerm != null) {
      for (Book_Author__c link : [
        SELECT Book__c
        FROM Book_Author__c
        WHERE Author__r.Name LIKE :likeTerm
        LIMIT 200
      ])
        relatedBookIds.add(link.Book__c);
      for (Book_Category_Link__c link : [
        SELECT Book__c
        FROM Book_Category_Link__c
        WHERE Book_Category__r.Name LIKE :likeTerm
        LIMIT 200
      ])
        relatedBookIds.add(link.Book__c);
    }

    List<Book__c> books;
    if (likeTerm == null) {
      books = [
        SELECT
          Id,
          Name,
          ISBN__c,
          Publisher__c,
          Publication_Year__c,
          Cover_Image_URL__c,
          Total_Copies__c,
          Available_Copies__c,
          (SELECT Author__r.Name FROM Book_Authors__r),
          (SELECT Book_Category__r.Name FROM Book_Category_Links__r)
        FROM Book__c
        WHERE Status__c = 'Active'
        ORDER BY Name
        LIMIT 40
      ];
    } else {
      books = [
        SELECT
          Id,
          Name,
          ISBN__c,
          Publisher__c,
          Publication_Year__c,
          Cover_Image_URL__c,
          Total_Copies__c,
          Available_Copies__c,
          (SELECT Author__r.Name FROM Book_Authors__r),
          (SELECT Book_Category__r.Name FROM Book_Category_Links__r)
        FROM Book__c
        WHERE
          Status__c = 'Active'
          AND (Name LIKE :likeTerm
          OR ISBN__c LIKE :likeTerm
          OR Publisher__c LIKE :likeTerm
          OR Id IN :relatedBookIds)
        ORDER BY Name
        LIMIT 40
      ];
    }

    List<CatalogBook> result = new List<CatalogBook>();
    for (Book__c book : books) {
      CatalogBook item = new CatalogBook();
      item.id = book.Id;
      item.title = book.Name;
      item.isbn = book.ISBN__c;
      item.publisher = book.Publisher__c;
      item.publicationYear = book.Publication_Year__c;
      item.coverUrl = book.Cover_Image_URL__c;
      item.totalCopies = book.Total_Copies__c;
      item.availableCopies = book.Available_Copies__c;
      List<String> authors = new List<String>();
      for (Book_Author__c link : book.Book_Authors__r)
        authors.add(link.Author__r.Name);
      item.authors = authors.isEmpty()
        ? 'Unknown author'
        : String.join(authors, ', ');
      List<String> categories = new List<String>();
      for (Book_Category_Link__c link : book.Book_Category_Links__r)
        categories.add(link.Book_Category__r.Name);
      item.categories = categories.isEmpty()
        ? 'General'
        : String.join(categories, ', ');
      result.add(item);
    }
    return result;
  }
}
