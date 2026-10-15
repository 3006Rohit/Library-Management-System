global with sharing class LibraryAgentMemberSummaryAction {
  global class Request {
    @InvocableVariable(required=true)
    global String memberLookup;
  }
  global class Response {
    @InvocableVariable
    public Boolean found;
    @InvocableVariable
    public String message;
    @InvocableVariable
    public String memberId;
    @InvocableVariable
    public String memberName;
    @InvocableVariable
    public String memberEmail;
    @InvocableVariable
    public Decimal totalLoans;
    @InvocableVariable
    public Decimal activeLoans;
    @InvocableVariable
    public Decimal totalReservations;
    @InvocableVariable
    public Decimal unpaidFineCount;
  }

  @InvocableMethod(
    label='Get Member Library Summary'
    description='Use this action for a live member-specific summary when an authorized librarian asks about a member. Invoke it before answering current member facts; never expose password, session, token, or security fields.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    try {
      LibraryPolicyService.require('Manage_Library_Circulation');
      String lookup = requests == null || requests.isEmpty()
        ? null
        : requests[0].memberLookup;
      if (String.isBlank(lookup)) {
        output.found = false;
        output.message = 'A member lookup value is required.';
        return new List<Response>{ output };
      }
      List<Member__c> members = new List<Member__c>();
      Id memberId;
      try {
        memberId = (Id) lookup.trim();
      } catch (Exception ignored) {
      }
      if (memberId != null)
        members = [
          SELECT Id, Name, First_Name__c, Last_Name__c, Email__c
          FROM Member__c
          WHERE Id = :memberId
          LIMIT 2
        ];
      else
        members = [
          SELECT Id, Name, First_Name__c, Last_Name__c, Email__c
          FROM Member__c
          WHERE Name = :lookup OR Email__c = :lookup
          LIMIT 2
        ];
      if (members.isEmpty()) {
        output.found = false;
        output.message = 'No matching member was found.';
        return new List<Response>{ output };
      }
      if (members.size() > 1) {
        output.found = false;
        output.message = 'The member lookup is ambiguous.';
        return new List<Response>{ output };
      }
      Member__c member = members[0];
      LibraryDataCloudService.MemberAnalyticsDTO source = LibraryDataCloudService.getMemberAnalytics(
        member.Id
      );
      output.found = true;
      output.memberId = String.valueOf(member.Id);
      output.memberName = String.isBlank(member.Name)
        ? member.First_Name__c + ' ' + member.Last_Name__c
        : member.Name;
      output.memberEmail = member.Email__c;
      output.totalLoans = source.totalLoans;
      output.activeLoans = source.activeLoans;
      output.totalReservations = source.totalReservations;
      output.unpaidFineCount = source.unpaidFineCount;
    } catch (Exception ex) {
      output.found = false;
      output.message = 'The member summary is temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_MEMBER_SUMMARY_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    return new List<Response>{ output };
  }
}
