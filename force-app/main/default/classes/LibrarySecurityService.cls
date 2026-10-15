public with sharing class LibrarySecurityService {
  public static void requireForPermission(String permission) {
    if (permission == 'Manage_Library_Catalog') {
      requireObject(Book__c.SObjectType, true, true);
      requireObject(Book_Copy__c.SObjectType, true, true);
      requireObject(Author__c.SObjectType, true, true);
      requireObject(Book_Category__c.SObjectType, true, true);
      requireObject(Book_Author__c.SObjectType, true, true);
      requireObject(Book_Category_Link__c.SObjectType, true, true);
    } else if (permission == 'Manage_Library_Circulation') {
      requireObject(Member__c.SObjectType, false, false);
      requireObject(Book_Copy__c.SObjectType, true, true);
      requireObject(Borrow_Record__c.SObjectType, true, true);
      requireObject(Reservation__c.SObjectType, true, true);
      requireObject(Fine__c.SObjectType, true, true);
    } else if (permission == 'Manage_Library_Fines') {
      requireObject(Fine__c.SObjectType, true, true);
      requireObject(Borrow_Record__c.SObjectType, false, true);
    } else if (permission == 'Manage_Library_Registrations') {
      requireObject(Library_Registration__c.SObjectType, true, true);
      requireObject(Member__c.SObjectType, true, true);
      requireObject(Contact.SObjectType, true, true);
    }
  }

  public static void requireRegistrationAccess() {
    requireObject(Library_Registration__c.SObjectType, true, true);
    requireObject(Member__c.SObjectType, true, true);
    requireObject(Contact.SObjectType, true, true);
  }

  public static void requireFields(
    Schema.SObjectType objectType,
    List<String> fieldNames,
    Boolean forUpdate
  ) {
    Map<String, Schema.SObjectField> fields = objectType.getDescribe().fields.getMap();
    for (String fieldName : fieldNames) {
      if (!fields.containsKey(fieldName)) {
        throw new AuraHandledException('The requested library field is unavailable.');
      }
      Schema.DescribeFieldResult field = fields.get(fieldName).getDescribe();
      Boolean allowed = forUpdate ? field.isUpdateable() : field.isAccessible();
      if (!allowed) {
        throw new AuraHandledException('You are not authorized to access the requested library field.');
      }
    }
  }

  public static void requireObject(
    Schema.SObjectType objectType,
    Boolean forCreate,
    Boolean forUpdate
  ) {
    Schema.DescribeSObjectResult describe = objectType.getDescribe();
    if (!describe.isAccessible() ||
        (forCreate && !describe.isCreateable()) ||
        (forUpdate && !describe.isUpdateable())) {
      throw new AuraHandledException('You are not authorized to access this library data.');
    }
  }

  public static List<SObject> readable(List<SObject> records) {
    if (records == null || records.isEmpty()) return records;
    return Security.stripInaccessible(AccessType.READABLE, records).getRecords();
  }

  public static List<SObject> creatable(List<SObject> records) {
    if (records == null || records.isEmpty()) return records;
    return Security.stripInaccessible(AccessType.CREATABLE, records).getRecords();
  }

  public static List<SObject> updatable(List<SObject> records) {
    if (records == null || records.isEmpty()) return records;
    return Security.stripInaccessible(AccessType.UPDATABLE, records).getRecords();
  }
}
