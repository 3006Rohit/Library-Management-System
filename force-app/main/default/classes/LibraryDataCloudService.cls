public with sharing class LibraryDataCloudService {
  public class CopyMetrics {
    @AuraEnabled
    public Decimal totalCopies;
    @AuraEnabled
    public Decimal availableCopies;
    @AuraEnabled
    public Decimal borrowedCopies;
    @AuraEnabled
    public Decimal reservedCopies;
    @AuraEnabled
    public Decimal lostCopies;
  }

  public class LoanMetrics {
    @AuraEnabled
    public Decimal totalLoans;
    @AuraEnabled
    public Decimal activeLoans;
    @AuraEnabled
    public Decimal returnedLoans;
    @AuraEnabled
    public Decimal overdueLoans;
  }

  public class ReservationMetrics {
    @AuraEnabled
    public Decimal totalReservations;
    @AuraEnabled
    public Decimal fulfilledReservations;
    @AuraEnabled
    public Decimal cancelledReservations;
    @AuraEnabled
    public Decimal pendingReservations;
    @AuraEnabled
    public Decimal readyReservations;
    @AuraEnabled
    public Decimal expiredReservations;
  }

  public class FineMetrics {
    @AuraEnabled
    public Decimal totalFineCount;
    @AuraEnabled
    public Decimal paidFineCount;
    @AuraEnabled
    public Decimal unpaidFineCount;
  }

  public class BookPopularityDTO {
    @AuraEnabled
    public String bookId;
    @AuraEnabled
    public Decimal borrowCount;
    @AuraEnabled
    public Decimal activeBorrowCount;
    @AuraEnabled
    public Decimal returnedBorrowCount;
    @AuraEnabled
    public String bookName;
  }

  public class ReservationDemandDTO {
    @AuraEnabled
    public String bookId;
    @AuraEnabled
    public Decimal totalReservations;
    @AuraEnabled
    public Decimal fulfilled;
    @AuraEnabled
    public Decimal cancelled;
    @AuraEnabled
    public Decimal pending;
    @AuraEnabled
    public Decimal ready;
    @AuraEnabled
    public Decimal expired;
    @AuraEnabled
    public String bookName;
  }

  public class LibrarianAnalyticsDTO {
    @AuraEnabled
    public Boolean available;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String refreshCadence;
    @AuraEnabled
    public Datetime lastUpdated;
    @AuraEnabled
    public CopyMetrics copyMetrics;
    @AuraEnabled
    public LoanMetrics loanMetrics;
    @AuraEnabled
    public ReservationMetrics reservationMetrics;
    @AuraEnabled
    public FineMetrics fineMetrics;
    @AuraEnabled
    public List<BookPopularityDTO> topBorrowedBooks;
    @AuraEnabled
    public List<ReservationDemandDTO> reservationDemand;
  }

  public class MemberAnalyticsDTO {
    @AuraEnabled
    public Boolean available { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public String refreshCadence { get; set; }
    @AuraEnabled
    public Datetime lastUpdated { get; set; }
    @AuraEnabled
    public Decimal totalLoans { get; set; }
    @AuraEnabled
    public Decimal activeLoans { get; set; }
    @AuraEnabled
    public Decimal returnedLoans { get; set; }
    @AuraEnabled
    public Decimal overdueLoans { get; set; }
    @AuraEnabled
    public Decimal totalReservations { get; set; }
    @AuraEnabled
    public Decimal activeReservationCount { get; set; }
    @AuraEnabled
    public Decimal totalFineCount { get; set; }
    @AuraEnabled
    public Decimal unpaidFineCount { get; set; }
    @AuraEnabled
    public Decimal fulfilledReservations { get; set; }
  }

  @TestVisible
  private static Boolean forceFailure = false;
  @TestVisible
  private static Map<String, List<Map<String, Object>>> testRows = new Map<String, List<Map<String, Object>>>();

  private static final String REFRESH_CADENCE = 'Data Cloud scheduled refresh: every 6 hours';
  private static final String REALTIME_CADENCE = 'Live Salesforce data • updates automatically';

  /**
   * Dashboard analytics intentionally reads the source transaction objects so
   * the librarian sees changes immediately. Data Cloud calculated insights are
   * still available for historical/aggregate use, but their six-hour schedule
   * is not suitable for operational dashboard numbers.
   */
  public static LibrarianAnalyticsDTO getRealtimeLibrarianAnalytics() {
    LibrarianAnalyticsDTO result = new LibrarianAnalyticsDTO();
    result.available = true;
    result.message = null;
    result.refreshCadence = REALTIME_CADENCE;
    result.lastUpdated = System.now();
    result.copyMetrics = new CopyMetrics();
    result.loanMetrics = new LoanMetrics();
    result.reservationMetrics = new ReservationMetrics();
    result.fineMetrics = new FineMetrics();
    defaultMetrics(result);
    result.topBorrowedBooks = new List<BookPopularityDTO>();
    result.reservationDemand = new List<ReservationDemandDTO>();

    try {
      DateTime now = System.now();
      for (AggregateResult row : [
        SELECT Status__c status, COUNT(Id) total
        FROM Book_Copy__c
        GROUP BY Status__c
      ]) {
        String status = String.valueOf(row.get('status'));
        Decimal total = aggregateValue(row.get('total'));
        if (status == 'Available')
          result.copyMetrics.availableCopies += total;
        else if (status == 'Borrowed')
          result.copyMetrics.borrowedCopies += total;
        else if (status == 'Reserved')
          result.copyMetrics.reservedCopies += total;
        else if (status == 'Lost')
          result.copyMetrics.lostCopies += total;
        result.copyMetrics.totalCopies += total;
      }

      for (AggregateResult row : [
        SELECT Status__c status, COUNT(Id) total
        FROM Borrow_Record__c
        GROUP BY Status__c
      ]) {
        String status = String.valueOf(row.get('status'));
        Decimal total = aggregateValue(row.get('total'));
        result.loanMetrics.totalLoans += total;
        if (status == 'Active')
          result.loanMetrics.activeLoans += total;
        else if (status == 'Overdue') {
          result.loanMetrics.activeLoans += total;
          result.loanMetrics.overdueLoans += total;
        } else if (status == 'Returned')
          result.loanMetrics.returnedLoans += total;
      }
      List<AggregateResult> overdueRows = [
        SELECT COUNT(Id) total
        FROM Borrow_Record__c
        WHERE Return_Date__c = NULL AND Due_Date__c < :now
      ];
      if (!overdueRows.isEmpty())
        result.loanMetrics.overdueLoans = aggregateValue(
          overdueRows[0].get('total')
        );

      for (AggregateResult row : [
        SELECT Status__c status, COUNT(Id) total
        FROM Reservation__c
        GROUP BY Status__c
      ]) {
        String status = String.valueOf(row.get('status'));
        Decimal total = aggregateValue(row.get('total'));
        result.reservationMetrics.totalReservations += total;
        if (status == 'Fulfilled')
          result.reservationMetrics.fulfilledReservations += total;
        else if (status == 'Cancelled')
          result.reservationMetrics.cancelledReservations += total;
        else if (status == 'Pending')
          result.reservationMetrics.pendingReservations += total;
        else if (status == 'Ready')
          result.reservationMetrics.readyReservations += total;
        else if (status == 'Expired')
          result.reservationMetrics.expiredReservations += total;
      }

      for (AggregateResult row : [
        SELECT Status__c status, COUNT(Id) total
        FROM Fine__c
        GROUP BY Status__c
      ]) {
        String status = String.valueOf(row.get('status'));
        Decimal total = aggregateValue(row.get('total'));
        result.fineMetrics.totalFineCount += total;
        if (status == 'Paid')
          result.fineMetrics.paidFineCount += total;
        else if (status == 'Unpaid' || status == 'Partially Paid')
          result.fineMetrics.unpaidFineCount += total;
      }

      Set<Id> popularBookIds = new Set<Id>();
      for (AggregateResult row : [
        SELECT Book_Copy__r.Book__c bookId, COUNT(Id) total
        FROM Borrow_Record__c
        WHERE Book_Copy__r.Book__c != NULL
        GROUP BY Book_Copy__r.Book__c
        ORDER BY COUNT(Id) DESC
        LIMIT 10
      ]) {
        BookPopularityDTO item = new BookPopularityDTO();
        item.bookId = String.valueOf(row.get('bookId'));
        item.borrowCount = aggregateValue(row.get('total'));
        item.activeBorrowCount = 0;
        item.returnedBorrowCount = 0;
        result.topBorrowedBooks.add(item);
        popularBookIds.add((Id) item.bookId);
      }
      applyBookNames(result.topBorrowedBooks, popularBookIds);

      Set<Id> demandBookIds = new Set<Id>();
      for (AggregateResult row : [
        SELECT Book__c bookId, COUNT(Id) total
        FROM Reservation__c
        WHERE Book__c != NULL
        GROUP BY Book__c
        ORDER BY COUNT(Id) DESC
        LIMIT 10
      ]) {
        ReservationDemandDTO item = new ReservationDemandDTO();
        item.bookId = String.valueOf(row.get('bookId'));
        item.totalReservations = aggregateValue(row.get('total'));
        item.fulfilled = 0;
        item.cancelled = 0;
        item.pending = 0;
        item.ready = 0;
        item.expired = 0;
        result.reservationDemand.add(item);
        demandBookIds.add((Id) item.bookId);
      }
      applyDemandBookNames(result.reservationDemand, demandBookIds);
    } catch (Exception ex) {
      result.available = false;
      result.message = 'Real-time analytics are temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_REALTIME_ANALYTICS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    defaultMetrics(result);
    return result;
  }

  public static LibrarianAnalyticsDTO getLibrarianAnalytics() {
    LibrarianAnalyticsDTO result = new LibrarianAnalyticsDTO();
    result.available = true;
    result.message = null;
    result.refreshCadence = REFRESH_CADENCE;
    result.lastUpdated = latestRun(
      new List<String>{
        'Library_Copy_Availability__cio',
        'Library_Member_Loan_Activity__cio',
        'Library_Member_Reservation_Activity__cio',
        'Library_Member_Fine_Activity__cio',
        'Library_Book_Popularity__cio',
        'Library_Reservation_Demand__cio'
      }
    );
    result.copyMetrics = new CopyMetrics();
    result.loanMetrics = new LoanMetrics();
    result.reservationMetrics = new ReservationMetrics();
    result.fineMetrics = new FineMetrics();
    result.topBorrowedBooks = new List<BookPopularityDTO>();
    result.reservationDemand = new List<ReservationDemandDTO>();

    try {
      List<Map<String, Object>> rows = rows(
        'Library_Copy_Availability__cio',
        null,
        null,
        null,
        'book_id__c',
        4999
      );
      for (Map<String, Object> row : rows) {
        result.copyMetrics.totalCopies = add(
          result.copyMetrics.totalCopies,
          value(row, 'total_copy_count__c')
        );
        result.copyMetrics.availableCopies = add(
          result.copyMetrics.availableCopies,
          value(row, 'available_copy_count__c')
        );
        result.copyMetrics.borrowedCopies = add(
          result.copyMetrics.borrowedCopies,
          value(row, 'borrowed_copy_count__c')
        );
        result.copyMetrics.reservedCopies = add(
          result.copyMetrics.reservedCopies,
          value(row, 'reserved_copy_count__c')
        );
        result.copyMetrics.lostCopies = add(
          result.copyMetrics.lostCopies,
          value(row, 'lost_copy_count__c')
        );
      }

      for (
        Map<String, Object> row : rows(
          'Library_Member_Loan_Activity__cio',
          null,
          null,
          null,
          'member_id__c',
          4999
        )
      ) {
        result.loanMetrics.totalLoans = add(
          result.loanMetrics.totalLoans,
          value(row, 'total_loan_count__c')
        );
        result.loanMetrics.activeLoans = add(
          result.loanMetrics.activeLoans,
          value(row, 'active_loan_count__c')
        );
        result.loanMetrics.returnedLoans = add(
          result.loanMetrics.returnedLoans,
          value(row, 'returned_loan_count__c')
        );
        result.loanMetrics.overdueLoans = add(
          result.loanMetrics.overdueLoans,
          value(row, 'overdue_loan_count__c')
        );
      }

      for (
        Map<String, Object> row : rows(
          'Library_Member_Reservation_Activity__cio',
          null,
          null,
          null,
          'member_id__c',
          4999
        )
      ) {
        result.reservationMetrics.totalReservations = add(
          result.reservationMetrics.totalReservations,
          value(row, 'total_reservation_count__c')
        );
        result.reservationMetrics.fulfilledReservations = add(
          result.reservationMetrics.fulfilledReservations,
          value(row, 'fulfilled_reservation_count__c')
        );
        result.reservationMetrics.cancelledReservations = add(
          result.reservationMetrics.cancelledReservations,
          value(row, 'cancelled_reservation_count__c')
        );
        result.reservationMetrics.pendingReservations = add(
          result.reservationMetrics.pendingReservations,
          value(row, 'pending_reservation_count__c')
        );
        result.reservationMetrics.readyReservations = add(
          result.reservationMetrics.readyReservations,
          value(row, 'ready_reservation_count__c')
        );
        result.reservationMetrics.expiredReservations = add(
          result.reservationMetrics.expiredReservations,
          value(row, 'expired_reservation_count__c')
        );
      }

      for (
        Map<String, Object> row : rows(
          'Library_Member_Fine_Activity__cio',
          null,
          null,
          null,
          'member_id__c',
          4999
        )
      ) {
        result.fineMetrics.totalFineCount = add(
          result.fineMetrics.totalFineCount,
          value(row, 'total_fine_count__c')
        );
        result.fineMetrics.paidFineCount = add(
          result.fineMetrics.paidFineCount,
          value(row, 'paid_fine_count__c')
        );
        result.fineMetrics.unpaidFineCount = add(
          result.fineMetrics.unpaidFineCount,
          value(row, 'unpaid_fine_count__c')
        );
      }

      List<Map<String, Object>> popularityRows = rows(
        'Library_Book_Popularity__cio',
        'book_id__c',
        'total_borrow_count__c,active_borrow_count__c,returned_borrow_count__c',
        null,
        'book_id__c',
        4999
      );
      Set<Id> bookIds = new Set<Id>();
      for (Map<String, Object> row : popularityRows) {
        BookPopularityDTO item = new BookPopularityDTO();
        item.bookId = text(row, 'book_id__c');
        item.borrowCount = value(row, 'total_borrow_count__c');
        item.activeBorrowCount = value(row, 'active_borrow_count__c');
        item.returnedBorrowCount = value(row, 'returned_borrow_count__c');
        result.topBorrowedBooks.add(item);
        addId(bookIds, item.bookId);
      }
      sortPopularity(result.topBorrowedBooks);
      trimPopularity(result.topBorrowedBooks, 10);
      applyBookNames(result.topBorrowedBooks, bookIds);

      List<Map<String, Object>> demandRows = rows(
        'Library_Reservation_Demand__cio',
        'book_id__c',
        'total_reservation_count__c,fulfilled_reservation_count__c,cancelled_reservation_count__c,pending_reservation_count__c,ready_reservation_count__c,expired_reservation_count__c',
        null,
        'book_id__c',
        4999
      );
      Set<Id> demandBookIds = new Set<Id>();
      for (Map<String, Object> row : demandRows) {
        ReservationDemandDTO item = new ReservationDemandDTO();
        item.bookId = text(row, 'book_id__c');
        item.totalReservations = value(row, 'total_reservation_count__c');
        item.fulfilled = value(row, 'fulfilled_reservation_count__c');
        item.cancelled = value(row, 'cancelled_reservation_count__c');
        item.pending = value(row, 'pending_reservation_count__c');
        item.ready = value(row, 'ready_reservation_count__c');
        item.expired = value(row, 'expired_reservation_count__c');
        result.reservationDemand.add(item);
        addId(demandBookIds, item.bookId);
      }
      sortDemand(result.reservationDemand);
      trimDemand(result.reservationDemand, 10);
      applyDemandBookNames(result.reservationDemand, demandBookIds);
    } catch (Exception ex) {
      result.available = false;
      result.message = 'Analytics are temporarily unavailable. Transactional library functions remain available.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_DATA_CLOUD_ANALYTICS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    defaultMetrics(result);
    return result;
  }

  public static MemberAnalyticsDTO getMemberAnalytics(Id memberId) {
    MemberAnalyticsDTO result = new MemberAnalyticsDTO();
    result.available = true;
    result.message = null;
    result.refreshCadence = REFRESH_CADENCE;
    result.lastUpdated = latestRun(
      new List<String>{
        'Library_Member_Loan_Activity__cio',
        'Library_Member_Reservation_Activity__cio',
        'Library_Member_Fine_Activity__cio'
      }
    );
    try {
      if (memberId == null)
        throw new AuraHandledException('MEMBER_ANALYTICS_MEMBER_REQUIRED');
      String filter = '[member_id__c=' + String.valueOf(memberId) + ']';
      for (
        Map<String, Object> row : rows(
          'Library_Member_Loan_Activity__cio',
          null,
          null,
          filter,
          'member_id__c',
          1
        )
      ) {
        result.totalLoans = value(row, 'total_loan_count__c');
        result.activeLoans = value(row, 'active_loan_count__c');
        result.returnedLoans = value(row, 'returned_loan_count__c');
        result.overdueLoans = value(row, 'overdue_loan_count__c');
      }
      for (
        Map<String, Object> row : rows(
          'Library_Member_Reservation_Activity__cio',
          null,
          null,
          filter,
          'member_id__c',
          1
        )
      ) {
        result.totalReservations = value(row, 'total_reservation_count__c');
        result.fulfilledReservations = value(
          row,
          'fulfilled_reservation_count__c'
        );
        result.activeReservationCount = add(
          value(row, 'pending_reservation_count__c'),
          value(row, 'ready_reservation_count__c')
        );
      }
      for (
        Map<String, Object> row : rows(
          'Library_Member_Fine_Activity__cio',
          null,
          null,
          filter,
          'member_id__c',
          1
        )
      ) {
        result.totalFineCount = value(row, 'total_fine_count__c');
        result.unpaidFineCount = value(row, 'unpaid_fine_count__c');
      }
    } catch (Exception ex) {
      result.available = false;
      result.message = 'Activity analytics are temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_MEMBER_ANALYTICS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    defaultMemberMetrics(result);
    return result;
  }

  /**
   * Member-facing activity must reflect the current Salesforce transaction state.
   * Data Cloud Calculated Insights remain appropriate for aggregate analytics,
   * but their scheduled refresh cadence is not suitable for a member dashboard.
   */
  public static MemberAnalyticsDTO getRealtimeMemberAnalytics(Id memberId) {
    MemberAnalyticsDTO result = new MemberAnalyticsDTO();
    result.available = true;
    result.message = null;
    result.refreshCadence = 'Real-time Salesforce transaction data';
    result.lastUpdated = System.now();
    try {
      if (memberId == null)
        throw new AuraHandledException('MEMBER_ANALYTICS_MEMBER_REQUIRED');
      DateTime now = System.now();

      Map<String, Object> memberBind = new Map<String, Object>{
        'memberId' => memberId
      };
      Map<String, Object> overdueBinds = new Map<String, Object>{
        'memberId' => memberId,
        'nowValue' => now
      };
      Integer totalLoans = systemCount(
        'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId',
        memberBind
      );
      Integer activeLoans = systemCount(
        'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId AND Return_Date__c = NULL',
        memberBind
      );
      Integer returnedLoans = systemCount(
        'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId AND Return_Date__c != NULL',
        memberBind
      );
      Integer overdueLoans = systemCount(
        'SELECT COUNT(Id) total FROM Borrow_Record__c WHERE Member__c = :memberId ' +
        'AND Return_Date__c = NULL AND Due_Date__c < :nowValue',
        overdueBinds
      );
      Integer totalReservations = systemCount(
        'SELECT COUNT(Id) total FROM Reservation__c WHERE Member__c = :memberId',
        memberBind
      );
      Integer activeReservations = systemCount(
        'SELECT COUNT(Id) total FROM Reservation__c WHERE Member__c = :memberId ' +
        'AND Status__c IN (\'Pending\', \'Ready\')',
        memberBind
      );
      Integer fulfilledReservations = systemCount(
        'SELECT COUNT(Id) total FROM Reservation__c WHERE Member__c = :memberId ' +
        'AND Status__c = \'Fulfilled\'',
        memberBind
      );
      Integer totalFines = systemCount(
        'SELECT COUNT(Id) total FROM Fine__c WHERE Member__c = :memberId',
        memberBind
      );
      Integer unpaidFines = systemCount(
        'SELECT COUNT(Id) total FROM Fine__c WHERE Member__c = :memberId ' +
        'AND Status__c IN (\'Unpaid\', \'Partially Paid\')',
        memberBind
      );

      result.totalLoans = totalLoans;
      result.activeLoans = activeLoans;
      result.returnedLoans = returnedLoans;
      result.overdueLoans = overdueLoans;
      result.totalReservations = totalReservations;
      result.activeReservationCount = activeReservations;
      result.fulfilledReservations = fulfilledReservations;
      result.totalFineCount = totalFines;
      result.unpaidFineCount = unpaidFines;
    } catch (Exception ex) {
      result.available = false;
      result.message = 'Real-time activity is temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_REALTIME_MEMBER_ANALYTICS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    defaultMemberMetrics(result);
    return result;
  }

  private static Integer systemCount(String query, Map<String, Object> binds) {
    List<AggregateResult> rows = (List<AggregateResult>) Database.queryWithBinds(
      query,
      binds,
      AccessLevel.SYSTEM_MODE
    );
    return rows.isEmpty() ? 0 : Integer.valueOf(rows[0].get('total'));
  }

  private static List<Map<String, Object>> rows(
    String ciName,
    String dimensions,
    String measures,
    String filters,
    String orderby,
    Integer limitValue
  ) {
    if (Test.isRunningTest()) {
      if (forceFailure)
        throw new AuraHandledException('TEST_DATA_CLOUD_FAILURE');
      if (testRows.containsKey(ciName))
        return testRows.get(ciName);
    }
    List<Map<String, Object>> parsed = new List<Map<String, Object>>();
    Integer pageSize = limitValue == null ? 10 : Math.min(limitValue, 10);
    Integer offset = 0;
    while (true) {
      ConnectApi.CdpQueryOutput response = ConnectApi.CdpQuery.queryCalculatedInsights(
        ciName,
        dimensions,
        measures,
        orderby,
        filters,
        pageSize,
        offset
      );
      if (response == null || response.data == null)
        break;
      List<Map<String, Object>> pageRows = parseRows(
        String.valueOf(response.data)
      );
      parsed.addAll(pageRows);
      if (pageRows.isEmpty() || pageRows.size() < pageSize)
        break;
      if (limitValue != null && parsed.size() >= limitValue)
        break;
      offset += pageRows.size();
    }
    return parsed;
  }

  private static void sortPopularity(List<BookPopularityDTO> items) {
    for (Integer i = 0; i < items.size(); i++) {
      Integer best = i;
      for (Integer j = i + 1; j < items.size(); j++) {
        if (items[j].borrowCount > items[best].borrowCount)
          best = j;
      }
      if (best != i) {
        BookPopularityDTO swap = items[i];
        items[i] = items[best];
        items[best] = swap;
      }
    }
  }

  private static void sortDemand(List<ReservationDemandDTO> items) {
    for (Integer i = 0; i < items.size(); i++) {
      Integer best = i;
      for (Integer j = i + 1; j < items.size(); j++) {
        if (items[j].totalReservations > items[best].totalReservations)
          best = j;
      }
      if (best != i) {
        ReservationDemandDTO swap = items[i];
        items[i] = items[best];
        items[best] = swap;
      }
    }
  }

  private static void trimPopularity(
    List<BookPopularityDTO> items,
    Integer count
  ) {
    while (items.size() > count)
      items.remove(items.size() - 1);
  }

  private static void trimDemand(
    List<ReservationDemandDTO> items,
    Integer count
  ) {
    while (items.size() > count)
      items.remove(items.size() - 1);
  }

  private static List<Map<String, Object>> parseRows(String rawData) {
    List<Map<String, Object>> parsed = new List<Map<String, Object>>();
    if (String.isBlank(rawData))
      return parsed;
    Integer rowStart = -1;
    Integer depth = 0;
    for (Integer index = 0; index < rawData.length(); index++) {
      String character = rawData.substring(index, index + 1);
      if (character == '{') {
        if (depth == 0)
          rowStart = index;
        depth++;
      } else if (character == '}' && depth > 0) {
        depth--;
        if (depth == 0 && rowStart >= 0) {
          parsed.add(parseRow(rawData.substring(rowStart + 1, index)));
          rowStart = -1;
        }
      }
    }
    return parsed;
  }

  private static Datetime latestRun(List<String> ciNames) {
    if (Test.isRunningTest())
      return null;
    Datetime latest;
    try {
      for (String ciName : ciNames) {
        ConnectApi.CdpCalculatedInsightOutput metadata = ConnectApi.CdpCalculatedInsight.getCalculatedInsight(
          ciName
        );
        Datetime runTime = metadata == null
          ? null
          : parseDataCloudDateTime(metadata.lastRunDateTime);
        if (runTime != null && (latest == null || runTime > latest)) {
          latest = runTime;
        }
      }
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        'LIBRARY_DATA_CLOUD_METADATA_UNAVAILABLE: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    return latest;
  }

  private static Datetime parseDataCloudDateTime(String valueText) {
    if (String.isBlank(valueText))
      return null;
    try {
      return Datetime.valueOfGmt(valueText.substring(0, 19).replace('T', ' '));
    } catch (Exception ignored) {
      return null;
    }
  }

  private static Map<String, Object> parseRow(String rawRow) {
    Map<String, Object> row = new Map<String, Object>();
    for (String pair : rawRow.split(',')) {
      Integer separator = pair.indexOf('=');
      if (separator <= 0)
        continue;
      String key = pair.substring(0, separator).trim();
      String valueText = pair.substring(separator + 1).trim();
      if (valueText == 'null')
        row.put(key, null);
      else
        row.put(key, valueText);
    }
    return row;
  }

  private static Decimal value(Map<String, Object> row, String key) {
    if (row == null || !row.containsKey(key) || row.get(key) == null)
      return 0;
    return Decimal.valueOf(String.valueOf(row.get(key)));
  }

  private static Decimal aggregateValue(Object rawValue) {
    return rawValue == null ? 0 : Decimal.valueOf(String.valueOf(rawValue));
  }

  private static String text(Map<String, Object> row, String key) {
    return row == null ||
      row.get(key) == null
      ? null
      : String.valueOf(row.get(key));
  }

  private static Decimal add(Decimal left, Decimal right) {
    return (left == null ? 0 : left) + (right == null ? 0 : right);
  }

  private static void addId(Set<Id> ids, String value) {
    if (String.isBlank(value))
      return;
    try {
      ids.add((Id) value);
    } catch (Exception ignored) {
    }
  }

  private static void applyBookNames(
    List<BookPopularityDTO> rows,
    Set<Id> ids
  ) {
    if (ids.isEmpty())
      return;
    Map<Id, Book__c> books = new Map<Id, Book__c>(
      [SELECT Id, Name FROM Book__c WHERE Id IN :ids]
    );
    for (BookPopularityDTO row : rows)
      if (books.containsKey((Id) row.bookId))
        row.bookName = books.get((Id) row.bookId).Name;
  }

  private static void applyDemandBookNames(
    List<ReservationDemandDTO> rows,
    Set<Id> ids
  ) {
    if (ids.isEmpty())
      return;
    Map<Id, Book__c> books = new Map<Id, Book__c>(
      [SELECT Id, Name FROM Book__c WHERE Id IN :ids]
    );
    for (ReservationDemandDTO row : rows) {
      if (books.containsKey((Id) row.bookId)) {
        row.bookName = books.get((Id) row.bookId).Name;
      } else {
        row.bookName = 'Unknown Book';
      }
    }
  }

  private static void defaultMetrics(LibrarianAnalyticsDTO result) {
    if (result.copyMetrics.totalCopies == null)
      result.copyMetrics.totalCopies = 0;
    if (result.copyMetrics.availableCopies == null)
      result.copyMetrics.availableCopies = 0;
    if (result.copyMetrics.borrowedCopies == null)
      result.copyMetrics.borrowedCopies = 0;
    if (result.copyMetrics.reservedCopies == null)
      result.copyMetrics.reservedCopies = 0;
    if (result.copyMetrics.lostCopies == null)
      result.copyMetrics.lostCopies = 0;
    if (result.loanMetrics.totalLoans == null)
      result.loanMetrics.totalLoans = 0;
    if (result.loanMetrics.activeLoans == null)
      result.loanMetrics.activeLoans = 0;
    if (result.loanMetrics.returnedLoans == null)
      result.loanMetrics.returnedLoans = 0;
    if (result.loanMetrics.overdueLoans == null)
      result.loanMetrics.overdueLoans = 0;
    if (result.reservationMetrics.totalReservations == null)
      result.reservationMetrics.totalReservations = 0;
    if (result.reservationMetrics.fulfilledReservations == null)
      result.reservationMetrics.fulfilledReservations = 0;
    if (result.reservationMetrics.cancelledReservations == null)
      result.reservationMetrics.cancelledReservations = 0;
    if (result.reservationMetrics.pendingReservations == null)
      result.reservationMetrics.pendingReservations = 0;
    if (result.reservationMetrics.readyReservations == null)
      result.reservationMetrics.readyReservations = 0;
    if (result.reservationMetrics.expiredReservations == null)
      result.reservationMetrics.expiredReservations = 0;
    if (result.fineMetrics.totalFineCount == null)
      result.fineMetrics.totalFineCount = 0;
    if (result.fineMetrics.paidFineCount == null)
      result.fineMetrics.paidFineCount = 0;
    if (result.fineMetrics.unpaidFineCount == null)
      result.fineMetrics.unpaidFineCount = 0;
  }

  private static void defaultMemberMetrics(MemberAnalyticsDTO result) {
    if (result.totalLoans == null)
      result.totalLoans = 0;
    if (result.activeLoans == null)
      result.activeLoans = 0;
    if (result.returnedLoans == null)
      result.returnedLoans = 0;
    if (result.overdueLoans == null)
      result.overdueLoans = 0;
    if (result.totalReservations == null)
      result.totalReservations = 0;
    if (result.activeReservationCount == null)
      result.activeReservationCount = 0;
    if (result.totalFineCount == null)
      result.totalFineCount = 0;
    if (result.unpaidFineCount == null)
      result.unpaidFineCount = 0;
    if (result.fulfilledReservations == null)
      result.fulfilledReservations = 0;
  }
}
