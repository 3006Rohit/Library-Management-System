@IsTest
public class LibraryAgentPublishTest {
  @IsTest
  static void testMemberAgentActionsExist() {
    // Verify action classes are compiled and deployable
    System.assertNotEquals(
      null,
      LibraryAgentMyActivityAction.class,
      'MyActivityAction exists'
    );
    System.assertNotEquals(
      null,
      LibraryAgentMyLoansAction.class,
      'MyLoansAction exists'
    );
    System.assertNotEquals(
      null,
      LibraryAgentMyReservationsAction.class,
      'MyReservationsAction exists'
    );
  }

  @IsTest
  static void testLibrarianAgentActionsExist() {
    // Verify librarian action classes are compiled and deployable
    System.assertNotEquals(
      null,
      LibraryAgentAnalyticsAction.class,
      'AnalyticsAction exists'
    );
    System.assertNotEquals(
      null,
      LibraryAgentCatalogAction.class,
      'CatalogAction exists'
    );
    System.assertNotEquals(
      null,
      LibraryAgentConfirmationAction.class,
      'ConfirmationAction exists'
    );
  }
}
