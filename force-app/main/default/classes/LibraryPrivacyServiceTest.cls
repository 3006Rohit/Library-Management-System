@IsTest
private class LibraryPrivacyServiceTest {
  private class Fixture {
    Member__c member;
    String token;
    String password = 'StrongPass123';
  }

  private static Fixture fixture(String suffix) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Privacy Plan ' + suffix,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1
    );
    insert plan;
    String email = 'privacy-' + suffix + '@example.com';
    String salt = LibraryMemberPasswordService.newSalt();
    Member__c member = new Member__c(
      First_Name__c = 'Privacy',
      Last_Name__c = 'Member',
      Email__c = email,
      Normalized_Email__c = email,
      External_Auth_Id__c = 'privacy-' + suffix,
      Password_Salt__c = salt,
      Password_Hash__c = LibraryMemberPasswordService.hash(
        salt,
        'StrongPass123'
      ),
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 5
    );
    insert member;
    Fixture result = new Fixture();
    result.member = member;
    result.token = LibraryMemberSessionService.create(
      member,
      null,
      'privacy-test'
    );
    return result;
  }

  @IsTest
  static void exportIsAllowlistedAndIdempotent() {
    Fixture f = fixture('export');
    LibraryPrivacyService.RequestDTO first = LibraryPrivacyService.requestExport(
      f.token,
      f.password
    );
    LibraryPrivacyService.RequestDTO second = LibraryPrivacyService.requestExport(
      f.token,
      f.password
    );
    System.assertEquals(first.id, second.id);
    System.assertEquals('Export', first.requestType);
    System.assertEquals('Completed', first.status);
    System.assertNotEquals(null, first.downloadUrl);
    Library_Scan_Transaction__c row = [
      SELECT Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :first.id
    ];
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      row.Result_Message__c
    );
    ContentVersion file = [
      SELECT Id, VersionData
      FROM ContentVersion
      WHERE Id = :((String) payload.get('cv'))
    ];
    String body = file.VersionData.toString();
    System.assert(body.contains('Privacy'));
    System.assert(!body.contains('Password_Hash__c'));
    System.assert(!body.contains('StrongPass123'));
  }

  @IsTest
  static void correctionRequiresReauthAndReviewerApproval() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Registrations'
    );
    Fixture f = fixture('correction');
    try {
      LibraryPrivacyService.requestCorrection(
        f.token,
        'WrongPassword123',
        'Updated',
        'Name',
        '9999999999',
        'New address',
        'My address and phone have changed.'
      );
      System.assert(false, 'Expected re-authentication failure');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    LibraryPrivacyService.RequestDTO request = LibraryPrivacyService.requestCorrection(
      f.token,
      f.password,
      'Updated',
      'Name',
      '9999999999',
      'New address',
      'My address and phone have changed.'
    );
    LibraryPrivacyService.decide(
      request.id,
      'Approved',
      'Verified member correction request.'
    );
    Member__c updated = [
      SELECT First_Name__c, Last_Name__c, Phone__c, Address__c
      FROM Member__c
      WHERE Id = :f.member.Id
    ];
    System.assertEquals('Updated', updated.First_Name__c);
    System.assertEquals('New address', updated.Address__c);
  }

  @IsTest
  static void approvedDeletionAnonymizesAndRevokesSessions() {
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Registrations'
    );
    Fixture f = fixture('deletion');
    LibraryPrivacyService.RequestDTO request = LibraryPrivacyService.requestDeletion(
      f.token,
      f.password,
      'I no longer need this library account and request closure.'
    );
    LibraryPrivacyService.decide(
      request.id,
      'Approved',
      'Retention review completed; profile anonymized.'
    );
    Member__c updated = [
      SELECT First_Name__c, Last_Name__c, Email__c, Status__c, Account_Status__c
      FROM Member__c
      WHERE Id = :f.member.Id
    ];
    System.assertEquals('Deleted', updated.First_Name__c);
    System.assertEquals('Inactive', updated.Account_Status__c);
    System.assert(updated.Email__c.endsWith('@privacy.invalid'));
    try {
      LibraryMemberSessionService.getCurrentMember(f.token);
      System.assert(false, 'Expected session revocation');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
  }
}
