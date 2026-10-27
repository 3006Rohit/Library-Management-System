@IsTest
private class LibraryAccessibilityServiceTest {
  private static Member__c createMember() {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Accessibility Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5,
      Fee__c = 10
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Access',
      Last_Name__c = 'Member',
      Email__c = 'accessibility@example.com',
      Normalized_Email__c = 'accessibility@example.com',
      External_Auth_Id__c = 'accessibility-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    return member;
  }

  @IsTest
  static void memberCanSaveAccessibilityPreferences() {
    Member__c member = createMember();
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'accessibility-test'
    );

    LibraryAccessibilityService.PreferenceDTO defaults = LibraryAccessibilityService.get(
      token
    );
    System.assertEquals('English', defaults.preferredLanguage);
    System.assertEquals(false, defaults.highContrast);

    Test.startTest();
    LibraryAccessibilityService.PreferenceDTO saved = LibraryAccessibilityService.save(
      token,
      'Hindi',
      'Asia/Kolkata',
      true,
      true,
      true,
      true
    );
    Test.stopTest();

    System.assertEquals('Hindi', saved.preferredLanguage);
    System.assertEquals('Asia/Kolkata', saved.timezone);
    System.assertEquals(true, saved.highContrast);
    System.assertEquals(true, saved.largeText);
    System.assertEquals(true, saved.reducedMotion);
    System.assertEquals(true, saved.screenReader);
    Member__c refreshed = [
      SELECT
        Preferred_Language__c,
        Timezone__c,
        High_Contrast__c,
        Large_Text__c,
        Reduced_Motion__c,
        Screen_Reader__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assertEquals('Hindi', refreshed.Preferred_Language__c);
    System.assertEquals('Asia/Kolkata', refreshed.Timezone__c);
    System.assertEquals(true, refreshed.High_Contrast__c);
  }

  @IsTest
  static void invalidLanguageAndTimezoneAreRejected() {
    Member__c member = createMember();
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'accessibility-invalid-test'
    );
    Boolean rejectedLanguage = false;
    try {
      LibraryAccessibilityService.save(
        token,
        'Klingon',
        'UTC',
        false,
        false,
        false,
        false
      );
    } catch (AuraHandledException error) {
      rejectedLanguage = true;
    }
    System.assertEquals(true, rejectedLanguage);

    Boolean rejectedTimezone = false;
    try {
      LibraryAccessibilityService.save(
        token,
        'English',
        'bad\nzone',
        false,
        false,
        false,
        false
      );
    } catch (AuraHandledException error) {
      rejectedTimezone = true;
    }
    System.assertEquals(true, rejectedTimezone);
  }
}
