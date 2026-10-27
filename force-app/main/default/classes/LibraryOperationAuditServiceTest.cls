@IsTest
private class LibraryOperationAuditServiceTest {
  @IsTest
  static void recordsSafeIdempotentAudit() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Registrations'
    );
    Map<String, Object> beforeState = new Map<String, Object>{
      'status' => 'Pending',
      'password' => 'never-store-this',
      'token' => 'never-store-this-either'
    };
    Map<String, Object> afterState = new Map<String, Object>{
      'status' => 'Approved',
      'count' => 2
    };
    Id first = LibraryOperationAuditService.record(
      'Test Operation',
      'Manage_Library_Catalog',
      null,
      'audit-test-correlation',
      'Reviewed by librarian',
      'Approved',
      beforeState,
      afterState
    );
    Id second = LibraryOperationAuditService.record(
      'Test Operation',
      'Manage_Library_Catalog',
      null,
      'audit-test-correlation',
      'Reviewed by librarian',
      'Approved',
      beforeState,
      afterState
    );
    System.assertEquals(first, second);
    List<LibraryOperationAuditService.AuditDTO> rows = LibraryOperationAuditService.getRecent(
      'Test Operation',
      null,
      10
    );
    System.assertEquals(1, rows.size());
    System.assertEquals('Approved', rows[0].result);
    System.assertNotEquals(null, rows[0].beforeDigest);
    System.assertNotEquals(null, rows[0].afterDigest);
    Library_Scan_Transaction__c raw = [
      SELECT Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :first
    ];
    System.assert(!raw.Result_Message__c.contains('never-store-this'));
  }
}
