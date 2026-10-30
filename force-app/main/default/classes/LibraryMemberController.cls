/**
 * @deprecated Legacy Salesforce User/Contact member controller. The deployed
 * custom-auth member shell uses LibraryMemberSessionController. Retained until
 * all legacy Aura/Experience Cloud references are removed and verified.
 */
public with sharing class LibraryMemberController {
  @TestVisible
  private static Id testUserId;
  public class DashboardData {
    @AuraEnabled
    public Member__c member;
    @AuraEnabled
    public Integer activeLoans;
    @AuraEnabled
    public Integer dueSoon;
    @AuraEnabled
    public Integer overdueLoans;
    @AuraEnabled
    public Integer activeReservations;
    @AuraEnabled
    public Decimal outstandingFine;
    @AuraEnabled
    public List<Borrow_Record__c> recentLoans;
    @AuraEnabled
    public List<Reservation__c> recentReservations;
  }
  private static Id userId() {
    return Test.isRunningTest() && testUserId != null
      ? testUserId
      : UserInfo.getUserId();
  }
  private static Member__c currentMember() {
    return LibraryMemberIdentityService.resolve(userId());
  }
  private static List<Book__c> readableBooks(List<Book__c> rows) {
    List<Book__c> result = new List<Book__c>();
    for (
      SObject row : Security.stripInaccessible(AccessType.READABLE, rows)
        .getRecords()
    )
      result.add((Book__c) row);
    return result;
  }
  private static List<Book_Category__c> readableCategories(
    List<Book_Category__c> rows
  ) {
    List<Book_Category__c> result = new List<Book_Category__c>();
    for (
      SObject row : Security.stripInaccessible(AccessType.READABLE, rows)
        .getRecords()
    )
      result.add((Book_Category__c) row);
    return result;
  }
  private static List<Borrow_Record__c> readableBorrowings(
    List<Borrow_Record__c> rows
  ) {
    List<Borrow_Record__c> result = new List<Borrow_Record__c>();
    for (
      SObject row : Security.stripInaccessible(AccessType.READABLE, rows)
        .getRecords()
    )
      result.add((Borrow_Record__c) row);
    return result;
  }
  private static List<Reservation__c> readableReservations(
    List<Reservation__c> rows
  ) {
    List<Reservation__c> result = new List<Reservation__c>();
    for (
      SObject row : Security.stripInaccessible(AccessType.READABLE, rows)
        .getRecords()
    )
      result.add((Reservation__c) row);
    return result;
  }
  private static List<Fine__c> readableFines(List<Fine__c> rows) {
    List<Fine__c> result = new List<Fine__c>();
    for (
      SObject row : Security.stripInaccessible(AccessType.READABLE, rows)
        .getRecords()
    )
      result.add((Fine__c) row);
    return result;
  }
  private static List<Membership_Payment__c> readablePayments(
    List<Membership_Payment__c> rows
  ) {
    List<Membership_Payment__c> result = new List<Membership_Payment__c>();
    for (
      SObject row : Security.stripInaccessible(AccessType.READABLE, rows)
        .getRecords()
    )
      result.add((Membership_Payment__c) row);
    return result;
  }
  private static Member__c readableMember(Member__c member) {
    return (Member__c) Security.stripInaccessible(
        AccessType.READABLE,
        new List<Member__c>{ member }
      )
      .getRecords()[0];
  }
  private static void requireUpdateable(
    Schema.SObjectType objectType,
    List<String> fieldNames
  ) {
    if (!objectType.getDescribe().isUpdateable())
      throw new AuraHandledException('Profile updates are not permitted.');
    Map<String, Schema.SObjectField> fields = objectType.getDescribe()
      .fields.getMap();
    for (String fieldName : fieldNames)
      if (
        !fields.containsKey(fieldName) ||
        !fields.get(fieldName).getDescribe().isUpdateable()
      )
        throw new AuraHandledException(
          'The profile field ' + fieldName + ' is not editable for this user.'
        );
  }
  @AuraEnabled(cacheable=true)
  public static Member__c getCurrentMemberContext() {
    return readableMember(currentMember());
  }
  @AuraEnabled(cacheable=true)
  public static DashboardData getMyDashboard() {
    Member__c m = currentMember();
    try {
      DashboardData d = new DashboardData();
      d.member = readableMember(m);
      DateTime soon = System.now().addDays(3);
      d.activeLoans = [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE Member__c = :m.Id AND Return_Date__c = NULL WITH SYSTEM_MODE ];
      d.overdueLoans = [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE
          Member__c = :m.Id
          AND Return_Date__c = NULL
          AND Due_Date__c < :System.now() WITH SYSTEM_MODE ];
      d.dueSoon = [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE
          Member__c = :m.Id
          AND Return_Date__c = NULL
          AND Due_Date__c >= :System.now()
          AND Due_Date__c <= :soon WITH SYSTEM_MODE ];
      d.activeReservations = [
        SELECT COUNT()
        FROM Reservation__c
        WHERE Member__c = :m.Id AND Status__c IN ('Pending', 'Ready') WITH SYSTEM_MODE ];
      List<AggregateResult> fines = [
        SELECT SUM(Balance__c) total
        FROM Fine__c
        WHERE Member__c = :m.Id AND Status__c IN ('Unpaid', 'Partially Paid') WITH SYSTEM_MODE ];
      d.outstandingFine = fines.isEmpty() || fines[0].get('total') == null
        ? 0
        : (Decimal) fines[0].get('total');
      d.recentLoans = readableBorrowings(
        [
          SELECT
            Id,
            Name,
            Book_Copy__r.Name,
            Book_Copy__r.Barcode__c,
            Book_Copy__r.Book__r.Name,
            Book_Copy__r.Book__r.Cover_Image_URL__c,
            Borrow_Date__c,
            Due_Date__c,
            Return_Date__c,
            Status__c,
            Renewal_Count__c
          FROM Borrow_Record__c
          WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY Borrow_Date__c DESC
          LIMIT 5
        ]
      );
      d.recentReservations = readableReservations(
        [
          SELECT
            Id,
            Name,
            Book__r.Name,
            Book_Copy__r.Name,
            Reservation_Date__c,
            Queue_Position__c,
            Status__c,
            Ready_Date__c,
            Expiry_Date__c,
            Fulfilled_Date__c,
            Estimated_Available_Date__c,
            ETA_Confidence__c,
            ETA_Last_Calculated__c,
            ETA_Reason__c
          FROM Reservation__c
          WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY Reservation_Date__c DESC
          LIMIT 5
        ]
      );
      return d;
    } catch (Exception ex) {
      String detail = ex.getTypeName() + ': ' + ex.getMessage();
      System.debug(LoggingLevel.ERROR, 'MEMBER_DATA_LOAD_FAILED: ' + detail);
      throw new AuraHandledException(
        'MEMBER_PORTAL_ERROR [MEMBER_DATA_LOAD_FAILED]: Your library dashboard could not be loaded. Please try again or contact the library if the problem continues.'
      );
    }
  }
  @AuraEnabled(cacheable=true)
  public static List<Book__c> searchCatalog(
    String searchTerm,
    String categoryId,
    String availability,
    Integer pageSize,
    Integer pageNumber
  ) {
    currentMember();
    Integer size = (pageSize == null ||
      pageSize < 1 ||
      pageSize > 50)
      ? 20
      : pageSize;
    Integer off = (pageNumber == null ||
      pageNumber < 1)
      ? 0
      : (pageNumber - 1) * size;
    String term = String.isBlank(searchTerm)
      ? null
      : '%' + searchTerm.trim() + '%';
    Set<Id> authorBookIds = new Set<Id>();
    if (term != null)
      for (Book_Author__c link : [
        SELECT Book__c
        FROM Book_Author__c
        WHERE Author__r.Name LIKE :term
        WITH SYSTEM_MODE
        LIMIT 1000
      ])
        authorBookIds.add(link.Book__c);
    String q = 'SELECT Id,Name,ISBN__c,Publisher__c,Publication_Year__c,Edition__c,Language__c,Description__c,Cover_Image_URL__c,Total_Copies__c,Available_Copies__c,Status__c,(SELECT Author__r.Name FROM Book_Authors__r),(SELECT Book_Category__r.Name FROM Book_Category_Links__r) FROM Book__c';
    List<String> c = new List<String>();
    if (term != null)
      c.add('(Name LIKE :term OR ISBN__c LIKE :term OR Id IN :authorBookIds)');
    if (!String.isBlank(categoryId))
      c.add(
        'Id IN (SELECT Book__c FROM Book_Category_Link__c WHERE Book_Category__c=:categoryId)'
      );
    if (availability == 'Available')
      c.add('Available_Copies__c>0');
    if (availability == 'Unavailable')
      c.add('Available_Copies__c=0');
    if (!c.isEmpty())
      q += ' WHERE ' + String.join(c, ' AND ');
    q += ' ORDER BY Name LIMIT :size OFFSET :off';
    return readableBooks((List<Book__c>) Database.query(q, AccessLevel.SYSTEM_MODE));
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Category__c> getCatalogCategories() {
    currentMember();
    return readableCategories(
      [
        SELECT Id, Name, Description__c
        FROM Book_Category__c
        WHERE Active__c = TRUE
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 100
      ]
    );
  }
  @AuraEnabled(cacheable=true)
  public static Book__c getBookDetails(Id bookId) {
    currentMember();
    if (bookId == null)
      throw new AuraHandledException('A book must be selected.');
    List<Book__c> books = [
      SELECT
        Id,
        Name,
        ISBN__c,
        Publisher__c,
        Publication_Year__c,
        Edition__c,
        Language__c,
        Description__c,
        Cover_Image_URL__c,
        Total_Copies__c,
        Available_Copies__c,
        Status__c,
        (SELECT Author__r.Name FROM Book_Authors__r),
        (SELECT Book_Category__r.Name FROM Book_Category_Links__r)
      FROM Book__c
      WHERE Id = :bookId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (books.isEmpty())
      throw new AuraHandledException(
        'The selected book was not found or is no longer available.'
      );
    return readableBooks(books)[0];
  }
  @AuraEnabled
  public static Id borrowBook(Id bookId) {
    Member__c member = currentMember();
    if (bookId == null)
      throw new AuraHandledException('A book must be selected.');
    List<Reservation__c> readyReservations = [
      SELECT Book_Copy__c
      FROM Reservation__c
      WHERE
        Member__c = :member.Id
        AND Book__c = :bookId
        AND Status__c = 'Ready'
        AND Book_Copy__c != NULL WITH SYSTEM_MODE ORDER BY Ready_Date__c
      LIMIT 1
    ];
    Id reservedCopyId = readyReservations.isEmpty()
      ? null
      : readyReservations[0].Book_Copy__c;
    List<Book_Copy__c> availableCopies;
    if (reservedCopyId != null)
      availableCopies = [
        SELECT Id
        FROM Book_Copy__c
        WHERE Id = :reservedCopyId AND Status__c IN ('Available', 'Reserved') WITH SYSTEM_MODE LIMIT 1
        FOR UPDATE
      ];
    else
      availableCopies = [
        SELECT Id
        FROM Book_Copy__c
        WHERE Book__c = :bookId AND Status__c = 'Available' WITH SYSTEM_MODE LIMIT 1
        FOR UPDATE
      ];
    if (availableCopies.isEmpty())
      throw new AuraHandledException(
        'No copy is currently available. Reserve this title to join the queue.'
      );
    return LibraryMemberBorrowService.checkout(member, availableCopies[0].Id);
  }
  @AuraEnabled(cacheable=true)
  public static List<Borrow_Record__c> getMyBorrowings() {
    Member__c m = currentMember();
    return readableBorrowings(
      [
        SELECT
          Id,
          Name,
          Book_Copy__r.Name,
          Book_Copy__r.Barcode__c,
          Book_Copy__r.Book__r.Name,
          Book_Copy__r.Book__r.Cover_Image_URL__c,
          Borrow_Date__c,
          Due_Date__c,
          Return_Date__c,
          Status__c,
          Renewal_Count__c
        FROM Borrow_Record__c
        WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY Borrow_Date__c DESC
        LIMIT 200
      ]
    );
  }
  @AuraEnabled
  public static void renewMyLoan(Id borrowRecordId) {
    Member__c m = currentMember();
    LibraryCirculationService.renewLoanForMember(borrowRecordId, m.Id);
  }
  @AuraEnabled(cacheable=true)
  public static List<Reservation__c> getMyReservations() {
    Member__c m = currentMember();
    return readableReservations(
      [
        SELECT
          Id,
          Name,
          Book__r.Name,
          Book_Copy__r.Name,
          Reservation_Date__c,
          Queue_Position__c,
          Status__c,
          Ready_Date__c,
          Expiry_Date__c,
          Fulfilled_Date__c,
          Estimated_Available_Date__c,
          ETA_Confidence__c,
          ETA_Last_Calculated__c,
          ETA_Reason__c
        FROM Reservation__c
        WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY Reservation_Date__c DESC
        LIMIT 200
      ]
    );
  }
  @AuraEnabled
  public static Id reserveBook(Id bookId) {
    Member__c m = currentMember();
    Id reservationId = LibraryCirculationService.createReservationForMember(
      m,
      bookId
    );
    LibraryReservationWorkflowService.promoteAvailableReservations(bookId);
    return reservationId;
  }
  @AuraEnabled
  public static void cancelMyReservation(Id reservationId) {
    Member__c m = currentMember();
    LibraryCirculationService.cancelReservationForMember(reservationId, m.Id);
  }
  @AuraEnabled(cacheable=true)
  public static List<Fine__c> getMyFines() {
    Member__c m = currentMember();
    return readableFines(
      [
        SELECT
          Id,
          Name,
          Borrow_Record__r.Name,
          Borrow_Record__r.Book_Copy__r.Book__r.Name,
          Fine_Type__c,
          Amount__c,
          Paid_Amount__c,
          Balance__c,
          Status__c,
          Generated_Date__c,
          Paid_Date__c
        FROM Fine__c
        WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY Generated_Date__c DESC
        LIMIT 200
      ]
    );
  }
  @AuraEnabled(cacheable=true)
  public static List<Membership_Payment__c> getMyPayments() {
    Member__c m = currentMember();
    return readablePayments(
      [
        SELECT
          Id,
          Name,
          Previous_Plan__r.Name,
          New_Plan__r.Name,
          Amount__c,
          Status__c,
          Payment_Method__c,
          Payment_Date__c,
          Transaction_Reference__c
        FROM Membership_Payment__c
        WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY Payment_Date__c DESC
        LIMIT 100
      ]
    );
  }
  @AuraEnabled(cacheable=true)
  public static List<Member_Notification__c> getMyNotifications() {
    Member__c m = currentMember();
    return (List<Member_Notification__c>) Security.stripInaccessible(
        AccessType.READABLE,
        [
          SELECT
            Id,
            Name,
            Type__c,
            Subject__c,
            Message__c,
            Status__c,
            Related_Record__c,
            CreatedDate,
            Read_At__c
          FROM Member_Notification__c
          WHERE Member__c = :m.Id WITH SYSTEM_MODE ORDER BY CreatedDate DESC
          LIMIT 100
        ]
      )
      .getRecords();
  }
  @AuraEnabled
  public static void markNotificationRead(Id notificationId) {
    Member__c m = currentMember();
    LibraryMemberNotificationService.markRead(notificationId, m.Id);
  }
  @AuraEnabled(cacheable=true)
  public static Member__c getMyMembership() {
    return readableMember(currentMember());
  }
  @AuraEnabled(cacheable=true)
  public static List<LibraryMembershipPaymentService.UpgradePlan> getUpgradePlans() {
    Member__c m = currentMember();
    return LibraryMembershipPaymentService.getUpgradePlans(m.Id);
  }
  @AuraEnabled
  public static Id payForMembershipUpgrade(Id planId) {
    Member__c m = currentMember();
    return LibraryMembershipPaymentService.payAndUpgrade(m.Id, planId);
  }
  @AuraEnabled
  public static Id renewMyMembership() {
    Member__c m = currentMember();
    return LibraryMembershipPaymentService.renewMembership(m.Id);
  }
  @AuraEnabled(cacheable=true)
  public static Member__c getMyProfile() {
    return readableMember(currentMember());
  }
  @AuraEnabled
  public static void updateMyProfile(
    String firstName,
    String lastName,
    String phone,
    String address
  ) {
    requireUpdateable(
      Member__c.SObjectType,
      new List<String>{
        'First_Name__c',
        'Last_Name__c',
        'Phone__c',
        'Address__c'
      }
    );
    Member__c current = currentMember();
    // Use a sparse update record. The identity resolver intentionally strips
    // protected fields from the readable member, and sending that full SObject
    // back through DML can trigger inaccessible-field errors for portal users.
    Member__c memberUpdate = new Member__c(
      Id = current.Id,
      First_Name__c = firstName,
      Last_Name__c = lastName,
      Phone__c = phone,
      Address__c = address
    );
    update memberUpdate;
    if (current.Contact__c != null) {
      Database.update(
        new Contact(
          Id = current.Contact__c,
          FirstName = firstName,
          LastName = lastName,
          Phone = phone,
          MailingStreet = address
        ),
        AccessLevel.SYSTEM_MODE
      );
    }
  }
}
