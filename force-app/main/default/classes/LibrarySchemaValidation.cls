public with sharing class LibrarySchemaValidation {
  public class Finding {
    @AuraEnabled
    public String target;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String detail;
    Finding(String target, String status, String detail) {
      this.target = target;
      this.status = status;
      this.detail = detail;
    }
  }
  @AuraEnabled(cacheable=true)
  public static List<Finding> validate() {
    List<Finding> findings = new List<Finding>();
    validateFields(
      'Notification_Delivery__c',
      new List<String>{
        'Member_Notification__c',
        'Channel__c',
        'Status__c',
        'Attempt__c',
        'Max_Attempts__c',
        'Next_Attempt_At__c',
        'Provider_Id__c',
        'Error_Code__c',
        'Idempotency_Key__c',
        'Attempted_At__c',
        'Delivered_At__c'
      },
      findings
    );
    validateFields(
      'Membership_Plan__c',
      new List<String>{
        'Active__c',
        'Fee__c',
        'Duration_Days__c',
        'Borrow_Limit__c',
        'Loan_Duration_Days__c',
        'Reservation_Limit__c',
        'Renewal_Limit__c',
        'Fine_Per_Day__c'
      },
      findings
    );
    validateFields(
      'Membership_Payment__c',
      new List<String>{
        'Member__c',
        'Previous_Plan__c',
        'New_Plan__c',
        'Amount__c',
        'Status__c',
        'Payment_Method__c',
        'Payment_Date__c',
        'Transaction_Reference__c',
        'Gateway_Payment_Id__c',
        'Refund_Amount__c',
        'Refund_Date__c',
        'Reconciliation_Status__c',
        'Idempotency_Key__c',
        'Gateway_Status__c'
      },
      findings
    );
    validateFields(
      'Member_Notification__c',
      new List<String>{
        'Member__c',
        'Type__c',
        'Subject__c',
        'Message__c',
        'Status__c',
        'Related_Record__c',
        'Dedup_Key__c',
        'Read_At__c'
      },
      findings
    );
    validateFields(
      'Notification_Preference__c',
      new List<String>{
        'Member__c',
        'Channel__c',
        'Notification_Type__c',
        'Enabled__c',
        'Digest_Frequency__c',
        'Quiet_Hours_Start__c',
        'Quiet_Hours_End__c',
        'Timezone__c',
        'Preference_Key__c',
        'Last_Updated__c'
      },
      findings
    );
    validateFields(
      'Library_Scan_Transaction__c',
      new List<String>{
        'Idempotency_Key__c',
        'Operation__c',
        'Member__c',
        'Book_Copy__c',
        'Borrow_Record__c',
        'Status__c',
        'Result_Message__c',
        'Created_At__c'
      },
      findings
    );
    validateFields(
      'Acquisition_Recommendation__c',
      new List<String>{
        'Book__c',
        'Recommendation_Type__c',
        'Recommendation_Score__c',
        'Recommended_Quantity__c',
        'Confidence__c',
        'Evidence__c',
        'Status__c',
        'Evidence_Window_Start__c',
        'Evidence_Window_End__c',
        'Refreshed_At__c',
        'Decision_Notes__c',
        'Decided_At__c',
        'Snapshot_Key__c'
      },
      findings
    );
    validateFields(
      'Search_Analytics__c',
      new List<String>{
        'Search_Hash__c',
        'Search_Result_Count__c',
        'Search_Status__c',
        'Searched_At__c',
        'Book__c'
      },
      findings
    );
    validateFields(
      'Reservation_Audit__c',
      new List<String>{
        'Reservation__c',
        'Action__c',
        'From_Status__c',
        'To_Status__c',
        'Queue_Position__c',
        'Actor__c',
        'Occurred_At__c',
        'Notes__c'
      },
      findings
    );
    validateRelationships(
      'Book__c',
      new List<String>{
        'Book_Authors__r',
        'Book_Category_Links__r',
        'Book_Copies__r'
      },
      findings
    );
    validateFields(
      'Fine__c',
      new List<String>{
        'Borrow_Record__c',
        'Member__c',
        'Fine_Type__c',
        'Amount__c',
        'Paid_Amount__c',
        'Balance__c',
        'Status__c'
      },
      findings
    );
    return findings;
  }
  private static void validateFields(
    String objectName,
    List<String> names,
    List<Finding> findings
  ) {
    Schema.SObjectType type = Schema.getGlobalDescribe().get(objectName);
    if (type == null) {
      findings.add(new Finding(objectName, 'ERROR', 'Object is missing.'));
      return;
    }
    Map<String, Schema.SObjectField> fields = type.getDescribe()
      .fields.getMap();
    Boolean complete = true;
    for (String name : names) {
      Boolean present = fields.containsKey(name);
      complete = complete && present;
      findings.add(
        new Finding(
          objectName + '.' + name,
          present ? 'PASS' : 'ERROR',
          present ? 'Field exists.' : 'Field is missing from the deployed org.'
        )
      );
    }
    findings.add(
      new Finding(
        objectName + '.SCHEMA',
        complete ? 'PASS' : 'ERROR',
        complete
          ? 'All expected fields are present in the runtime schema.'
          : 'One or more expected fields are absent from the runtime schema.'
      )
    );
  }
  private static void validateRelationships(
    String objectName,
    List<String> names,
    List<Finding> findings
  ) {
    Schema.SObjectType type = Schema.getGlobalDescribe().get(objectName);
    if (type == null) {
      findings.add(new Finding(objectName, 'ERROR', 'Object is missing.'));
      return;
    }
    Set<String> relationships = new Set<String>();
    for (
      Schema.ChildRelationship child : type.getDescribe()
        .getChildRelationships()
    )
      if (child.getRelationshipName() != null)
        relationships.add(child.getRelationshipName());
    for (String name : names)
      findings.add(
        new Finding(
          objectName + '.' + name,
          relationships.contains(name) ? 'PASS' : 'ERROR',
          relationships.contains(name)
            ? 'Child relationship exists.'
            : 'Child relationship name does not match the deployed schema.'
        )
      );
  }
}
