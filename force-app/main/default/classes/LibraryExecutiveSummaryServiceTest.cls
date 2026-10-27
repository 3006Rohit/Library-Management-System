@IsTest
private class LibraryExecutiveSummaryServiceTest {
  @IsTest
  static void dailySummaryIsIdempotentAndReadable() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Registrations'
    );
    Test.startTest();
    LibraryExecutiveSummaryService.SummaryDTO first = LibraryExecutiveSummaryService.generate();
    LibraryExecutiveSummaryService.SummaryDTO second = LibraryExecutiveSummaryService.generate();
    List<LibraryExecutiveSummaryService.SummaryDTO> recent = LibraryExecutiveSummaryService.getRecent(
      10
    );
    Test.stopTest();
    System.assertEquals(first.id, second.id);
    System.assertEquals(1, recent.size());
    System.assertEquals(Date.today(), first.reportingDate);
    System.assertNotEquals(null, first.activeMembers);
  }
}
