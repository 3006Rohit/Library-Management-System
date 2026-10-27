@IsTest
private class LibraryStocktakeServiceTest {
  @IsTest
  static void stocktakeScansIdempotentlyAndClosesWithDiscrepancy() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Book__c book = new Book__c(
      Name = 'Stocktake Book',
      ISBN__c = 'STOCK-001',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'STOCK-BAR-001',
      Status__c = 'Available',
      Condition__c = 'Good'
    );
    insert copy;
    LibraryStocktakeService.AuditDTO audit = LibraryStocktakeService.start(
      'October Stocktake',
      'Main shelf'
    );
    LibraryStocktakeService.LineDTO first = LibraryStocktakeService.scan(
      audit.id,
      copy.Barcode__c,
      'Borrowed',
      'Observed on loan cart.'
    );
    LibraryStocktakeService.LineDTO second = LibraryStocktakeService.scan(
      audit.id,
      copy.Barcode__c,
      'Borrowed',
      'Retry should be idempotent.'
    );
    System.assertEquals(first.id, second.id);
    System.assertEquals(true, first.discrepancy);
    System.assertEquals(1, LibraryStocktakeService.getLines(audit.id).size());
    LibraryStocktakeService.close(
      audit.id,
      'Reviewed discrepancy and opened a follow-up investigation.'
    );
    System.assertEquals(
      'Closed',
      [SELECT Status__c FROM Library_Scan_Transaction__c WHERE Id = :audit.id]
      .Status__c
    );
  }
}
