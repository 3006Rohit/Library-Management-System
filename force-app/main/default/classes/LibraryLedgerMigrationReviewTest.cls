@IsTest
private class LibraryLedgerMigrationReviewTest {
  @IsTest
  static void reviewIsIdempotentAndReadable() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    Datetime generatedAt = System.now().addMinutes(-2);

    Test.startTest();
    LibraryLedgerMigrationReviewService.ReviewDTO first = LibraryLedgerMigrationReviewService.recordReview(
      '2026-10-17-v1',
      generatedAt,
      'Reviewed for target-object planning.',
      3,
      1,
      2
    );
    LibraryLedgerMigrationReviewService.ReviewDTO second = LibraryLedgerMigrationReviewService.recordReview(
      '2026-10-17-v1',
      generatedAt,
      'Reviewed for target-object planning.',
      3,
      1,
      2
    );
    LibraryLedgerMigrationReviewService.ReviewDTO latest = LibraryLedgerMigrationReviewService.getLatestReview();
    Test.stopTest();

    System.assertEquals(first.auditId, second.auditId);
    System.assertEquals(first.auditId, latest.auditId);
    System.assertEquals('Reviewed', latest.status);
    System.assertEquals('2026-10-17-v1', latest.manifestVersion);
    System.assertEquals(
      'Reviewed for target-object planning.',
      latest.reviewNote
    );
  }
}
