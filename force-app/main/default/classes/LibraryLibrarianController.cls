public with sharing class LibraryLibrarianController {
  public class DashboardData {
    @AuraEnabled
    public Integer totalBooks;
    @AuraEnabled
    public Integer totalCopies;
    @AuraEnabled
    public Integer availableCopies;
    @AuraEnabled
    public Integer borrowedCopies;
    @AuraEnabled
    public Integer totalMembers;
    @AuraEnabled
    public Integer activeMembers;
    @AuraEnabled
    public Integer pendingRegistrations;
    @AuraEnabled
    public Integer activeLoans;
    @AuraEnabled
    public Integer overdueLoans;
    @AuraEnabled
    public Integer pendingReservations;
    @AuraEnabled
    public Integer unpaidFines;
    @AuraEnabled
    public Decimal membershipRevenue;
    @AuraEnabled
    public List<Borrow_Record__c> recentLoans;
    @AuraEnabled
    public List<Library_Registration__c> registrations;
    @AuraEnabled
    public List<Reservation__c> readyReservations;
  }
  public class MemberDetail {
    @AuraEnabled
    public Member__c member;
    @AuraEnabled
    public List<Borrow_Record__c> loans;
    @AuraEnabled
    public List<Reservation__c> reservations;
    @AuraEnabled
    public List<Fine__c> fines;
    @AuraEnabled
    public List<Membership_Payment__c> payments;
    @AuraEnabled
    public Decimal outstandingBalance;
  }
  public class PaymentRow {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public String paymentType;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public Datetime paymentDate;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String reference;
  }
  @AuraEnabled(cacheable=true)
  public static DashboardData getDashboard() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    DashboardData d = new DashboardData();
    List<AggregateResult> books = [
      SELECT
        COUNT(Id) total,
        SUM(Total_Copies__c) copies,
        SUM(Available_Copies__c) available
      FROM Book__c
    ];
    d.totalBooks = Integer.valueOf(books[0].get('total'));
    d.totalCopies = books[0].get('copies') == null
      ? 0
      : Integer.valueOf(books[0].get('copies'));
    d.availableCopies = books[0].get('available') == null
      ? 0
      : Integer.valueOf(books[0].get('available'));
    d.borrowedCopies = d.totalCopies - d.availableCopies;
    d.totalMembers = [SELECT COUNT() FROM Member__c];
    d.activeMembers = [
      SELECT COUNT()
      FROM Member__c
      WHERE Status__c = 'Active' AND Membership_End_Date__c >= :Date.today()
    ];
    d.pendingRegistrations = [
      SELECT COUNT()
      FROM Library_Registration__c
      WHERE Status__c = 'Pending'
    ];
    d.activeLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Return_Date__c = NULL AND Status__c IN ('Active', 'Overdue')
    ];
    d.overdueLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Return_Date__c = NULL AND Due_Date__c < :System.now()
    ];
    d.pendingReservations = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE Status__c = 'Pending'
    ];
    d.unpaidFines = [
      SELECT COUNT()
      FROM Fine__c
      WHERE Status__c IN ('Unpaid', 'Partially Paid')
    ];
    List<AggregateResult> revenue = [
      SELECT SUM(Amount__c) total
      FROM Membership_Payment__c
      WHERE Status__c = 'Paid'
    ];
    d.membershipRevenue = revenue[0].get('total') == null
      ? 0
      : (Decimal) revenue[0].get('total');
    d.recentLoans = [
      SELECT
        Id,
        Name,
        Member__r.Name,
        Book_Copy__r.Name,
        Book_Copy__r.Book__r.Name,
        Borrow_Date__c,
        Due_Date__c,
        Return_Date__c,
        Status__c
      FROM Borrow_Record__c
      ORDER BY Borrow_Date__c DESC
      LIMIT 10
    ];
    d.registrations = [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Requested_Plan__r.Name,
        Registration_Date__c,
        Status__c,
        Provisioning_State__c
      FROM Library_Registration__c
      WHERE Status__c = 'Pending'
      ORDER BY Registration_Date__c ASC
      LIMIT 10
    ];
    d.readyReservations = [
      SELECT
        Id,
        Name,
        Member__r.Name,
        Book__r.Name,
        Ready_Date__c,
        Expiry_Date__c
      FROM Reservation__c
      WHERE Status__c = 'Ready'
      ORDER BY Ready_Date__c ASC
      LIMIT 10
    ];
    return d;
  }

  @AuraEnabled(cacheable=false)
  public static LibraryDataCloudService.LibrarianAnalyticsDTO getDashboardAnalytics() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    return LibraryDataCloudService.getRealtimeLibrarianAnalytics();
  }
  @AuraEnabled(cacheable=true)
  public static List<Book__c> searchBooks(
    String searchTerm,
    String categoryId,
    String status,
    Integer pageSize,
    Integer pageNumber
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Integer size = pageSize == null ||
      pageSize < 1 ||
      pageSize > 100
      ? 25
      : pageSize;
    Integer offsetValue = pageNumber == null ||
      pageNumber < 1
      ? 0
      : (pageNumber - 1) * size;
    String term = String.isBlank(searchTerm)
      ? null
      : '%' + searchTerm.trim() + '%';
    String q = 'SELECT Id,Name,ISBN__c,Publisher__c,Publication_Year__c,Edition__c,Language__c,Total_Copies__c,Available_Copies__c,Status__c,(SELECT Author__r.Name FROM Book_Authors__r),(SELECT Book_Category__r.Name FROM Book_Category_Links__r) FROM Book__c';
    List<String> clauses = new List<String>();
    if (term != null)
      clauses.add(
        '(Name LIKE :term OR ISBN__c LIKE :term OR Publisher__c LIKE :term)'
      );
    if (!String.isBlank(status))
      clauses.add('Status__c=:status');
    if (!String.isBlank(categoryId))
      clauses.add(
        'Id IN (SELECT Book__c FROM Book_Category_Link__c WHERE Book_Category__c=:categoryId)'
      );
    if (!clauses.isEmpty())
      q += ' WHERE ' + String.join(clauses, ' AND ');
    q += ' ORDER BY Name LIMIT :size OFFSET :offsetValue';
    return Database.query(q);
  }
  @AuraEnabled(cacheable=true)
  public static List<Author__c> getAuthors() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    return [SELECT Id, Name FROM Author__c ORDER BY Name LIMIT 500];
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Category__c> getCategories() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    return [
      SELECT Id, Name
      FROM Book_Category__c
      WHERE Active__c = TRUE
      ORDER BY Name
      LIMIT 500
    ];
  }
  @AuraEnabled(cacheable=true)
  public static Book__c getBookDetail(Id bookId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    return [
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
        (SELECT Id, Author__c, Author__r.Name FROM Book_Authors__r),
        (
          SELECT Id, Book_Category__c, Book_Category__r.Name
          FROM Book_Category_Links__r
        ),
        (
          SELECT
            Id,
            Name,
            Barcode__c,
            Status__c,
            Shelf_Location__c,
            Acquisition_Date__c,
            Condition__c,
            Price__c
          FROM Book_Copies__r
          ORDER BY Name
        )
      FROM Book__c
      WHERE Id = :bookId
    ];
  }
  @AuraEnabled(cacheable=true)
  public static List<Member__c> searchMembers(
    String searchTerm,
    String status
  ) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    String term = String.isBlank(searchTerm)
      ? null
      : '%' + searchTerm.trim() + '%';
    String q = 'SELECT Id,Name,First_Name__c,Last_Name__c,Email__c,Phone__c,Membership_Plan__c,Membership_Plan__r.Name,Registration_Date__c,Membership_Start_Date__c,Membership_End_Date__c,Status__c,Account_Status__c FROM Member__c';
    List<String> clauses = new List<String>();
    if (term != null)
      clauses.add(
        '(Name LIKE :term OR First_Name__c LIKE :term OR Last_Name__c LIKE :term OR Email__c LIKE :term OR Phone__c LIKE :term)'
      );
    if (!String.isBlank(status))
      clauses.add('Status__c=:status');
    if (!clauses.isEmpty())
      q += ' WHERE ' + String.join(clauses, ' AND ');
    q += ' ORDER BY Last_Name__c LIMIT 100';
    return Database.query(q);
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Copy__c> getAvailableCopies(Id bookId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    return [
      SELECT
        Id,
        Name,
        Barcode__c,
        Status__c,
        Shelf_Location__c,
        Condition__c,
        Book__r.Name
      FROM Book_Copy__c
      WHERE Book__c = :bookId AND Status__c = 'Available'
      ORDER BY Name
      LIMIT 100
    ];
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Copy__c> searchCopies(
    String searchTerm,
    String status,
    Id bookId,
    Integer pageSize,
    Integer pageNumber
  ) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Integer size = pageSize;
    if (size == null || size < 1 || size > 50)
      size = 11;
    Integer off = 0;
    if (pageNumber != null && pageNumber > 1)
      off = (pageNumber - 1) * 10;
    String term = String.isBlank(searchTerm)
      ? null
      : '%' + searchTerm.trim() + '%';
    String q = 'SELECT Id,Name,Barcode__c,Status__c,Shelf_Location__c,Condition__c,Acquisition_Date__c,Price__c,Book__c,Book__r.Name FROM Book_Copy__c';
    List<String> clauses = new List<String>();
    if (term != null)
      clauses.add(
        '(Name LIKE :term OR Barcode__c LIKE :term OR Book__r.Name LIKE :term)'
      );
    if (!String.isBlank(status))
      clauses.add('Status__c=:status');
    if (bookId != null)
      clauses.add('Book__c=:bookId');
    if (!clauses.isEmpty())
      q += ' WHERE ' + String.join(clauses, ' AND ');
    q += ' ORDER BY Name LIMIT :size OFFSET :off';
    return Database.query(q);
  }
  @AuraEnabled
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
    return LibraryCatalogService.addBook(
      title,
      isbn,
      publisher,
      publicationYear,
      edition,
      language,
      description,
      coverUrl,
      authorIds,
      categoryIds
    );
  }
  @AuraEnabled
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
    LibraryCatalogService.updateBook(
      bookId,
      title,
      isbn,
      publisher,
      publicationYear,
      edition,
      language,
      description,
      coverUrl,
      authorIds,
      categoryIds
    );
  }
  @AuraEnabled
  public static Id addCopy(
    Id bookId,
    String barcode,
    String shelf,
    Date acquisitionDate,
    String condition,
    Decimal price
  ) {
    return LibraryCatalogService.addCopy(
      bookId,
      barcode,
      shelf,
      acquisitionDate,
      condition,
      price
    );
  }
  @AuraEnabled
  public static void updateCopy(
    Id copyId,
    String shelf,
    Date acquisitionDate,
    String condition,
    Decimal price,
    String status
  ) {
    LibraryCatalogService.updateCopy(
      copyId,
      shelf,
      acquisitionDate,
      condition,
      price,
      status
    );
  }
  @AuraEnabled
  public static Id addMember(
    String firstName,
    String lastName,
    String email,
    String phone,
    Id planId
  ) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    validateMemberInput(firstName, lastName, email, planId, null);
    Membership_Plan__c plan = activePlan(planId);
    Contact contact = new Contact(
      FirstName = firstName.trim(),
      LastName = lastName.trim(),
      Email = email.trim(),
      Phone = phone
    );
    Database.insert(contact, AccessLevel.SYSTEM_MODE);
    Integer duration = plan.Duration_Days__c == null
      ? 0
      : Integer.valueOf(plan.Duration_Days__c);
    Member__c member = new Member__c(
      First_Name__c = firstName.trim(),
      Last_Name__c = lastName.trim(),
      Email__c = email.trim(),
      Normalized_Email__c = email.trim().toLowerCase(),
      Phone__c = phone,
      Contact__c = contact.Id,
      Membership_Plan__c = plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(duration),
      Max_Borrow_Limit__c = plan.Borrow_Limit__c,
      Status__c = 'Active',
      Account_Status__c = 'Pending'
    );
    Database.insert(member, AccessLevel.SYSTEM_MODE);
    return member.Id;
  }
  @AuraEnabled
  public static Id updateMember(
    Id memberId,
    String firstName,
    String lastName,
    String email,
    String phone,
    Id planId
  ) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    validateMemberInput(firstName, lastName, email, planId, memberId);
    Membership_Plan__c plan = activePlan(planId);
    Member__c existing = [
      SELECT Id, Contact__c
      FROM Member__c
      WHERE Id = :memberId
      FOR UPDATE
    ];
    if (existing.Contact__c != null) {
      Database.update(
        new Contact(
          Id = existing.Contact__c,
          FirstName = firstName.trim(),
          LastName = lastName.trim(),
          Email = email.trim(),
          Phone = phone
        ),
        AccessLevel.SYSTEM_MODE
      );
    }
    Database.update(
      new Member__c(
        Id = memberId,
        First_Name__c = firstName.trim(),
        Last_Name__c = lastName.trim(),
        Email__c = email.trim(),
        Normalized_Email__c = email.trim().toLowerCase(),
        Phone__c = phone,
        Membership_Plan__c = plan.Id,
        Max_Borrow_Limit__c = plan.Borrow_Limit__c
      ),
      AccessLevel.SYSTEM_MODE
    );
    return memberId;
  }
  private static void validateMemberInput(
    String firstName,
    String lastName,
    String email,
    Id planId,
    Id excludedMemberId
  ) {
    if (
      String.isBlank(firstName) ||
      String.isBlank(lastName) ||
      String.isBlank(email) ||
      planId == null
    )
      throw new AuraHandledException(
        'First name, last name, email and membership plan are required.'
      );
    String normalizedEmail = email.trim().toLowerCase();
    Integer duplicates = excludedMemberId == null
      ? [
          SELECT COUNT()
          FROM Member__c
          WHERE Normalized_Email__c = :normalizedEmail
        ]
      : [
          SELECT COUNT()
          FROM Member__c
          WHERE
            Normalized_Email__c = :normalizedEmail
            AND Id != :excludedMemberId
        ];
    if (duplicates > 0)
      throw new AuraHandledException(
        'A member with this email already exists.'
      );
  }
  private static Membership_Plan__c activePlan(Id planId) {
    List<Membership_Plan__c> plans = [
      SELECT Id, Duration_Days__c, Borrow_Limit__c
      FROM Membership_Plan__c
      WHERE Id = :planId AND Active__c = TRUE
      LIMIT 1
    ];
    if (plans.isEmpty())
      throw new AuraHandledException('Select an active membership plan.');
    return plans[0];
  }
  @AuraEnabled
  public static void retireCopy(Id copyId) {
    LibraryCatalogService.retireCopy(copyId);
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Copy__c> getBookCopies(Id bookId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    return [
      SELECT
        Id,
        Name,
        Barcode__c,
        Status__c,
        Shelf_Location__c,
        Acquisition_Date__c,
        Condition__c,
        Price__c
      FROM Book_Copy__c
      WHERE Book__c = :bookId
      ORDER BY Name
      LIMIT 200
    ];
  }
  public static List<Library_Registration__c> getRegistrations() {
    return getRegistrations(null);
  }
  @AuraEnabled(cacheable=true)
  public static List<Library_Registration__c> getRegistrations(String status) {
    LibraryPolicyService.require('Manage_Library_Registrations');
    String q = 'SELECT Id,Name,First_Name__c,Last_Name__c,Email__c,Phone__c,Requested_Plan__r.Name,Registration_Date__c,Status__c,Provisioning_State__c FROM Library_Registration__c';
    if (!String.isBlank(status))
      q += ' WHERE Status__c=:status';
    q += ' ORDER BY Registration_Date__c DESC LIMIT 200';
    return Database.query(q);
  }
  @AuraEnabled
  public static void approveRegistration(Id registrationId) {
    LibraryRegistrationController.approveRegistration(registrationId);
  }
  @AuraEnabled
  public static void rejectRegistration(Id registrationId, String reason) {
    LibraryRegistrationController.rejectRegistration(registrationId, reason);
  }
  @AuraEnabled
  public static void retryProvisioning(Id registrationId) {
    LibraryRegistrationController.retryProvisioning(registrationId);
  }
  public static List<Reservation__c> getReservations() {
    return getReservations(null);
  }
  @AuraEnabled(cacheable=true)
  public static List<Reservation__c> getReservations(String status) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    String q = 'SELECT Id,Name,Member__c,Member__r.Name,Book__c,Book__r.Name,Book_Copy__c,Book_Copy__r.Name,Reservation_Date__c,Queue_Position__c,Status__c,Ready_Date__c,Expiry_Date__c,Fulfilled_Date__c FROM Reservation__c';
    if (!String.isBlank(status))
      q += ' WHERE Status__c=:status';
    q += ' ORDER BY Reservation_Date__c DESC LIMIT 200';
    return Database.query(q);
  }
  public static List<Fine__c> getFines() {
    return getFines(null);
  }
  @AuraEnabled(cacheable=true)
  public static List<Fine__c> getFines(String status) {
    LibraryPolicyService.require('Manage_Library_Fines');
    String q = 'SELECT Id,Name,Member__r.Name,Borrow_Record__r.Name,Fine_Type__c,Amount__c,Paid_Amount__c,Balance__c,Status__c,Generated_Date__c,Paid_Date__c FROM Fine__c';
    if (!String.isBlank(status))
      q += ' WHERE Status__c=:status';
    q += ' ORDER BY Generated_Date__c DESC LIMIT 200';
    return Database.query(q);
  }
  @AuraEnabled(cacheable=true)
  public static MemberDetail getMemberDetail(Id memberId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    MemberDetail d = new MemberDetail();
    d.member = [
      SELECT
        Id,
        Name,
        First_Name__c,
        Last_Name__c,
        Email__c,
        Phone__c,
        User__c,
        Membership_Plan__c,
        Membership_Plan__r.Name,
        Registration_Date__c,
        Membership_Start_Date__c,
        Membership_End_Date__c,
        Status__c,
        Account_Status__c
      FROM Member__c
      WHERE Id = :memberId
    ];
    d.loans = [
      SELECT
        Id,
        Name,
        Book_Copy__r.Name,
        Book_Copy__r.Book__r.Name,
        Borrow_Date__c,
        Due_Date__c,
        Return_Date__c,
        Status__c,
        Renewal_Count__c
      FROM Borrow_Record__c
      WHERE Member__c = :memberId
      ORDER BY Borrow_Date__c DESC
      LIMIT 100
    ];
    d.reservations = [
      SELECT
        Id,
        Name,
        Book__r.Name,
        Status__c,
        Reservation_Date__c,
        Queue_Position__c,
        Ready_Date__c,
        Expiry_Date__c,
        Fulfilled_Date__c
      FROM Reservation__c
      WHERE Member__c = :memberId
      ORDER BY Reservation_Date__c DESC
      LIMIT 100
    ];
    d.fines = [
      SELECT
        Id,
        Name,
        Fine_Type__c,
        Amount__c,
        Paid_Amount__c,
        Balance__c,
        Status__c,
        Generated_Date__c
      FROM Fine__c
      WHERE Member__c = :memberId
      ORDER BY Generated_Date__c DESC
      LIMIT 100
    ];
    d.payments = [
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
      WHERE Member__c = :memberId
      ORDER BY Payment_Date__c DESC
      LIMIT 100
    ];
    d.outstandingBalance = 0;
    for (Fine__c f : d.fines)
      if (f.Status__c == 'Unpaid' || f.Status__c == 'Partially Paid')
        d.outstandingBalance += (f.Balance__c == null ? 0 : f.Balance__c);
    return d;
  }
  @AuraEnabled
  public static void setMemberAccountStatus(Id memberId, String accountStatus) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Set<String> allowed = new Set<String>{ 'Active', 'Suspended', 'Inactive' };
    if (memberId == null || !allowed.contains(accountStatus))
      throw new AuraHandledException(
        'Select a member and a valid account status.'
      );
    Member__c member = [
      SELECT Id, External_Auth_Id__c, Email_Verified__c
      FROM Member__c
      WHERE Id = :memberId
      FOR UPDATE
    ];
    if (
      accountStatus == 'Active' &&
      (String.isBlank(member.External_Auth_Id__c) ||
      member.Email_Verified__c != true)
    )
      throw new AuraHandledException(
        'Only a verified external identity can be activated.'
      );
    Database.update(
      new Member__c(Id = member.Id, Account_Status__c = accountStatus),
      AccessLevel.SYSTEM_MODE
    );
  }
  @AuraEnabled
  public static Id renewMemberMembership(Id memberId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    return LibraryMembershipPaymentService.renewMembership(memberId);
  }
  @AuraEnabled
  public static void resetMemberPassword(Id memberId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    List<Member__c> members = [
      SELECT Id, User__c
      FROM Member__c
      WHERE Id = :memberId
      LIMIT 1
    ];
    if (members.isEmpty() || members[0].User__c == null)
      throw new AuraHandledException(
        'This member does not have an active portal user account.'
      );
    System.resetPassword(members[0].User__c, true);
  }
  @AuraEnabled
  public static Id checkout(Id memberId, Id copyId) {
    return LibraryCirculationService.checkout(memberId, copyId);
  }
  @AuraEnabled
  public static void approveBorrowRequest(Id loanId) {
    LibraryCirculationService.approveBorrowRequest(loanId);
  }
  @AuraEnabled
  public static void rejectBorrowRequest(Id loanId, String reason) {
    LibraryCirculationService.rejectBorrowRequest(loanId, reason);
  }
  @AuraEnabled
  public static Id issueReservedBook(Id reservationId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    List<Reservation__c> reservations = [
      SELECT Id, Member__c, Book_Copy__c, Status__c
      FROM Reservation__c
      WHERE Id = :reservationId
      LIMIT 1
    ];
    if (
      reservations.isEmpty() ||
      reservations[0].Status__c != 'Ready' ||
      reservations[0].Book_Copy__c == null
    )
      throw new AuraHandledException(
        'Only a ready reservation with an assigned copy can be issued.'
      );
    return LibraryCirculationService.checkout(
      reservations[0].Member__c,
      reservations[0].Book_Copy__c
    );
  }
  @AuraEnabled
  public static Boolean prepareReservation(Id reservationId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    return LibraryReservationWorkflowService.prepareReservation(reservationId);
  }
  @AuraEnabled
  public static void returnLoan(Id loanId) {
    LibraryCirculationService.returnLoan(loanId);
  }
  @AuraEnabled
  public static void renewLoan(Id loanId) {
    LibraryCirculationService.renewLoan(loanId);
  }
  @AuraEnabled
  public static void reportDefectiveCopy(Id loanId, String notes) {
    LibraryCirculationService.reportDefectiveCopy(loanId, notes);
  }
  @AuraEnabled
  public static void replaceDefectiveCopy(Id loanId, Id replacementCopyId) {
    LibraryCirculationService.replaceDefectiveCopy(loanId, replacementCopyId);
  }
  @AuraEnabled
  public static void recordFinePayment(Id fineId, Decimal amount) {
    LibraryCirculationService.recordFinePayment(fineId, amount);
  }
  @AuraEnabled
  public static void waiveFine(Id fineId, String reason) {
    LibraryCirculationService.waiveFine(fineId, reason);
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Copy__c> getReplacementOptions(Id loanId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    List<Borrow_Record__c> loans = [
      SELECT Book_Copy__r.Book__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
      LIMIT 1
    ];
    if (loans.isEmpty() || loans[0].Book_Copy__r == null)
      throw new AuraHandledException(
        'The loan or source book could not be found.'
      );
    return [
      SELECT Id, Name, Barcode__c, Shelf_Location__c, Condition__c
      FROM Book_Copy__c
      WHERE Book__c = :loans[0].Book_Copy__r.Book__c AND Status__c = 'Available'
      ORDER BY Name
      LIMIT 100
    ];
  }
  @AuraEnabled(cacheable=true)
  public static List<Membership_Plan__c> getMembershipPlans() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    return [
      SELECT
        Id,
        Name,
        Description__c,
        Duration_Days__c,
        Borrow_Limit__c,
        Loan_Duration_Days__c,
        Reservation_Limit__c,
        Renewal_Limit__c,
        Fine_Per_Day__c,
        Fee__c,
        Active__c
      FROM Membership_Plan__c
      ORDER BY Fee__c
      LIMIT 200
    ];
  }
  @AuraEnabled
  public static Id saveMembershipPlan(
    Id planId,
    String name,
    String description,
    Decimal durationDays,
    Decimal borrowLimit,
    Decimal loanDurationDays,
    Decimal reservationLimit,
    Decimal renewalLimit,
    Decimal finePerDay,
    Decimal fee,
    Boolean active
  ) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    if (
      String.isBlank(name) ||
      durationDays == null ||
      durationDays <= 0 ||
      borrowLimit == null ||
      borrowLimit <= 0 ||
      fee == null ||
      fee < 0
    )
      throw new AuraHandledException(
        'Plan name, positive duration, positive borrow limit and a valid price are required.'
      );
    Membership_Plan__c plan = new Membership_Plan__c(
      Id = planId,
      Name = name.trim(),
      Description__c = description,
      Duration_Days__c = durationDays,
      Borrow_Limit__c = borrowLimit,
      Loan_Duration_Days__c = loanDurationDays,
      Reservation_Limit__c = reservationLimit,
      Renewal_Limit__c = renewalLimit,
      Fine_Per_Day__c = finePerDay,
      Fee__c = fee,
      Active__c = active == null ? true : active
    );
    Database.upsert(plan, AccessLevel.SYSTEM_MODE);
    return plan.Id;
  }
  @AuraEnabled(cacheable=true)
  public static List<PaymentRow> getPayments(String status) {
    LibraryPolicyService.require('Manage_Library_Fines');
    String q = 'SELECT Id,Name,Member__r.Name,Previous_Plan__r.Name,New_Plan__r.Name,Amount__c,Status__c,Payment_Method__c,Payment_Date__c,Transaction_Reference__c,Reconciliation_Status__c FROM Membership_Payment__c';
    if (!String.isBlank(status))
      q += ' WHERE Status__c=:status';
    q += ' ORDER BY Payment_Date__c DESC LIMIT 200';
    List<PaymentRow> result = new List<PaymentRow>();
    for (
      Membership_Payment__c payment : (List<Membership_Payment__c>) Database.query(
        q
      )
    ) {
      PaymentRow row = new PaymentRow();
      row.id = payment.Id;
      row.name = payment.Name;
      row.memberName = payment.Member__r == null ? '—' : payment.Member__r.Name;
      row.paymentType = 'Membership';
      row.amount = payment.Amount__c;
      row.paymentDate = payment.Payment_Date__c;
      row.status = payment.Status__c;
      row.reference = payment.Transaction_Reference__c;
      result.add(row);
    }
    String fineQuery = 'SELECT Id,Name,Member__r.Name,Paid_Amount__c,Paid_Date__c,Status__c,Borrow_Record__r.Name FROM Fine__c WHERE Paid_Amount__c > 0';
    if (!String.isBlank(status))
      fineQuery += ' AND Status__c=:status';
    fineQuery += ' ORDER BY Paid_Date__c DESC LIMIT 200';
    for (Fine__c fine : (List<Fine__c>) Database.query(fineQuery)) {
      PaymentRow row = new PaymentRow();
      row.id = fine.Id;
      row.name = fine.Name;
      row.memberName = fine.Member__r == null ? '—' : fine.Member__r.Name;
      row.paymentType = 'Fine';
      row.amount = fine.Paid_Amount__c;
      row.paymentDate = fine.Paid_Date__c == null
        ? null
        : Datetime.newInstance(fine.Paid_Date__c, Time.newInstance(0, 0, 0, 0));
      row.status = fine.Status__c;
      row.reference = fine.Borrow_Record__r == null
        ? null
        : fine.Borrow_Record__r.Name;
      result.add(row);
    }
    return result;
  }
  @AuraEnabled(cacheable=true)
  public static List<Borrow_Record__c> getLoans(String status) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    String q = 'SELECT Id,Name,Member__r.Name,Book_Copy__r.Name,Book_Copy__r.Book__r.Name,Borrow_Date__c,Due_Date__c,Return_Date__c,Status__c,Renewal_Count__c FROM Borrow_Record__c';
    if (!String.isBlank(status))
      q += ' WHERE Status__c=:status';
    q += ' ORDER BY Borrow_Date__c DESC LIMIT 200';
    return Database.query(q);
  }
  @AuraEnabled
  public static Id createReservation(Id memberId, Id bookId) {
    Id reservationId = LibraryCirculationService.createReservation(
      memberId,
      bookId
    );
    LibraryReservationWorkflowService.promoteAvailableReservations(bookId);
    return reservationId;
  }
  @AuraEnabled
  public static void cancelReservation(Id reservationId) {
    LibraryCirculationService.cancelReservation(reservationId);
  }
  @AuraEnabled
  public static Integer processExpiredReservations() {
    return LibraryCirculationService.processExpiredReservations();
  }
}
