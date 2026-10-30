global without sharing class LibraryReservationExpiryBatch implements Database.Batchable<SObject> {
  global Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Reservation__c
        WHERE Status__c = 'Ready' AND Expiry_Date__c < :System.now()
        WITH SYSTEM_MODE
        ORDER BY Expiry_Date__c, Id
      ]
    );
  }

  global void execute(Database.BatchableContext context, List<SObject> scope) {
    Set<Id> ids = new Set<Id>();
    for (SObject row : scope)
      ids.add((Id) row.get('Id'));
    LibraryCirculationService.processExpiredReservationsBatch(ids);
  }

  global void finish(Database.BatchableContext context) {
  }
}
