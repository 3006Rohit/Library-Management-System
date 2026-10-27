@IsTest
private class LibraryCalendarServiceTest {
  @IsTest
  static void closureDatesShiftDueDateAndRemainIdempotent() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Date closureStart = Date.newInstance(2026, 3, 16);
    Date closureEnd = Date.newInstance(2026, 3, 18);
    Id first = LibraryCalendarService.createClosure(
      'Spring maintenance',
      closureStart,
      closureEnd,
      null,
      'Asia/Kolkata',
      false
    );
    Id second = LibraryCalendarService.createClosure(
      'A different label is idempotent',
      closureStart,
      closureEnd,
      null,
      'UTC',
      true
    );
    System.assertEquals(first, second);
    System.assertEquals(
      Date.newInstance(2026, 3, 19),
      LibraryCalendarService.calculateDueDate(
        Date.newInstance(2026, 3, 1),
        15,
        null
      )
    );
    System.assertEquals(
      Date.newInstance(2028, 2, 29),
      LibraryCalendarService.calculateDueDate(
        Date.newInstance(2028, 2, 1),
        28,
        null
      )
    );
    System.assertEquals(1, LibraryCalendarService.getClosures().size());
  }

  @IsTest
  static void branchClosuresOnlyApplyToTheirBranch() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Id branchId = LibraryBranchService.createBranch(
      'CAL',
      'Calendar Branch',
      'Main Street',
      'UTC'
    );
    LibraryCalendarService.createClosure(
      'Branch emergency closure',
      Date.newInstance(2026, 5, 4),
      Date.newInstance(2026, 5, 5),
      branchId,
      'UTC',
      true
    );
    Date base = Date.newInstance(2026, 4, 20);
    System.assertEquals(
      Date.newInstance(2026, 5, 6),
      LibraryCalendarService.calculateDueDate(base, 14, branchId)
    );
    System.assertEquals(
      Date.newInstance(2026, 5, 4),
      LibraryCalendarService.calculateDueDate(base, 14, null)
    );
  }
}
