@IsTest
private class LibraryMemberProvisioningQueueableTest {
  private static Library_Registration__c registration(String email) {
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Auth UAT Plan ' + email,
      Active__c = true,
      Duration_Days__c = 30,
      Borrow_Limit__c = 5
    );
    insert plan;
    Library_Registration__c row = new Library_Registration__c(
      First_Name__c = 'Auth',
      Last_Name__c = 'UAT',
      Email__c = email,
      Registration_Email_Key__c = email,
      Requested_Plan__c = plan.Id,
      Registration_Date__c = System.now(),
      Approved_Date__c = System.now(),
      Approved_By__c = UserInfo.getUserId(),
      Status__c = 'Pending',
      Provisioning_State__c = 'Queued'
    );
    insert row;
    return row;
  }

  @IsTest
  static void approvalCreatesMemberAndActivationWithoutUser() {
    Library_Registration__c row = registration('auth-approval@example.com');
    Integer beforeUsers = [SELECT COUNT() FROM User];

    Test.startTest();
    System.enqueueJob(new LibraryRegistrationProvisioningQueueable(row.Id));
    Test.stopTest();

    Integer afterUsers = [SELECT COUNT() FROM User];
    System.assertEquals(
      beforeUsers,
      afterUsers,
      'Member approval must not create a Salesforce User.'
    );
    row = [
      SELECT
        Status__c,
        Provisioning_State__c,
        Provisioning_Message__c,
        Created_Member__c
      FROM Library_Registration__c
      WHERE Id = :row.Id
    ];
    System.assertEquals(
      'Approved',
      row.Status__c,
      'Provisioning failed: ' +
        row.Provisioning_Message__c +
        ' / ' +
        LibraryRegistrationProvisioningQueueable.testLastError
    );
    System.assertEquals('Completed', row.Provisioning_State__c);
    Member__c member = [
      SELECT Status__c, Account_Status__c, User__c
      FROM Member__c
      WHERE Id = :row.Created_Member__c
    ];
    System.assertEquals('Suspended', member.Status__c);
    System.assertEquals('Active', member.Account_Status__c);
    System.assert(
      Schema.SObjectType.Member__c.fields.getMap()
        .containsKey('Registration_Status__c')
    );
    System.assert(
      Schema.SObjectType.Member__c.fields.getMap()
        .containsKey('Activation_Token_Hash__c')
    );
    System.assert(
      Schema.SObjectType.Member__c.fields.getMap()
        .containsKey('Activation_Token_Expires_At__c')
    );
    System.assertEquals(null, member.User__c);
  }

  @IsTest
  static void completedApprovalIsIdempotent() {
    Library_Registration__c row = registration('auth-idempotent@example.com');
    new LibraryRegistrationProvisioningQueueable(row.Id).execute(null);
    row = [
      SELECT Status__c, Provisioning_State__c, Created_Member__c
      FROM Library_Registration__c
      WHERE Id = :row.Id
    ];
    Id memberId = row.Created_Member__c;
    Integer memberCount = [SELECT COUNT() FROM Member__c WHERE Id = :memberId];

    Test.startTest();
    System.enqueueJob(new LibraryRegistrationProvisioningQueueable(row.Id));
    Test.stopTest();

    System.assertEquals(
      memberCount,
      [SELECT COUNT() FROM Member__c WHERE Id = :memberId]
    );
    System.assertEquals(
      memberId,
      [SELECT Created_Member__c FROM Library_Registration__c WHERE Id = :row.Id]
      .Created_Member__c
    );
  }
}
