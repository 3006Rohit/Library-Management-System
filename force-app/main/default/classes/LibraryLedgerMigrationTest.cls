@IsTest
private class LibraryLedgerMigrationTest {
  @IsTest
  static void reportsKnownAndMalformedLedgerRows() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    insert new List<Library_Scan_Transaction__c>{
      new Library_Scan_Transaction__c(
        Operation__c = 'Reading List',
        Idempotency_Key__c = 'migration-known',
        Status__c = 'Completed',
        Created_At__c = System.now()
      ),
      new Library_Scan_Transaction__c(
        Operation__c = 'Legacy Unknown',
        Idempotency_Key__c = 'migration-unknown',
        Status__c = 'Completed',
        Created_At__c = System.now()
      ),
      new Library_Scan_Transaction__c(
        Operation__c = 'Reading List',
        Idempotency_Key__c = 'migration-malformed',
        Created_At__c = System.now()
      )
    };

    Test.startTest();
    LibraryLedgerMigrationReadinessService.StatusDTO status = LibraryLedgerMigrationReadinessService.getStatus();
    Test.stopTest();

    System.assertEquals(3, status.totalRows);
    System.assertEquals(1, status.migratableRows);
    System.assertEquals(1, status.unknownOperationRows);
    System.assertEquals(1, status.malformedRows);
    System.assertEquals(false, status.ready);
    System.assertEquals('Blocked', status.status);
    System.assertEquals(2, status.blockers.size());
    System.assertEquals(2, status.operations.size());
    Boolean foundKnown = false;
    for (
      LibraryLedgerMigrationReadinessService.OperationDTO operation : status.operations
    ) {
      if (operation.operation == 'Reading List') {
        foundKnown = true;
        System.assertEquals('Known migration target', operation.status);
        System.assertEquals(
          'Member_Book_Engagement__c',
          operation.plannedTarget
        );
        System.assertEquals(true, operation.targetAvailable);
      }
    }
    System.assertEquals(true, foundKnown);
  }
}
