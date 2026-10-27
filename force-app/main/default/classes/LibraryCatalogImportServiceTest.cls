@IsTest
private class LibraryCatalogImportServiceTest {
  @IsTest
  static void previewRejectsDuplicateAndCommitIsIdempotent() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    String csv = 'title,isbn,publisher,publicationYear\n"The First Book",IMPORT-001,Press,2024\n,IMPORT-002,Press,2024';
    List<LibraryCatalogImportService.RowDTO> preview = LibraryCatalogImportService.preview(
      csv
    );
    System.assertEquals(2, preview.size());
    System.assertEquals('Valid', preview[0].status);
    System.assertEquals('Invalid', preview[1].status);
    String validCsv = 'title,isbn,publisher,publicationYear\nThe First Book,IMPORT-001,Press,2024';
    LibraryCatalogImportService.ImportDTO first = LibraryCatalogImportService.executeImport(
      'import-test-001',
      validCsv
    );
    LibraryCatalogImportService.ImportDTO second = LibraryCatalogImportService.executeImport(
      'import-test-001',
      validCsv
    );
    System.assertEquals(1, first.created);
    System.assertEquals(first.auditId, second.auditId);
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Book__c WHERE ISBN__c = 'IMPORT-001']
    );
  }
}
