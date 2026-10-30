public with sharing class LibraryLedgerMigrationReadinessService {
  public class OperationDTO {
    @AuraEnabled
    public String operation;
    @AuraEnabled
    public Integer totalRows;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String plannedTarget;
    @AuraEnabled
    public Boolean targetAvailable;
  }

  public class StatusDTO {
    @AuraEnabled
    public Boolean ready;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer totalRows;
    @AuraEnabled
    public Integer migratableRows;
    @AuraEnabled
    public Integer malformedRows;
    @AuraEnabled
    public Integer unknownOperationRows;
    @AuraEnabled
    public Datetime generatedAt;
    @AuraEnabled
    public List<String> blockers;
    @AuraEnabled
    public List<OperationDTO> operations;
  }

  private static final Set<String> KNOWN_OPERATIONS = new Set<String>{
    'Self Checkout',
    'Self Return',
    'Member Card',
    'Reading List',
    'Author Follow',
    'Book Review',
    'Library Event',
    'Event Registration',
    'Library Room',
    'Room Booking',
    'Reading Challenge',
    'Challenge Enrollment',
    'Challenge Achievement',
    'Challenge Preference',
    'Library Branch',
    'Branch Inventory',
    'Branch Transfer',
    'Fine Appeal',
    'Membership Hold',
    'No-show Processing',
    'Library Closure',
    'Privacy Request',
    'Operation Audit',
    'Risk Alert',
    'Executive Summary',
    'Payment Receipt',
    'Catalog Import',
    'Stocktake Audit',
    'Stocktake Line',
    'Copy Repair',
    'Catalog Metadata',
    'Payment Webhook',
    'Payment Refund'
  };
  private static final Map<String, String> PLANNED_TARGETS = new Map<String, String>{
    'Reading List' => 'Member_Book_Engagement__c',
    'Author Follow' => 'Author_Follow__c',
    'Book Review' => 'Book_Review__c',
    'Library Event' => 'Library_Event__c',
    'Event Registration' => 'Event_Registration__c',
    'Library Room' => 'Library_Room__c',
    'Room Booking' => 'Room_Booking__c',
    'Reading Challenge' => 'Reading_Challenge__c',
    'Challenge Enrollment' => 'Challenge_Enrollment__c',
    'Library Branch' => 'Library_Branch__c',
    'Branch Transfer' => 'Branch_Transfer__c',
    'Fine Appeal' => 'Fine_Appeal__c',
    'Membership Hold' => 'Membership_Hold__c',
    'No-show Processing' => 'No_Show_Processing__c',
    'Library Closure' => 'Library_Closure__c',
    'Privacy Request' => 'Privacy_Request__c',
    'Operation Audit' => 'Library_Operation_Audit__c',
    'Risk Alert' => 'Library_Risk_Alert__c',
    'Executive Summary' => 'Executive_Summary__c',
    'Payment Receipt' => 'Payment_Receipt__c',
    'Catalog Import' => 'Catalog_Import__c',
    'Stocktake Audit' => 'Stocktake_Audit__c',
    'Stocktake Line' => 'Stocktake_Line__c',
    'Copy Repair' => 'Copy_Repair__c'
  };

  public static StatusDTO getStatus() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    StatusDTO result = new StatusDTO();
    result.generatedAt = System.now();
    result.blockers = new List<String>();
    result.operations = new List<OperationDTO>();
    result.totalRows = [SELECT COUNT() FROM Library_Scan_Transaction__c WITH SYSTEM_MODE];
    Integer knownRows = [
      SELECT COUNT()
      FROM Library_Scan_Transaction__c
      WHERE Operation__c IN :KNOWN_OPERATIONS
      WITH SYSTEM_MODE
    ];
    result.unknownOperationRows = result.totalRows - knownRows;
    result.malformedRows = [
      SELECT COUNT()
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = NULL
        OR Status__c = NULL
        OR Idempotency_Key__c = NULL
        OR Created_At__c = NULL
      WITH SYSTEM_MODE
    ];
    result.migratableRows = [
      SELECT COUNT()
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c IN :KNOWN_OPERATIONS
        AND Status__c != NULL
        AND Idempotency_Key__c != NULL
        AND Created_At__c != NULL
      WITH SYSTEM_MODE
    ];
    if (result.unknownOperationRows > 0)
      result.blockers.add(
        String.valueOf(result.unknownOperationRows) +
        ' ledger rows use an unknown operation and require migration review.'
      );
    if (result.malformedRows > 0)
      result.blockers.add(
        String.valueOf(result.malformedRows) +
        ' ledger rows are missing stable migration metadata.'
      );
    for (AggregateResult row : [
      SELECT Operation__c operation, COUNT(Id) total
      FROM Library_Scan_Transaction__c
      WITH SYSTEM_MODE
      GROUP BY Operation__c
      ORDER BY COUNT(Id) DESC
      LIMIT 50
    ]) {
      String operation = (String) row.get('operation');
      OperationDTO summary = new OperationDTO();
      summary.operation = String.isBlank(operation) ? '(blank)' : operation;
      summary.totalRows = Integer.valueOf(String.valueOf(row.get('total')));
      summary.plannedTarget = PLANNED_TARGETS.containsKey(operation)
        ? PLANNED_TARGETS.get(operation)
        : 'Dedicated target metadata pending';
      summary.targetAvailable = PLANNED_TARGETS.containsKey(operation)
        ? isTargetAvailable(summary.plannedTarget)
        : null;
      if (!KNOWN_OPERATIONS.contains(operation)) {
        summary.status = 'Review required';
      } else if (!PLANNED_TARGETS.containsKey(operation)) {
        summary.status = 'Known operation; target pending';
      } else if (summary.targetAvailable) {
        summary.status = 'Known migration target';
      } else {
        summary.status = 'Target object not deployed';
        result.blockers.add(
          summary.operation +
            ' has ' +
            String.valueOf(summary.totalRows) +
            ' row(s), but ' +
            summary.plannedTarget +
            ' is not deployed in this org.'
        );
      }
      result.operations.add(summary);
    }
    result.ready = result.blockers.isEmpty();
    result.status = result.ready ? 'Ready for migration planning' : 'Blocked';
    return result;
  }

  private static Boolean isTargetAvailable(String targetName) {
    if (String.isBlank(targetName))
      return false;
    return Schema.getGlobalDescribe().containsKey(targetName);
  }
}
