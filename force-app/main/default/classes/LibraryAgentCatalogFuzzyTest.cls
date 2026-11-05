@IsTest
private class LibraryAgentCatalogFuzzyTest {
  @TestSetup
  static void setup() {
    insert new List<Book__c>{
      new Book__c(
        Name = 'A Quiet Season',
        Status__c = 'Active',
        Total_Copies__c = 5,
        Available_Copies__c = 5
      ),
      new Book__c(
        Name = 'A Short History of Trade',
        Status__c = 'Active',
        Total_Copies__c = 2,
        Available_Copies__c = 2
      ),
      new Book__c(
        Name = 'Season of Storms',
        Status__c = 'Active',
        Total_Copies__c = 2,
        Available_Copies__c = 0
      )
    };
  }

  private static List<LibraryAgentCatalogAction.BookResult> search(
    String title,
    Boolean availableOnly
  ) {
    LibraryAgentCatalogAction.Request req = new LibraryAgentCatalogAction.Request();
    req.title = title;
    req.availableOnly = availableOnly;
    return LibraryAgentCatalogAction.execute(
      new List<LibraryAgentCatalogAction.Request>{ req }
    );
  }

  @IsTest
  static void misspelledTitleStillFindsTheBookFirst() {
    List<LibraryAgentCatalogAction.BookResult> rows = search(
      'A Quite Season',
      false
    );
    System.assert(!rows.isEmpty(), 'typo should still match');
    System.assertEquals('A Quiet Season', rows[0].title);
  }

  @IsTest
  static void exactSearchIsUnchanged() {
    List<LibraryAgentCatalogAction.BookResult> rows = search(
      'Quiet Season',
      false
    );
    System.assertEquals(1, rows.size());
    System.assertEquals('A Quiet Season', rows[0].title);
  }

  @IsTest
  static void fuzzyFallbackRespectsAvailableOnly() {
    List<LibraryAgentCatalogAction.BookResult> rows = search(
      'Seasn of Storms',
      true
    );
    for (LibraryAgentCatalogAction.BookResult row : rows) {
      System.assertNotEquals('Season of Storms', row.title);
    }
  }

  @IsTest
  static void nonsenseTitleReturnsNothing() {
    System.assert(search('zzzzqq xxwwvv', false).isEmpty());
  }

  @IsTest
  static void onlyStopWordsReturnsNothing() {
    System.assert(search('the and', false).isEmpty());
  }
}
