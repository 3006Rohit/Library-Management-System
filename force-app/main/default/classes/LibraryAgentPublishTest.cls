@IsTest
public class LibraryAgentPublishTest {

    @IsTest
    static void testMemberAgentActions() {
        // Test member activity action
        LibraryAgentMyActivityAction activityAction = new LibraryAgentMyActivityAction();
        Map<String, Object> activityInput = new Map<String, Object>{
            'sessionToken' => 'test-token-123'
        };
        Map<String, Object> activityResult = (Map<String, Object>)activityAction.invoke(activityInput);
        System.assertNotEquals(null, activityResult, 'Activity action should return a result');

        // Test loans action
        LibraryAgentMyLoansAction loansAction = new LibraryAgentMyLoansAction();
        Map<String, Object> loansInput = new Map<String, Object>{
            'sessionToken' => 'test-token-123'
        };
        Map<String, Object> loansResult = (Map<String, Object>)loansAction.invoke(loansInput);
        System.assertNotEquals(null, loansResult, 'Loans action should return a result');

        // Test reservations action
        LibraryAgentMyReservationsAction reservationsAction = new LibraryAgentMyReservationsAction();
        Map<String, Object> reservationsInput = new Map<String, Object>{
            'sessionToken' => 'test-token-123'
        };
        Map<String, Object> reservationsResult = (Map<String, Object>)reservationsAction.invoke(reservationsInput);
        System.assertNotEquals(null, reservationsResult, 'Reservations action should return a result');
    }

    @IsTest
    static void testLibrarianAgentActions() {
        // Test analytics action
        LibraryAgentAnalyticsAction analyticsAction = new LibraryAgentAnalyticsAction();
        Map<String, Object> analyticsInput = new Map<String, Object>{
            'requestContext' => 'show overdues'
        };
        Map<String, Object> analyticsResult = (Map<String, Object>)analyticsAction.invoke(analyticsInput);
        System.assertNotEquals(null, analyticsResult, 'Analytics action should return a result');

        // Test catalog search
        LibraryAgentCatalogAction catalogAction = new LibraryAgentCatalogAction();
        Map<String, Object> catalogInput = new Map<String, Object>{
            'title' => 'Harry Potter'
        };
        Map<String, Object> catalogResult = (Map<String, Object>)catalogAction.invoke(catalogInput);
        System.assertNotEquals(null, catalogResult, 'Catalog action should return a result');
    }
}
