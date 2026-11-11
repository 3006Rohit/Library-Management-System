public without sharing class LibraryRegistrationGuestController {
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

  private static final Set<String> PAYMENT_METHODS = new Set<String>{
    'Card',
    'UPI',
    'Net banking',
    'Wallet'
  };

  public class PaymentQuote {
    @AuraEnabled
    public Id planId;
    @AuraEnabled
    public String planName;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String currencyCode;
    @AuraEnabled
    public Decimal durationDays;
    @AuraEnabled
    public Boolean paymentRequired;
  }

  @AuraEnabled(cacheable=true)
  public static List<Membership_Plan__c> getActivePlans() {
    return [
      SELECT
        Id,
        Name,
        Description__c,
        Duration_Days__c,
        Borrow_Limit__c,
        Fee__c,
        Loan_Duration_Days__c,
        Reservation_Limit__c,
        Renewal_Limit__c
      FROM Membership_Plan__c
      WHERE Active__c = TRUE
      WITH SYSTEM_MODE
      ORDER BY Name
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<String> getInterestOptions() {
    List<String> options = new List<String>();
    for (Book_Category__c category : [
      SELECT Name
      FROM Book_Category__c
      WHERE Active__c = TRUE
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 100
    ]) {
      options.add(category.Name);
    }
    return options;
  }

  public class LibraryStats {
    @AuraEnabled
    public Integer bookCount;
    @AuraEnabled
    public Integer memberCount;
  }

  @AuraEnabled(cacheable=true)
  public static LibraryStats getLibraryStats() {
    LibraryStats stats = new LibraryStats();
    stats.bookCount = [
      SELECT COUNT()
      FROM Book__c
      WHERE Status__c = 'Active'
      WITH SYSTEM_MODE
    ];
    stats.memberCount = [
      SELECT COUNT()
      FROM Member__c
      WHERE Account_Status__c = 'Active'
      WITH SYSTEM_MODE
    ];
    return stats;
  }

  @AuraEnabled(cacheable=true)
  public static String getDisplayCurrency() {
    return paymentCurrency();
  }

  @AuraEnabled(cacheable=true)
  public static PaymentQuote getPaymentQuote(Id planId) {
    Membership_Plan__c plan = activePlan(planId);
    PaymentQuote quote = new PaymentQuote();
    quote.planId = plan.Id;
    quote.planName = plan.Name;
    quote.amount = planFee(plan);
    quote.currencyCode = paymentCurrency();
    quote.durationDays = plan.Duration_Days__c;
    quote.paymentRequired = quote.amount > 0;
    return quote;
  }

  // Demo checkout: the amount always comes from the plan record, never from the
  // browser. The registration and its payment are saved together or not at all.
  @AuraEnabled
  public static String submitRegistrationWithPayment(
    LibraryRegistrationController.RegistrationInput input,
    String paymentMethod,
    String idempotencyKey
  ) {
    if (input == null || input.requestedPlanId == null) {
      throw new AuraHandledException('Please complete the registration form.');
    }
    Membership_Plan__c plan = activePlan(input.requestedPlanId);
    Decimal fee = planFee(plan);
    Boolean paying = fee > 0;
    String method = String.isBlank(paymentMethod) ? null : paymentMethod.trim();
    String key = String.isBlank(idempotencyKey) ? null : idempotencyKey.trim();
    if (paying) {
      if (method == null || !PAYMENT_METHODS.contains(method)) {
        throw new AuraHandledException('Choose a payment option to continue.');
      }
      if (key == null || key.length() > 80) {
        throw new AuraHandledException(
          'Payment could not be started. Refresh the page and try again.'
        );
      }
    }
    Savepoint checkpoint = Database.setSavepoint();
    try {
      String registrationId = LibraryRegistrationService.submitGuest(input);
      if (paying) {
        String reference =
          'DEMO-' +
          EncodingUtil.convertToHex(Crypto.generateAesKey(128))
            .substring(0, 12)
            .toUpperCase();
        Database.insert(
          new Membership_Payment__c(
            Amount__c = fee,
            Currency__c = paymentCurrency(),
            Status__c = 'Paid',
            Payment_Method__c = 'Demo Payment',
            Payment_Date__c = System.now(),
            Idempotency_Key__c = key,
            Transaction_Reference__c = reference,
            Gateway_Status__c = 'Demo succeeded',
            New_Plan__c = plan.Id
          ),
          AccessLevel.SYSTEM_MODE
        );
        Database.update(
          new Library_Registration__c(
            Id = registrationId,
            Payment_Status__c = 'Paid',
            Payment_Reference__c = reference,
            Payment_Amount__c = fee,
            Payment_Method_Used__c = method
          ),
          AccessLevel.SYSTEM_MODE
        );
      }
      return registrationId;
    } catch (DmlException ex) {
      Database.rollback(checkpoint);
      if (
        ex.getMessage() != null && ex.getMessage().contains('DUPLICATE_VALUE')
      ) {
        throw friendlyError('This payment was already processed.');
      }
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_PAYMENT_FAILED: ' + ex.getMessage()
      );
      throw friendlyError(
        'We could not complete your payment. You have not been charged. Please try again.'
      );
    } catch (Exception ex) {
      Database.rollback(checkpoint);
      throw ex;
    }
  }

  // AuraHandledException hides its text from getMessage() unless it is set.
  private static AuraHandledException friendlyError(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }

  private static Membership_Plan__c activePlan(Id planId) {
    List<Membership_Plan__c> rows = planId == null
      ? new List<Membership_Plan__c>()
      : [
          SELECT Id, Name, Fee__c, Duration_Days__c
          FROM Membership_Plan__c
          WHERE Id = :planId AND Active__c = TRUE
          WITH SYSTEM_MODE
          LIMIT 1
        ];
    if (rows.isEmpty()) {
      throw new AuraHandledException(
        'The selected membership plan is not active or could not be found.'
      );
    }
    return rows[0];
  }

  private static Decimal planFee(Membership_Plan__c plan) {
    return plan.Fee__c == null || plan.Fee__c < 0 ? 0 : plan.Fee__c;
  }

  private static String paymentCurrency() {
    List<Payment_Gateway_Config__mdt> rows = [
      SELECT Default_Currency__c
      FROM Payment_Gateway_Config__mdt
      WHERE DeveloperName = 'Default'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    String code = rows.isEmpty() ? null : rows[0].Default_Currency__c;
    return String.isBlank(code) ? 'INR' : code.trim().toUpperCase();
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
        WITH SYSTEM_MODE
        LIMIT 200
      ])
        relatedBookIds.add(link.Book__c);
      for (Book_Category_Link__c link : [
        SELECT Book__c
        FROM Book_Category_Link__c
        WHERE Book_Category__r.Name LIKE :likeTerm
        WITH SYSTEM_MODE
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
        WITH SYSTEM_MODE
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
        WITH SYSTEM_MODE
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
