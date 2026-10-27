@IsTest
private class LibraryRepairServiceTest {
  @IsTest
  static void repairCaseOpensIdempotentlyAndResolves() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Book__c book = new Book__c(
      Name = 'Repair Book',
      ISBN__c = 'REPAIR-001',
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 0
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'REPAIR-BAR-001',
      Status__c = 'Damaged',
      Condition__c = 'Poor'
    );
    insert copy;

    LibraryRepairService.RepairDTO opened = LibraryRepairService.open(
      copy.Id,
      'Water damage requires inspection.'
    );
    LibraryRepairService.RepairDTO retry = LibraryRepairService.open(
      copy.Id,
      'This retry must not create a duplicate.'
    );
    System.assertEquals('Open', opened.status);
    System.assertEquals(opened.id, retry.id);
    System.assertEquals(
      'Maintenance',
      [SELECT Status__c FROM Book_Copy__c WHERE Id = :copy.Id].Status__c
    );

    LibraryRepairService.resolve(
      opened.id,
      'Replaced cover',
      'Repaired',
      'Cover replaced and copy passed inspection.'
    );
    Book_Copy__c repaired = [
      SELECT Status__c, Condition__c
      FROM Book_Copy__c
      WHERE Id = :copy.Id
    ];
    System.assertEquals('Available', repaired.Status__c);
    System.assertEquals('Good', repaired.Condition__c);
    System.assertEquals(1, LibraryRepairService.getAll('Repaired').size());
  }
}
