global with sharing class LibraryAgentMyActivityAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
  }
  global class Response {
    @InvocableVariable
    public Boolean available;
    @InvocableVariable
    public String message;
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
    public Decimal activeReservationCount;
    @InvocableVariable
    public Decimal totalFineCount;
    @InvocableVariable
    public Decimal unpaidFineCount;
  }

  @InvocableMethod(
    label='Get My Library Activity'
    description='Use only for live activity questions about the currently authenticated member. Invoke this action before answering; identity is derived from the server-validated session token and no Member ID is accepted.'
  )
  global static List<Response> execute(List<Request> requests) {
    String token = requests == null || requests.isEmpty()
      ? null
      : requests[0].sessionToken;
    LibraryDataCloudService.MemberAnalyticsDTO source = LibraryMemberSessionController.getMyAnalytics(
      token
    );
    Response output = new Response();
    output.available = source.available;
    output.message = source.message;
    output.totalLoans = source.totalLoans;
    output.activeLoans = source.activeLoans;
    output.returnedLoans = source.returnedLoans;
    output.overdueLoans = source.overdueLoans;
    output.totalReservations = source.totalReservations;
    output.activeReservationCount = source.activeReservationCount;
    output.totalFineCount = source.totalFineCount;
    output.unpaidFineCount = source.unpaidFineCount;
    return new List<Response>{ output };
  }
}
