@IsTest
private class LibrarySettingsControllerTest {
  @IsTest
  static void settingsCanBeSavedAndRead() {
    LibraryPolicyService.testGrantedPermissions = new Set<String>{
      'Manage_Library_Circulation'
    };

    Test.startTest();
    Library_Settings__c defaults = LibrarySettingsController.getSettings();
    Id settingsId = LibrarySettingsController.saveSettings(
      null,
      'Central Library',
      'library@example.com',
      'STACK',
      5,
      2,
      150,
      true,
      true,
      true,
      true,
      true,
      true,
      true
    );
    Library_Settings__c settings = LibrarySettingsController.getSettings();
    Test.stopTest();

    System.assertEquals(null, defaults.Id);
    System.assertEquals('Library Management', defaults.Library_Name__c);
    System.assertEquals(settingsId, settings.Id);
    System.assertEquals('Central Library', settings.Library_Name__c);
    System.assertEquals(5, settings.Reservation_Hold_Days__c);
    System.assertEquals(true, settings.Send_Due_Reminders__c);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Library_Settings__c
        WHERE Settings_Key__c = 'Default'
      ]
    );
  }

  @IsTest
  static void invalidSettingsAreRejected() {
    LibraryPolicyService.testGrantedPermissions = new Set<String>{
      'Manage_Library_Circulation'
    };
    Boolean rejected = false;
    try {
      LibrarySettingsController.saveSettings(
        null,
        '',
        null,
        null,
        0,
        -1,
        1,
        false,
        false,
        false,
        false,
        false,
        false,
        false
      );
    } catch (AuraHandledException expected) {
      rejected = true;
    }
    System.assertEquals(true, rejected);
  }

  @IsTest
  static void runtimeSchemaContractIsComplete() {
    List<LibrarySchemaValidation.Finding> findings = LibrarySchemaValidation.validate();
    System.assert(
      findings.size() > 0,
      'The validator must inspect the required schema contract.'
    );
    for (LibrarySchemaValidation.Finding finding : findings) {
      System.assertEquals(
        'PASS',
        finding.status,
        finding.target + ': ' + finding.detail
      );
    }
  }
}
