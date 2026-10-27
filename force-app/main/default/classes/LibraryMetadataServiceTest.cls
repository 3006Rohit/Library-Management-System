@IsTest
private class LibraryMetadataServiceTest {
  private class MetadataMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody(
        '{"title":"The Test Library","subtitle":"A Catalog","publishers":["Open Books"],"publish_date":"2024-06-01","authors":[{"name":"A. Reader"}],"languages":[{"key":"/languages/eng"}],"subjects":["Libraries","Testing"],"description":{"value":"A test description."},"covers":[12345],"edition_name":"Second edition"}'
      );
      return response;
    }
  }

  @IsTest
  static void normalizesValidatesAndMapsProviderData() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    System.assertEquals(
      '9780306406157',
      LibraryMetadataService.normalize('978-0-306-40615-7')
    );
    System.assert(LibraryMetadataService.isValid('9780306406157'));
    System.assert(!LibraryMetadataService.isValid('9780306406158'));
    Test.setMock(HttpCalloutMock.class, new MetadataMock());
    Test.startTest();
    LibraryMetadataService.MetadataDTO result = LibraryMetadataService.lookup(
      '978-0-306-40615-7'
    );
    Test.stopTest();
    System.assertEquals('The Test Library', result.title);
    System.assertEquals('English', result.language);
    System.assertEquals(2024, result.publicationYear);
    System.assertEquals(6, result.qualityScore);
  }

  @IsTest
  static void invalidIsbnIsRejectedBeforeCallout() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    try {
      LibraryMetadataService.lookup('9780306406158');
      System.assert(false, 'Expected invalid ISBN error');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected);
    }
  }

  @IsTest
  static void appliesOnlySelectedFields() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Book__c book = new Book__c(
      Name = 'Curated Title',
      ISBN__c = '9780306406157',
      Status__c = 'Active',
      Total_Copies__c = 0,
      Available_Copies__c = 0,
      Publisher__c = 'Old Publisher'
    );
    insert book;
    LibraryMetadataService.apply(
      book.Id,
      'publisher,description',
      '9780306406157',
      'Provider Title',
      'New Publisher',
      2024,
      null,
      null,
      'New description',
      null
    );
    Book__c saved = [
      SELECT Name, Publisher__c, Description__c
      FROM Book__c
      WHERE Id = :book.Id
    ];
    System.assertEquals('Curated Title', saved.Name);
    System.assertEquals('New Publisher', saved.Publisher__c);
    System.assertEquals('New description', saved.Description__c);
  }
}
