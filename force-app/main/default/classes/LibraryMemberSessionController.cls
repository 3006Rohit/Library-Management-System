public without sharing class LibraryMemberSessionController {
  public class LoanDTO {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String bookTitle { get; set; }
    @AuraEnabled
    public String coverUrl { get; set; }
    @AuraEnabled
    public String copyName { get; set; }
    @AuraEnabled
    public String barcode { get; set; }
    @AuraEnabled
    public Datetime borrowDate { get; set; }
    @AuraEnabled
    public Datetime dueDate { get; set; }
    @AuraEnabled
    public Datetime returnDate { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Decimal renewalCount { get; set; }
    @AuraEnabled
    public Boolean replacementRequired { get; set; }
  }
  public class ReservationDTO {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String bookName { get; set; }
    @AuraEnabled
    public String bookCopyName { get; set; }
    @AuraEnabled
    public Datetime reservationDate { get; set; }
    @AuraEnabled
    public Decimal queuePosition { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Datetime readyDate { get; set; }
    @AuraEnabled
    public Datetime expiryDate { get; set; }
    @AuraEnabled
    public Datetime fulfilledDate { get; set; }
  }
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
    public List<LoanDTO> recentLoans;
    @AuraEnabled
    public List<ReservationDTO> recentReservations;
  }
  private class RankedBook implements Comparable {
    Book__c book;
    Integer score;
    RankedBook(Book__c book, Integer score) {
      this.book = book;
      this.score = score;
    }
    public Integer compareTo(Object otherValue) {
      RankedBook other = (RankedBook) otherValue;
      if (score != other.score)
        return other.score - score;
      Decimal mine = book.Available_Copies__c == null
        ? 0
        : book.Available_Copies__c;
      Decimal theirs = other.book.Available_Copies__c == null
        ? 0
        : other.book.Available_Copies__c;
      if (mine != theirs)
        return mine > theirs ? -1 : 1;
      return book.Name.toLowerCase().compareTo(other.book.Name.toLowerCase());
    }
  }
  private static Member__c member(String token) {
    return LibraryMemberSessionService.browserMember(
      LibraryMemberSessionService.getCurrentMember(token)
    );
  }
  private static List<LoanDTO> loanDtos(List<Borrow_Record__c> rows) {
    // This controller is already authenticated by a server-side member
    // session. The SOQL projection above is the browser allowlist; applying
    // stripInaccessible here throws "No access to entity" for Experience
    // Cloud guest contexts before the allowlisted response can be returned.
    List<LoanDTO> results = new List<LoanDTO>();
    for (Borrow_Record__c row : rows) {
      LoanDTO result = new LoanDTO();
      result.id = row.Id;
      result.name = row.Name;
      result.copyName = row.Book_Copy__r == null ? null : row.Book_Copy__r.Name;
      result.barcode = row.Book_Copy__r == null
        ? null
        : row.Book_Copy__r.Barcode__c;
      result.bookTitle = row.Book_Copy__r == null ||
        row.Book_Copy__r.Book__r == null
        ? null
        : row.Book_Copy__r.Book__r.Name;
      result.coverUrl = row.Book_Copy__r == null ||
        row.Book_Copy__r.Book__r == null
        ? null
        : row.Book_Copy__r.Book__r.Cover_Image_URL__c;
      result.borrowDate = row.Borrow_Date__c;
      result.dueDate = row.Due_Date__c;
      result.returnDate = row.Return_Date__c;
      result.status = row.Status__c;
      result.renewalCount = row.Renewal_Count__c;
      result.replacementRequired = row.Replacement_Required__c;
      results.add(result);
    }
    return results;
  }
  private static List<ReservationDTO> reservationDtos(
    List<Reservation__c> rows
  ) {
    List<ReservationDTO> results = new List<ReservationDTO>();
    for (Reservation__c row : rows) {
      ReservationDTO result = new ReservationDTO();
      result.id = row.Id;
      result.name = row.Name;
      result.bookName = row.Book__r == null ? null : row.Book__r.Name;
      result.bookCopyName = row.Book_Copy__r == null
        ? null
        : row.Book_Copy__r.Name;
      result.reservationDate = row.Reservation_Date__c;
      result.queuePosition = row.Queue_Position__c;
      result.status = row.Status__c;
      result.readyDate = row.Ready_Date__c;
      result.expiryDate = row.Expiry_Date__c;
      result.fulfilledDate = row.Fulfilled_Date__c;
      results.add(result);
    }
    return results;
  }
  private static List<Fine__c> readableFines(List<Fine__c> rows) {
    return rows;
  }
  private static List<Membership_Payment__c> readablePayments(
    List<Membership_Payment__c> rows
  ) {
    return rows;
  }
  private static List<Member_Notification__c> readableNotifications(
    List<Member_Notification__c> rows
  ) {
    return rows;
  }
  private static List<Book_Category__c> readableCategories(
    List<Book_Category__c> rows
  ) {
    return rows;
  }
  private static List<Book__c> readableBooks(List<Book__c> rows) {
    return rows;
  }
  @AuraEnabled(cacheable=true)
  public static Member__c getCurrentMemberContext(String sessionToken) {
    return member(sessionToken);
  }
  @AuraEnabled
  public static DashboardData getMyDashboard(String sessionToken) {
    Member__c m = member(sessionToken);
    DateTime now = System.now();
    DateTime soon = now.addDays(3);
    DashboardData d = new DashboardData();
    d.member = m;
    d.activeLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Member__c = :m.Id AND Return_Date__c = NULL
    ];
    d.overdueLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Member__c = :m.Id AND Return_Date__c = NULL AND Due_Date__c < :now
    ];
    d.dueSoon = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE
        Member__c = :m.Id
        AND Return_Date__c = NULL
        AND Due_Date__c >= :now
        AND Due_Date__c <= :soon
    ];
    d.activeReservations = systemReservationCount(
      'SELECT COUNT(Id) total FROM Reservation__c ' +
      'WHERE Member__c = :memberId AND Status__c IN (\'Pending\', \'Ready\')',
      new Map<String, Object>{ 'memberId' => m.Id }
    );
    List<AggregateResult> totals = [
      SELECT SUM(Balance__c) total
      FROM Fine__c
      WHERE Member__c = :m.Id AND Status__c IN ('Unpaid', 'Partially Paid')
    ];
    d.outstandingFine = totals.isEmpty() || totals[0].get('total') == null
      ? 0
      : (Decimal) totals[0].get('total');
    d.recentLoans = loanDtos(
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
          Renewal_Count__c,
          Replacement_Required__c
        FROM Borrow_Record__c
        WHERE Member__c = :m.Id
        ORDER BY Borrow_Date__c DESC
        LIMIT 5
      ]
    );
    d.recentReservations = reservationDtos(
      systemReservations(
        'SELECT Id, Name, Book__r.Name, Book_Copy__r.Name, Reservation_Date__c, ' +
          'Queue_Position__c, Status__c, Ready_Date__c, Expiry_Date__c, Fulfilled_Date__c ' +
          'FROM Reservation__c WHERE Member__c = :memberId ' +
          'ORDER BY Reservation_Date__c DESC LIMIT 5',
        new Map<String, Object>{ 'memberId' => m.Id }
      )
    );
    return d;
  }
  @AuraEnabled
  public static LibraryDataCloudService.MemberAnalyticsDTO getMyAnalytics(
    String sessionToken
  ) {
    Member__c m = member(sessionToken);
    LibraryDataCloudService.MemberAnalyticsDTO result = new LibraryDataCloudService.MemberAnalyticsDTO();
    result.available = true;
    result.message = null;
    result.refreshCadence = 'Real-time Salesforce transaction data';
    result.lastUpdated = System.now();
    DateTime nowValue = System.now();
    Map<String, Object> memberBind = new Map<String, Object>{
      'memberId' => m.Id
    };
    result.totalLoans = systemCount(
      'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId',
      memberBind
    );
    result.activeLoans = systemCount(
      'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId AND Return_Date__c = NULL',
      memberBind
    );
    result.returnedLoans = systemCount(
      'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId AND Return_Date__c != NULL',
      memberBind
    );
    result.overdueLoans = systemCount(
      'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId AND Return_Date__c = NULL AND Due_Date__c < :nowValue',
      new Map<String, Object>{ 'memberId' => m.Id, 'nowValue' => nowValue }
    );
    result.totalReservations = systemCount(
      'SELECT COUNT(Id) total FROM Reservation__c WHERE Member__c = :memberId',
      memberBind
    );
    result.activeReservationCount = systemCount(
      'SELECT COUNT(Id) total FROM Reservation__c WHERE Member__c = :memberId AND Status__c IN (\'Pending\', \'Ready\')',
      memberBind
    );
    result.fulfilledReservations = systemCount(
      'SELECT COUNT(Id) total FROM Reservation__c WHERE Member__c = :memberId AND Status__c = \'Fulfilled\'',
      memberBind
    );
    result.totalFineCount = systemCount(
      'SELECT COUNT(Id) total FROM Fine__c WHERE Member__c = :memberId',
      memberBind
    );
    result.unpaidFineCount = systemCount(
      'SELECT COUNT(Id) total FROM Fine__c WHERE Member__c = :memberId AND Status__c IN (\'Unpaid\', \'Partially Paid\')',
      memberBind
    );
    return result;
  }

  @AuraEnabled
  public static List<Book__c> getSuggestedBooks(String sessionToken) {
    Member__c m = member(sessionToken);
    Set<Id> borrowedBookIds = new Set<Id>();
    Set<Id> recentBorrowedBookIds = new Set<Id>();
    for (Borrow_Record__c loan : [
      SELECT Book_Copy__r.Book__c, Borrow_Date__c
      FROM Borrow_Record__c
      WHERE Member__c = :m.Id AND Book_Copy__r.Book__c != NULL
      ORDER BY Borrow_Date__c DESC NULLS LAST
      LIMIT 20
    ]) {
      borrowedBookIds.add(loan.Book_Copy__r.Book__c);
      recentBorrowedBookIds.add(loan.Book_Copy__r.Book__c);
    }

    Set<Id> preferredCategoryIds = new Set<Id>();
    Set<Id> recentCategoryIds = new Set<Id>();
    Set<Id> preferredAuthorIds = new Set<Id>();
    if (!borrowedBookIds.isEmpty()) {
      for (Book_Category_Link__c link : [
        SELECT Book_Category__c
        FROM Book_Category_Link__c
        WHERE Book__c IN :borrowedBookIds
      ])
        preferredCategoryIds.add(link.Book_Category__c);
      for (Book_Category_Link__c link : [
        SELECT Book_Category__c
        FROM Book_Category_Link__c
        WHERE Book__c IN :recentBorrowedBookIds
      ])
        recentCategoryIds.add(link.Book_Category__c);
      for (Book_Author__c link : [
        SELECT Author__c
        FROM Book_Author__c
        WHERE Book__c IN :borrowedBookIds
      ])
        preferredAuthorIds.add(link.Author__c);
    }

    List<String> interests = new List<String>();
    if (!String.isBlank(m.Interests__c)) {
      for (String value : m.Interests__c.toLowerCase().split('[,;|]')) {
        String cleaned = value.trim();
        if (cleaned.length() >= 2)
          interests.add(cleaned);
      }
    }
    List<Book__c> candidates = [
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
        (SELECT Author__c, Author__r.Name FROM Book_Authors__r),
        (
          SELECT Book_Category__c, Book_Category__r.Name
          FROM Book_Category_Links__r
        )
      FROM Book__c
      WHERE Status__c = 'Active' AND Id NOT IN :borrowedBookIds
      ORDER BY Available_Copies__c DESC NULLS LAST, Name
      LIMIT 200
    ];
    List<RankedBook> ranked = new List<RankedBook>();
    for (Book__c candidate : candidates) {
      Integer score = 0;
      String searchable = (candidate.Name +
        ' ' +
        (candidate.Description__c == null ? '' : candidate.Description__c))
        .toLowerCase();
      for (Book_Author__c link : candidate.Book_Authors__r) {
        if (preferredAuthorIds.contains(link.Author__c))
          score += 3;
        if (link.Author__r != null)
          searchable += ' ' + link.Author__r.Name.toLowerCase();
      }
      for (Book_Category_Link__c link : candidate.Book_Category_Links__r) {
        if (recentCategoryIds.contains(link.Book_Category__c))
          score += 8;
        if (preferredCategoryIds.contains(link.Book_Category__c))
          score += 5;
        if (link.Book_Category__r != null)
          searchable += ' ' + link.Book_Category__r.Name.toLowerCase();
      }
      for (String interest : interests)
        if (searchable.contains(interest))
          score += 4;
      ranked.add(new RankedBook(candidate, score));
    }
    ranked.sort();
    List<Book__c> suggestions = new List<Book__c>();
    for (RankedBook row : ranked) {
      suggestions.add(row.book);
      if (suggestions.size() == 4)
        break;
    }
    return suggestions;
  }
  @AuraEnabled(cacheable=true)
  public static List<Book_Category__c> getCatalogCategories(
    String sessionToken
  ) {
    member(sessionToken);
    return readableCategories(
      [
        SELECT Id, Name, Description__c
        FROM Book_Category__c
        WHERE Active__c = TRUE
        ORDER BY Name
        LIMIT 100
      ]
    );
  }
  @AuraEnabled
  public static List<Book__c> searchCatalog(
    String sessionToken,
    String searchTerm,
    String categoryId,
    String availability,
    Integer pageSize,
    Integer pageNumber
  ) {
    member(sessionToken);
    Integer size = pageSize == null ||
      pageSize < 1 ||
      pageSize > 50
      ? 20
      : pageSize;
    Integer off = pageNumber == null ||
      pageNumber < 1
      ? 0
      : (pageNumber - 1) * size;
    String term = String.isBlank(searchTerm)
      ? null
      : '%' + searchTerm.trim() + '%';
    String q = 'SELECT Id,Name,ISBN__c,Publisher__c,Publication_Year__c,Edition__c,Language__c,Description__c,Cover_Image_URL__c,Total_Copies__c,Available_Copies__c,Status__c,(SELECT Author__r.Name FROM Book_Authors__r),(SELECT Book_Category__r.Name FROM Book_Category_Links__r) FROM Book__c';
    List<String> c = new List<String>();
    if (term != null)
      c.add('(Name LIKE :term OR ISBN__c LIKE :term)');
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
    return readableBooks((List<Book__c>) Database.query(q));
  }
  @AuraEnabled
  public static List<LoanDTO> getMyBorrowings(String sessionToken) {
    Member__c m = member(sessionToken);
    return loanDtos(
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
          Renewal_Count__c,
          Replacement_Required__c
        FROM Borrow_Record__c
        WHERE Member__c = :m.Id
        ORDER BY Borrow_Date__c DESC
        LIMIT 200
      ]
    );
  }
  @AuraEnabled
  public static List<ReservationDTO> getMyReservations(String sessionToken) {
    Member__c m = member(sessionToken);
    return reservationDtos(
      systemReservations(
        'SELECT Id, Name, Book__r.Name, Book_Copy__r.Name, Reservation_Date__c, ' +
          'Queue_Position__c, Status__c, Ready_Date__c, Expiry_Date__c, Fulfilled_Date__c ' +
          'FROM Reservation__c WHERE Member__c = :memberId ' +
          'ORDER BY Reservation_Date__c DESC LIMIT 200',
        new Map<String, Object>{ 'memberId' => m.Id }
      )
    );
  }
  @AuraEnabled
  public static List<Fine__c> getMyFines(String sessionToken) {
    Member__c m = member(sessionToken);
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
        WHERE Member__c = :m.Id
        ORDER BY Generated_Date__c DESC
        LIMIT 200
      ]
    );
  }
  @AuraEnabled
  public static List<Membership_Payment__c> getMyPayments(String sessionToken) {
    Member__c m = member(sessionToken);
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
        WHERE Member__c = :m.Id
        ORDER BY Payment_Date__c DESC
        LIMIT 100
      ]
    );
  }
  @AuraEnabled(cacheable=true)
  public static Member__c getMyProfile(String sessionToken) {
    return member(sessionToken);
  }
  @AuraEnabled(cacheable=true)
  public static Member__c getMyMembership(String sessionToken) {
    return member(sessionToken);
  }
  @AuraEnabled(cacheable=true)
  public static List<LibraryMembershipPaymentService.UpgradePlan> getUpgradePlans(
    String sessionToken
  ) {
    Member__c m = member(sessionToken);
    return LibraryMembershipPaymentService.getUpgradePlans(m.Id);
  }
  @AuraEnabled
  public static void updateMyProfile(
    String sessionToken,
    String firstName,
    String lastName,
    String phone,
    String address
  ) {
    Member__c m = member(sessionToken);
    update new Member__c(
      Id = m.Id,
      First_Name__c = firstName,
      Last_Name__c = lastName,
      Phone__c = phone,
      Address__c = address
    );
  }
  @AuraEnabled
  public static void renewMyLoan(String sessionToken, Id borrowRecordId) {
    Member__c m = member(sessionToken);
    LibraryCirculationService.renewLoanForMember(borrowRecordId, m.Id);
  }
  @AuraEnabled
  public static void reportDefectiveLoan(
    String sessionToken,
    Id borrowRecordId,
    String notes
  ) {
    Member__c m = member(sessionToken);
    LibraryCirculationService.reportDefectiveCopyForMember(
      borrowRecordId,
      m.Id,
      notes
    );
  }
  @AuraEnabled
  public static void cancelMyReservation(
    String sessionToken,
    Id reservationId
  ) {
    Member__c m = member(sessionToken);
    LibraryCirculationService.cancelReservationForMember(reservationId, m.Id);
  }
  @AuraEnabled
  public static Id reserveBook(String sessionToken, Id bookId) {
    Member__c m = member(sessionToken);
    Id id = LibraryCirculationService.createReservationForMember(m, bookId);
    LibraryReservationWorkflowService.promoteAvailableReservations(bookId);
    return id;
  }
  @AuraEnabled
  public static Id payForMembershipUpgrade(String sessionToken, Id planId) {
    Member__c m = member(sessionToken);
    return LibraryMembershipPaymentService.payAndUpgrade(m.Id, planId);
  }
  @AuraEnabled
  public static Id renewMyMembership(String sessionToken) {
    return LibraryMembershipPaymentService.renewMembership(
      member(sessionToken).Id
    );
  }
  @AuraEnabled
  public static List<Member_Notification__c> getMyNotifications(
    String sessionToken
  ) {
    Member__c m = member(sessionToken);
    return readableNotifications(
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
        WHERE Member__c = :m.Id
        ORDER BY CreatedDate DESC
        LIMIT 100
      ]
    );
  }
  @AuraEnabled
  public static void markNotificationRead(
    String sessionToken,
    Id notificationId
  ) {
    LibraryMemberNotificationService.markRead(
      notificationId,
      member(sessionToken).Id
    );
  }
  @AuraEnabled
  public static Book__c getBookDetails(String sessionToken, Id bookId) {
    member(sessionToken);
    return readableBooks(
      [
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
        LIMIT 1
      ]
    )[0];
  }
  @AuraEnabled
  public static Id borrowBook(String sessionToken, Id bookId) {
    Member__c m = member(sessionToken);
    if (bookId == null)
      throw new AuraHandledException('A book must be selected.');

    // Promote queued reservations before choosing a copy. This keeps the
    // member-facing availability state aligned with the reservation queue.
    LibraryReservationWorkflowService.promoteAvailableReservations(bookId);

    List<Reservation__c> readyReservations = systemReservations(
      'SELECT Book_Copy__c FROM Reservation__c ' +
        'WHERE Member__c = :memberId AND Book__c = :bookId ' +
        'AND Status__c = \'Ready\' AND Book_Copy__c != NULL ' +
        'ORDER BY Ready_Date__c LIMIT 1',
      new Map<String, Object>{ 'memberId' => m.Id, 'bookId' => bookId }
    );
    Id reservedCopyId = readyReservations.isEmpty()
      ? null
      : readyReservations[0].Book_Copy__c;
    List<Book_Copy__c> copies;
    if (reservedCopyId != null) {
      copies = [
        SELECT Id
        FROM Book_Copy__c
        WHERE Id = :reservedCopyId AND Status__c IN ('Available', 'Reserved')
        LIMIT 1
        FOR UPDATE
      ];
    } else {
      copies = [
        SELECT Id
        FROM Book_Copy__c
        WHERE Book__c = :bookId AND Status__c = 'Available'
        LIMIT 1
        FOR UPDATE
      ];
    }
    if (copies.isEmpty())
      throw new AuraHandledException(
        'No copy is currently available. Reserve this title to join the queue.'
      );
    return LibraryMemberBorrowService.request(m, bookId);
  }

  private static List<Reservation__c> systemReservations(
    String query,
    Map<String, Object> binds
  ) {
    return (List<Reservation__c>) Database.queryWithBinds(
      query,
      binds,
      AccessLevel.SYSTEM_MODE
    );
  }

  private static Integer systemReservationCount(
    String query,
    Map<String, Object> binds
  ) {
    List<AggregateResult> rows = (List<AggregateResult>) Database.queryWithBinds(
      query,
      binds,
      AccessLevel.SYSTEM_MODE
    );
    return rows.isEmpty() ? 0 : Integer.valueOf(rows[0].get('total'));
  }

  private static Integer systemCount(String query, Map<String, Object> binds) {
    List<AggregateResult> rows = (List<AggregateResult>) Database.queryWithBinds(
      query,
      binds,
      AccessLevel.SYSTEM_MODE
    );
    return rows.isEmpty() ? 0 : Integer.valueOf(rows[0].get('total'));
  }
}
