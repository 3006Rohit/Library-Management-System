global with sharing class LibraryAgentAnalyticsAction {
  global class Request {
    @InvocableVariable(required=false)
    global String requestContext;
  }

  global class Response {
    @InvocableVariable
    public Boolean available;
    @InvocableVariable
    public String message;
    @InvocableVariable
    public String lastUpdated;
    @InvocableVariable
    public Decimal totalCopies;
    @InvocableVariable
    public Decimal availableCopies;
    @InvocableVariable
    public Decimal borrowedCopies;
    @InvocableVariable
    public Decimal reservedCopies;
    @InvocableVariable
    public Decimal lostCopies;
    @InvocableVariable
    public Decimal totalLoans;
    @InvocableVariable
    public Decimal activeLoans;
    @InvocableVariable
    public Decimal returnedLoans;
    @InvocableVariable
    public Decimal overdueLoans;
    @InvocableVariable
    public Decimal totalReservations;
    @InvocableVariable
    public Decimal fulfilledReservations;
    @InvocableVariable
    public Decimal cancelledReservations;
    @InvocableVariable
    public Decimal pendingReservations;
    @InvocableVariable
    public Decimal readyReservations;
    @InvocableVariable
    public Decimal expiredReservations;
    @InvocableVariable
    public Decimal totalFineCount;
    @InvocableVariable
    public Decimal paidFineCount;
    @InvocableVariable
    public Decimal unpaidFineCount;
    @InvocableVariable
    public String topBorrowedBooksJson;
    @InvocableVariable
    public String reservationDemandJson;
  }

  @InvocableMethod(
    label='Get Library Analytics'
    description='Read-only librarian analytics from validated Data 360 Calculated Insights. Use for library-wide summaries; do not invent values.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      LibraryPolicyService.require('Manage_Library_Circulation');
      LibraryDataCloudService.LibrarianAnalyticsDTO source = LibraryDataCloudService.getLibrarianAnalytics();
      output.available = source.available;
      output.message = source.message;
      output.lastUpdated = source.lastUpdated == null
        ? null
        : String.valueOf(source.lastUpdated);
      output.totalCopies = source.copyMetrics.totalCopies;
      output.availableCopies = source.copyMetrics.availableCopies;
      output.borrowedCopies = source.copyMetrics.borrowedCopies;
      output.reservedCopies = source.copyMetrics.reservedCopies;
      output.lostCopies = source.copyMetrics.lostCopies;
      output.totalLoans = source.loanMetrics.totalLoans;
      output.activeLoans = source.loanMetrics.activeLoans;
      output.returnedLoans = source.loanMetrics.returnedLoans;
      output.overdueLoans = source.loanMetrics.overdueLoans;
      output.totalReservations = source.reservationMetrics.totalReservations;
      output.fulfilledReservations = source.reservationMetrics.fulfilledReservations;
      output.cancelledReservations = source.reservationMetrics.cancelledReservations;
      output.pendingReservations = source.reservationMetrics.pendingReservations;
      output.readyReservations = source.reservationMetrics.readyReservations;
      output.expiredReservations = source.reservationMetrics.expiredReservations;
      output.totalFineCount = source.fineMetrics.totalFineCount;
      output.paidFineCount = source.fineMetrics.paidFineCount;
      output.unpaidFineCount = source.fineMetrics.unpaidFineCount;
      output.topBorrowedBooksJson = JSON.serialize(source.topBorrowedBooks);
      output.reservationDemandJson = JSON.serialize(source.reservationDemand);
    } catch (Exception ex) {
      output.available = false;
      output.message = 'Library analytics are temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_ANALYTICS_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    return new List<Response>{ output };
  }
}
