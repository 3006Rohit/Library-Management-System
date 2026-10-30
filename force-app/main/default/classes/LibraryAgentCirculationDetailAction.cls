global with sharing class LibraryAgentCirculationDetailAction {
  global class Request {
    @InvocableVariable(required=true)
    global String detailType;
  }
  global class Response {
    @InvocableVariable
    public Boolean available;
    @InvocableVariable
    public String message;
    @InvocableVariable
    public String detailType;
    @InvocableVariable
    public Decimal totalCount;
    @InvocableVariable
    public Decimal shownCount;
    @InvocableVariable
    public String rowsJson;
  }

  @InvocableMethod(
    label='Get Circulation Details'
    description='Read-only record-level detail for authorized librarians. detailType is OVERDUE_LOANS, UNPAID_FINES, or PENDING_RESERVATIONS. Returns up to 25 rows with member name and ID, book, dates, and amounts. Never includes contact details.'
  )
  global static List<Response> execute(List<Request> requests) {
    Response output = new Response();
    output.available = false;
    try {
      LibraryPolicyService.require('Manage_Library_Circulation');
      String type = requests == null || requests.isEmpty()
        ? null
        : requests[0].detailType;
      type = type == null ? '' : type.trim().toUpperCase();
      output.detailType = type;
      CircDetailReader reader = new CircDetailReader();
      List<Map<String, Object>> rows;
      if (type == 'OVERDUE_LOANS') {
        rows = reader.overdueLoans(output);
      } else if (type == 'UNPAID_FINES') {
        rows = reader.unpaidFines(output);
      } else if (type == 'PENDING_RESERVATIONS') {
        rows = reader.pendingReservations(output);
      } else {
        output.message = 'detailType must be OVERDUE_LOANS, UNPAID_FINES, or PENDING_RESERVATIONS.';
        return new List<Response>{ output };
      }
      output.available = true;
      output.shownCount = rows.size();
      output.rowsJson = JSON.serialize(rows);
    } catch (Exception ex) {
      output.available = false;
      output.message = 'Circulation details are temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_CIRC_DETAIL_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
    return new List<Response>{ output };
  }

  // Callers authorize first (Manage_Library_Circulation). The agent user has no
  // record sharing on the private circulation objects, so reads are system mode
  // and without sharing.
  private without sharing class CircDetailReader {
    private String memberName(Member__c m) {
      if (m == null)
        return null;
      String full = String.join(
        new List<String>{
          m.First_Name__c == null ? '' : m.First_Name__c,
          m.Last_Name__c == null ? '' : m.Last_Name__c
        },
        ' '
      ).trim();
      return String.isBlank(full) ? m.Name : full;
    }

    public List<Map<String, Object>> overdueLoans(Response output) {
      DateTime now = System.now();
      output.totalCount = [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE Return_Date__c = NULL AND Due_Date__c < :now AND Status__c != 'Lost'
        WITH SYSTEM_MODE
      ];
      List<Map<String, Object>> rows = new List<Map<String, Object>>();
      for (Borrow_Record__c r : [
        SELECT
          Name,
          Borrow_Date__c,
          Due_Date__c,
          Status__c,
          Member__r.Name,
          Member__r.First_Name__c,
          Member__r.Last_Name__c,
          Book_Copy__r.Book__r.Name
        FROM Borrow_Record__c
        WHERE Return_Date__c = NULL AND Due_Date__c < :now AND Status__c != 'Lost'
        WITH SYSTEM_MODE
        ORDER BY Due_Date__c ASC
        LIMIT 25
      ]) {
        rows.add(
          new Map<String, Object>{
            'loanId' => r.Name,
            'memberId' => r.Member__r?.Name,
            'memberName' => memberName(r.Member__r),
            'book' => r.Book_Copy__r?.Book__r?.Name,
            'borrowedOn' => r.Borrow_Date__c?.date(),
            'dueOn' => r.Due_Date__c?.date(),
            'daysOverdue' => r.Due_Date__c == null
              ? null
              : r.Due_Date__c.date().daysBetween(now.date()),
            'status' => r.Status__c
          }
        );
      }
      return rows;
    }

    public List<Map<String, Object>> unpaidFines(Response output) {
      output.totalCount = [
        SELECT COUNT()
        FROM Fine__c
        WHERE Status__c IN ('Unpaid', 'Partially Paid')
        WITH SYSTEM_MODE
      ];
      List<Map<String, Object>> rows = new List<Map<String, Object>>();
      for (Fine__c f : [
        SELECT
          Name,
          Fine_Type__c,
          Amount__c,
          Paid_Amount__c,
          Balance__c,
          Status__c,
          Generated_Date__c,
          Member__r.Name,
          Member__r.First_Name__c,
          Member__r.Last_Name__c
        FROM Fine__c
        WHERE Status__c IN ('Unpaid', 'Partially Paid')
        WITH SYSTEM_MODE
        ORDER BY Generated_Date__c ASC
        LIMIT 25
      ]) {
        rows.add(
          new Map<String, Object>{
            'fineId' => f.Name,
            'memberId' => f.Member__r?.Name,
            'memberName' => memberName(f.Member__r),
            'type' => f.Fine_Type__c,
            'amount' => f.Amount__c,
            'paid' => f.Paid_Amount__c,
            'balance' => f.Balance__c,
            'status' => f.Status__c,
            'generatedOn' => f.Generated_Date__c
          }
        );
      }
      return rows;
    }

    public List<Map<String, Object>> pendingReservations(Response output) {
      output.totalCount = [
        SELECT COUNT()
        FROM Reservation__c
        WHERE Status__c IN ('Pending', 'Ready')
        WITH SYSTEM_MODE
      ];
      List<Map<String, Object>> rows = new List<Map<String, Object>>();
      for (Reservation__c r : [
        SELECT
          Name,
          Status__c,
          Queue_Position__c,
          Reservation_Date__c,
          Ready_Date__c,
          Expiry_Date__c,
          Book__r.Name,
          Member__r.Name,
          Member__r.First_Name__c,
          Member__r.Last_Name__c
        FROM Reservation__c
        WHERE Status__c IN ('Pending', 'Ready')
        WITH SYSTEM_MODE
        ORDER BY Reservation_Date__c ASC
        LIMIT 25
      ]) {
        rows.add(
          new Map<String, Object>{
            'reservationId' => r.Name,
            'memberId' => r.Member__r?.Name,
            'memberName' => memberName(r.Member__r),
            'book' => r.Book__r?.Name,
            'status' => r.Status__c,
            'queuePosition' => r.Queue_Position__c,
            'reservedOn' => r.Reservation_Date__c,
            'readyOn' => r.Ready_Date__c,
            'expiresOn' => r.Expiry_Date__c
          }
        );
      }
      return rows;
    }
  }
}
