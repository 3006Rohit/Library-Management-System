public with sharing class LibraryDataCloudReadinessService {
  public class InsightDTO {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String purpose;
    @AuraEnabled
    public String sources;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String reason;
  }

  public class StatusDTO {
    @AuraEnabled
    public Boolean ready;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer totalMembers;
    @AuraEnabled
    public Integer productionMembers;
    @AuraEnabled
    public Integer unclassifiedMembers;
    @AuraEnabled
    public Integer productionMembersMissingEmail;
    @AuraEnabled
    public Integer nonProductionLoans;
    @AuraEnabled
    public Integer nonProductionReservations;
    @AuraEnabled
    public Integer nonProductionFines;
    @AuraEnabled
    public Integer productionLoans;
    @AuraEnabled
    public Integer productionReservations;
    @AuraEnabled
    public Integer productionFines;
    @AuraEnabled
    public Integer orphanLoans;
    @AuraEnabled
    public Integer orphanReservations;
    @AuraEnabled
    public Integer orphanFines;
    @AuraEnabled
    public List<String> blockers;
    @AuraEnabled
    public List<String> warnings;
    @AuraEnabled
    public Datetime generatedAt;
    @AuraEnabled
    public String handoffVersion;
    @AuraEnabled
    public String productionMemberFilter;
    @AuraEnabled
    public String productionChildFilter;
    @AuraEnabled
    public List<String> governedSources;
    @AuraEnabled
    public List<String> deferredSources;
    @AuraEnabled
    public String calculatedInsightStatus;
    @AuraEnabled
    public List<InsightDTO> calculatedInsights;
  }

  public static StatusDTO getStatus() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    StatusDTO result = new StatusDTO();
    result.blockers = new List<String>();
    result.warnings = new List<String>();
    result.generatedAt = System.now();
    result.handoffVersion = '2026-10-17-v1';
    result.productionMemberFilter = 'Member_Type__c = Production';
    result.productionChildFilter = 'Member__r.Member_Type__c = Production';
    result.governedSources = new List<String>{
      'Member__c',
      'Membership_Plan__c',
      'Borrow_Record__c',
      'Reservation__c',
      'Fine__c',
      'Book__c'
    };
    result.deferredSources = new List<String>{
      'Membership_Payment__c',
      'Member_Session__c',
      'Contact Point Phone'
    };
    result.totalMembers = [SELECT COUNT() FROM Member__c WITH SYSTEM_MODE];
    result.productionMembers = [
      SELECT COUNT()
      FROM Member__c
      WHERE Member_Type__c = 'Production'
      WITH SYSTEM_MODE
    ];
    result.unclassifiedMembers = [
      SELECT COUNT()
      FROM Member__c
      WHERE Member_Type__c = NULL
      WITH SYSTEM_MODE
    ];
    result.productionMembersMissingEmail = [
      SELECT COUNT()
      FROM Member__c
      WHERE
        Member_Type__c = 'Production'
        AND (Email__c = NULL
        OR Email_Verified__c = FALSE)
      WITH SYSTEM_MODE
    ];
    result.nonProductionLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Member__c != NULL AND Member__r.Member_Type__c != 'Production'
      WITH SYSTEM_MODE
    ];
    result.productionLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Member__c != NULL AND Member__r.Member_Type__c = 'Production'
      WITH SYSTEM_MODE
    ];
    result.orphanLoans = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Member__c = NULL
      WITH SYSTEM_MODE
    ];
    result.nonProductionReservations = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE Member__c != NULL AND Member__r.Member_Type__c != 'Production'
      WITH SYSTEM_MODE
    ];
    result.productionReservations = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE Member__c != NULL AND Member__r.Member_Type__c = 'Production'
      WITH SYSTEM_MODE
    ];
    result.orphanReservations = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE Member__c = NULL
      WITH SYSTEM_MODE
    ];
    result.nonProductionFines = [
      SELECT COUNT()
      FROM Fine__c
      WHERE Member__c != NULL AND Member__r.Member_Type__c != 'Production'
      WITH SYSTEM_MODE
    ];
    result.productionFines = [
      SELECT COUNT()
      FROM Fine__c
      WHERE Member__c != NULL AND Member__r.Member_Type__c = 'Production'
      WITH SYSTEM_MODE
    ];
    result.orphanFines = [
      SELECT COUNT()
      FROM Fine__c
      WHERE Member__c = NULL
      WITH SYSTEM_MODE
    ];
    if (result.productionMembers == 0)
      result.blockers.add('No Production members are available for ingestion.');
    if (result.unclassifiedMembers > 0)
      result.blockers.add(
        String.valueOf(result.unclassifiedMembers) +
        ' members have no Member Type and must be classified.'
      );
    if (result.nonProductionLoans > 0)
      result.blockers.add(
        String.valueOf(result.nonProductionLoans) +
        ' loan records require a Production-member source filter.'
      );
    if (result.nonProductionReservations > 0)
      result.blockers.add(
        String.valueOf(result.nonProductionReservations) +
        ' reservation records require a Production-member source filter.'
      );
    if (result.nonProductionFines > 0)
      result.blockers.add(
        String.valueOf(result.nonProductionFines) +
        ' fine records require a Production-member source filter.'
      );
    if (result.orphanLoans > 0)
      result.blockers.add(
        String.valueOf(result.orphanLoans) +
        ' loan records have no Member relationship for insight mapping.'
      );
    if (result.orphanReservations > 0)
      result.blockers.add(
        String.valueOf(result.orphanReservations) +
        ' reservation records have no Member relationship for insight mapping.'
      );
    if (result.orphanFines > 0)
      result.blockers.add(
        String.valueOf(result.orphanFines) +
        ' fine records have no Member relationship for insight mapping.'
      );
    if (result.productionMembersMissingEmail > 0)
      result.warnings.add(
        String.valueOf(result.productionMembersMissingEmail) +
        ' Production members are missing a verified email.'
      );
    result.ready = result.blockers.isEmpty();
    result.status = result.ready
      ? result.warnings.isEmpty() ? 'Ready' : 'Ready with warnings'
      : 'Blocked';
    result.calculatedInsightStatus = result.ready
      ? 'Ready for setup review'
      : 'Blocked by source quality';
    result.calculatedInsights = buildInsightCatalog(result.ready);
    return result;
  }

  private static List<InsightDTO> buildInsightCatalog(Boolean sourceReady) {
    List<InsightDTO> insights = new List<InsightDTO>();
    addInsight(
      insights,
      'Active loan count',
      'Count active and overdue loans by member.',
      'Borrow_Record__c + Member__c',
      sourceReady
    );
    addInsight(
      insights,
      'Overdue count and days',
      'Count overdue loans and measure maximum overdue days.',
      'Borrow_Record__c + Book_Copy__c',
      sourceReady
    );
    addInsight(
      insights,
      'Outstanding fine balance',
      'Sum governed outstanding fine balances by member.',
      'Fine__c + Member__c',
      sourceReady
    );
    addInsight(
      insights,
      'Reservation activity',
      'Measure pending, ready, fulfilled, and expired demand.',
      'Reservation__c + Member__c + Book__c',
      sourceReady
    );
    addInsight(
      insights,
      'Book popularity',
      'Compare governed loan and reservation demand by book.',
      'Borrow_Record__c + Reservation__c + Book__c',
      sourceReady
    );
    return insights;
  }

  private static void addInsight(
    List<InsightDTO> insights,
    String name,
    String purpose,
    String sources,
    Boolean sourceReady
  ) {
    InsightDTO insight = new InsightDTO();
    insight.name = name;
    insight.purpose = purpose;
    insight.sources = sources;
    insight.status = sourceReady
      ? 'Ready for setup review'
      : 'Blocked by source quality';
    insight.reason = sourceReady
      ? 'Source checks passed; create and validate this insight in Data Cloud.'
      : 'Resolve readiness blockers before creating this insight in Data Cloud.';
    insights.add(insight);
  }
}
