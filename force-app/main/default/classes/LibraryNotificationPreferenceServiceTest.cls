@IsTest
private class LibraryNotificationPreferenceServiceTest {
  private static Id memberId() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Preference Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert plan;
    Account account = new Account(Name = 'Preference Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Preference',
      LastName = 'Member',
      Email = 'preference@example.com',
      AccountId = account.Id
    );
    insert contact;
    Member__c member = new Member__c(
      First_Name__c = 'Preference',
      Last_Name__c = 'Member',
      Email__c = contact.Email,
      Normalized_Email__c = contact.Email,
      Contact__c = contact.Id,
      Membership_Plan__c = plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3,
      Status__c = 'Active',
      Account_Status__c = 'Active'
    );
    insert member;
    return member.Id;
  }

  @IsTest
  static void defaultsAreCreatedForNewMember() {
    Id memberId = memberId();

    Test.startTest();
    List<LibraryNotificationPreferenceService.PreferenceDTO> preferences = LibraryNotificationPreferenceService.getForMember(
      memberId
    );
    Test.stopTest();

    System.assertEquals(18, preferences.size());
    System.assertEquals('Email', preferences[0].channel);
  }

  @IsTest
  static void memberCanDisableEmailWithoutDisablingInApp() {
    Id memberId = memberId();
    LibraryNotificationPreferenceService.getForMember(memberId);
    LibraryNotificationPreferenceService.PreferenceInput input = new LibraryNotificationPreferenceService.PreferenceInput();
    input.channel = 'Email';
    input.notificationType = 'Book Available';
    input.enabled = false;
    input.digestFrequency = 'Daily';

    Test.startTest();
    LibraryNotificationPreferenceService.saveForMember(
      memberId,
      new List<LibraryNotificationPreferenceService.PreferenceInput>{ input }
    );
    Test.stopTest();

    System.assertEquals(
      false,
      LibraryNotificationPreferenceService.shouldDeliver(
        memberId,
        'Email',
        'Book Available'
      )
    );
    System.assertEquals(
      true,
      LibraryNotificationPreferenceService.shouldDeliver(
        memberId,
        'In-App',
        'Book Available'
      )
    );
  }

  @IsTest
  static void invalidQuietHoursAreRejected() {
    Id memberId = memberId();
    LibraryNotificationPreferenceService.PreferenceInput input = new LibraryNotificationPreferenceService.PreferenceInput();
    input.channel = 'Email';
    input.notificationType = 'Loan Due';
    input.quietHoursStart = '25:00';

    Boolean rejected = false;
    try {
      LibraryNotificationPreferenceService.saveForMember(
        memberId,
        new List<LibraryNotificationPreferenceService.PreferenceInput>{ input }
      );
      System.assert(false, 'Expected invalid quiet hours to be rejected');
    } catch (AuraHandledException error) {
      rejected = true;
    }
    System.assertEquals(true, rejected);
  }
}
