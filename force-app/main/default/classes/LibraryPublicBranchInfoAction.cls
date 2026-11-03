global with sharing class LibraryPublicBranchInfoAction {
  private static final String BRANCH_OPERATION = 'Library Branch';

  global class Request {
    @InvocableVariable(label='Branch name or code (optional)')
    public String branch;
  }
  global class BranchResult {
    @InvocableVariable
    public String name;
    @InvocableVariable
    public String code;
    @InvocableVariable
    public String address;
    @InvocableVariable
    public String openingHours;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Get Library Branch Info'
    description='Use for public questions about library branch names, locations and addresses. Returns public branch data only; never returns member or authentication data. Opening hours are reported only when published.'
  )
  global static List<BranchResult> execute(List<Request> requests) {
    try {
      return executeInternal(requests);
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_PUBLIC_BRANCH_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
      return new List<BranchResult>{
        messageOnly('Branch information is temporarily unavailable.')
      };
    }
  }

  private static List<BranchResult> executeInternal(List<Request> requests) {
    String filter = requests == null ||
      requests.isEmpty() ||
      requests[0] == null ||
      String.isBlank(requests[0].branch)
      ? null
      : requests[0].branch.trim().toLowerCase();
    List<BranchResult> output = new List<BranchResult>();
    for (Library_Scan_Transaction__c row : [
      SELECT Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :BRANCH_OPERATION AND Status__c = 'Active'
      WITH SYSTEM_MODE
      ORDER BY Created_At__c ASC
      LIMIT 50
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      BranchResult result = new BranchResult();
      result.code = text(payload.get('c'));
      result.name = text(payload.get('n'));
      result.address = text(payload.get('a'));
      result.openingHours = text(payload.get('h'));
      if (
        filter != null &&
        !(result.name.toLowerCase().contains(filter) ||
        result.code.toLowerCase().contains(filter))
      )
        continue;
      if (String.isBlank(result.openingHours))
        result.message = 'Opening hours are not published for this branch; please contact the library desk.';
      output.add(result);
    }
    if (output.isEmpty())
      output.add(messageOnly('No matching branch was found.'));
    return output;
  }

  private static BranchResult messageOnly(String message) {
    BranchResult result = new BranchResult();
    result.message = message;
    return result;
  }
  private static Map<String, Object> parse(String raw) {
    if (String.isBlank(raw))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }
  private static String text(Object value) {
    return value == null ? '' : String.valueOf(value);
  }
}
