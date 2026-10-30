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
      List<Member__c> members = new MemberReader().find(lookup);
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
      Map<String, Decimal> counts = new MemberReader().counts(member.Id);
      output.found = true;
      output.memberId = String.valueOf(member.Id);
      output.memberName = String.isBlank(member.Name)
        ? member.First_Name__c + ' ' + member.Last_Name__c
        : member.Name;
      output.memberEmail = member.Email__c;
      output.totalLoans = counts.get('totalLoans');
      output.activeLoans = counts.get('activeLoans');
      output.totalReservations = counts.get('totalReservations');
      output.unpaidFineCount = counts.get('unpaidFineCount');
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

  // Callers authorize first (Manage_Library_Circulation). The agent user has no
  // record sharing on the private member and circulation objects, so the
  // lookup and counts read without sharing.
  private without sharing class MemberReader {
    public List<Member__c> find(String lookup) {
      Id memberId;
      try {
        memberId = (Id) lookup.trim();
      } catch (Exception ignored) {
      }
      if (memberId != null)
        return [
          SELECT Id, Name, First_Name__c, Last_Name__c, Email__c
          FROM Member__c
          WHERE Id = :memberId
          WITH SYSTEM_MODE
          LIMIT 2
        ];
      return [
        SELECT Id, Name, First_Name__c, Last_Name__c, Email__c
        FROM Member__c
        WHERE Name = :lookup OR Email__c = :lookup
        WITH SYSTEM_MODE
        LIMIT 2
      ];
    }

    public Map<String, Decimal> counts(Id memberId) {
      Map<String, Decimal> result = new Map<String, Decimal>{
        'totalLoans' => 0,
        'activeLoans' => 0,
        'totalReservations' => 0,
        'unpaidFineCount' => 0
      };
      for (AggregateResult row : [
        SELECT Status__c status, COUNT(Id) total
        FROM Borrow_Record__c
        WHERE Member__c = :memberId
        WITH SYSTEM_MODE
        GROUP BY Status__c
      ]) {
        Decimal total = Decimal.valueOf((Integer) row.get('total'));
        String status = (String) row.get('status');
        result.put('totalLoans', result.get('totalLoans') + total);
        if (status == 'Active' || status == 'Overdue')
          result.put('activeLoans', result.get('activeLoans') + total);
      }
      result.put(
        'totalReservations',
        [SELECT COUNT() FROM Reservation__c WHERE Member__c = :memberId WITH SYSTEM_MODE]
      );
      result.put(
        'unpaidFineCount',
        [
          SELECT COUNT()
          FROM Fine__c
          WHERE
            Member__c = :memberId
            AND Status__c IN ('Unpaid', 'Partially Paid')
          WITH SYSTEM_MODE
        ]
      );
      return result;
    }
  }
}
