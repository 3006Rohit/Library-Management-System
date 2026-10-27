@IsTest
private class LibraryBranchServiceTest {
  @IsTest
  static void branchAssignmentAndTransferLifecycle() {
    LibraryPolicyService.testGrantedPermissions.add('Manage_Library_Catalog');
    Membership_Plan__c plan = new Membership_Plan__c(
      Name = 'Branch Plan',
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 3,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 3,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 10,
      Fee__c = 10
    );
    insert plan;
    Member__c member = new Member__c(
      First_Name__c = 'Branch',
      Last_Name__c = 'Member',
      Email__c = 'branch-member@example.com',
      Normalized_Email__c = 'branch-member@example.com',
      External_Auth_Id__c = 'branch-member',
      Status__c = 'Active',
      Account_Status__c = 'Active',
      Membership_Plan__c = plan.Id,
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 3
    );
    insert member;
    String token = LibraryMemberSessionService.create(
      member,
      null,
      'branch-test'
    );
    Id source = LibraryBranchService.createBranch(
      'MAIN',
      'Main Library',
      '1 Main St',
      'UTC'
    );
    Id destination = LibraryBranchService.createBranch(
      'WEST',
      'West Library',
      '2 West St',
      'UTC'
    );
    Book__c book = new Book__c(
      Name = 'Branch Book',
      ISBN__c = 'BR-' + String.valueOf(DateTime.now().getTime()),
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = 1
    );
    insert book;
    Book_Copy__c copy = new Book_Copy__c(
      Book__c = book.Id,
      Barcode__c = 'BR-' + String.valueOf(DateTime.now().getTime()),
      Status__c = 'Available'
    );
    insert copy;
    LibraryBranchService.assignCopy(copy.Id, source);
    LibraryBranchService.TransferDTO transfer = LibraryBranchService.requestTransfer(
      copy.Id,
      destination
    );
    LibraryBranchService.shipTransfer(transfer.id);
    LibraryBranchService.receiveTransfer(transfer.id);
    System.assertEquals(
      'Received',
      LibraryBranchService.getTransfers()[0].status
    );
    System.assertEquals(2, LibraryBranchService.getBranches(token).size());
  }
}
