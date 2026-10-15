@IsTest
private class LibrarySecurityServiceTest {
  @IsTest
  static void enforcesObjectAndFieldBoundaries() {
    LibrarySecurityService.requireForPermission('Manage_Library_Catalog');
    LibrarySecurityService.requireFields(
      Member__c.SObjectType,
      new List<String>{'First_Name__c', 'Last_Name__c', 'Phone__c', 'Address__c'},
      true
    );

    Member__c value = new Member__c(
      First_Name__c = 'Security',
      Last_Name__c = 'Test',
      Phone__c = '+91 9876543210',
      Address__c = 'Test address'
    );
    List<SObject> readable = LibrarySecurityService.readable(
      new List<SObject>{value}
    );
    System.assertEquals(1, readable.size());
  }
}
