@IsTest
private class LibraryContactControllerTest {
  @IsTest
  static void submitMessageCreatesWebCase() {
    Test.startTest();
    LibraryContactController.submitMessage(
      'Jane',
      'Doe',
      'jane@example.com',
      '555-0100',
      'Opening hours',
      'What time do you open on Sunday?'
    );
    Test.stopTest();

    Case created = [
      SELECT Origin, Subject, Description, SuppliedName, SuppliedEmail
      FROM Case
      LIMIT 1
    ];
    System.assertEquals('Web', created.Origin);
    System.assertEquals('Opening hours', created.Subject);
    System.assertEquals('Jane Doe', created.SuppliedName);
    System.assertEquals('jane@example.com', created.SuppliedEmail);
  }

  @IsTest
  static void submitMessageUsesDefaultSubject() {
    LibraryContactController.submitMessage(
      'Jane',
      'Doe',
      'jane@example.com',
      null,
      null,
      'Hello'
    );
    System.assertEquals(
      'Library website enquiry',
      [SELECT Subject FROM Case LIMIT 1].Subject
    );
  }

  @IsTest
  static void submitMessageRejectsInvalidInput() {
    assertRejected(null, 'Doe', 'jane@example.com', 'Hi');
    assertRejected('Jane', 'Doe', 'not-an-email', 'Hi');
    assertRejected('Jane', 'Doe', 'jane@example.com', '   ');
    assertRejected('Jane', 'Doe', 'jane@example.com', 'x'.repeat(4001));
    System.assertEquals(0, [SELECT COUNT() FROM Case]);
  }

  @IsTest
  static void getBranchesReturnsAList() {
    System.assertNotEquals(null, LibraryContactController.getBranches());
  }

  private static void assertRejected(
    String first,
    String last,
    String email,
    String message
  ) {
    try {
      LibraryContactController.submitMessage(
        first,
        last,
        email,
        null,
        null,
        message
      );
      System.assert(false, 'Expected the submission to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }
}
