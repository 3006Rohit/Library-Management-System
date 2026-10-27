public without sharing class LibraryMemberBorrowService {
  public static Id request(Member__c resolvedMember, Id bookId) {
    if (resolvedMember == null || resolvedMember.Id == null)
      throw new AuraHandledException('An authenticated member is required.');
    if (bookId == null)
      throw new AuraHandledException('A book must be selected.');
    Member__c member = [
      SELECT Id, Contact__c, Status__c, Email__c
      FROM Member__c
      WHERE Id = :resolvedMember.Id
      FOR UPDATE
    ];
    if (member.Status__c != 'Active')
      throw new AuraHandledException(
        'Your membership must be active to request a book.'
      );
    if (
      [
        SELECT COUNT()
        FROM Borrow_Record__c
        WHERE Member__c = :member.Id AND Status__c = 'Pending'
      ] > 0
    )
      throw new AuraHandledException(
        'You already have a borrowing request awaiting librarian approval.'
      );
    List<Book_Copy__c> copies = [
      SELECT Id
      FROM Book_Copy__c
      WHERE Book__c = :bookId AND Status__c = 'Available'
      LIMIT 1
      FOR UPDATE
    ];
    if (copies.isEmpty())
      throw new AuraHandledException(
        'No copy is currently available. Reserve this title to join the queue.'
      );
    Borrow_Record__c request = new Borrow_Record__c(
      Member__c = member.Id,
      Contact__c = member.Contact__c,
      Book_Copy__c = copies[0].Id,
      Borrow_Date__c = System.now(),
      Status__c = 'Pending',
      Renewal_Count__c = 0,
      Notes__c = 'Requested by member; awaiting librarian approval.'
    );
    insert request;
    update new Book_Copy__c(Id = copies[0].Id, Status__c = 'Reserved');
    LibraryMemberNotificationService.create(
      member.Id,
      'Borrow Request',
      'Borrow request submitted',
      'Your borrowing request is awaiting librarian approval.',
      request.Id,
      'BORROW-REQUEST-' + request.Id,
      member.Email__c
    );
    return request.Id;
  }

  public static Id checkout(Member__c resolvedMember, Id copyId) {
    if (resolvedMember == null || resolvedMember.Id == null)
      throw new AuraHandledException('An authenticated member is required.');
    Member__c member = [
      SELECT
        Id,
        Contact__c,
        Status__c,
        Membership_End_Date__c,
        Membership_Plan__c,
        Membership_Plan__r.Active__c,
        Membership_Plan__r.Borrow_Limit__c,
        Membership_Plan__r.Loan_Duration_Days__c
      FROM Member__c
      WHERE Id = :resolvedMember.Id
      FOR UPDATE
    ];
    Book_Copy__c copy = [
      SELECT Id, Book__c, Status__c
      FROM Book_Copy__c
      WHERE Id = :copyId
      FOR UPDATE
    ];
    List<Borrow_Record__c> activeLoans = [
      SELECT Id
      FROM Borrow_Record__c
      WHERE
        Member__c = :member.Id
        AND Return_Date__c = NULL
        AND Status__c IN ('Active', 'Overdue')
      FOR UPDATE
    ];
    Decimal outstanding = 0;
    for (Fine__c fine : [
      SELECT Balance__c
      FROM Fine__c
      WHERE Member__c = :member.Id AND Status__c IN ('Unpaid', 'Partially Paid')
    ])
      outstanding += fine.Balance__c == null ? 0 : fine.Balance__c;
    Reservation__c blocking;
    List<Reservation__c> reservations = [
      SELECT Id, Member__c, Status__c, Book_Copy__c
      FROM Reservation__c
      WHERE
        Book__c = :copy.Book__c
        AND Status__c = 'Ready'
        AND Book_Copy__c = :copy.Id
      ORDER BY Status__c DESC, Reservation_Date__c, Id
      LIMIT 1
    ];
    if (!reservations.isEmpty())
      blocking = reservations[0];
    LibraryPolicyService.PolicyResult result = LibraryPolicyService.canBorrow(
      member,
      member.Membership_Plan__r,
      activeLoans.size(),
      outstanding,
      copy,
      blocking
    );
    if (!result.allowed)
      throw new AuraHandledException(result.message);
    if (
      blocking != null &&
      blocking.Status__c == 'Ready' &&
      blocking.Member__c == member.Id &&
      blocking.Book_Copy__c != null &&
      blocking.Book_Copy__c != copy.Id
    )
      throw new AuraHandledException(
        'This reservation is ready on a different copy.'
      );
    Datetime now = System.now();
    Borrow_Record__c loan = new Borrow_Record__c(
      Member__c = member.Id,
      Contact__c = member.Contact__c,
      Book_Copy__c = copy.Id,
      Borrow_Date__c = now,
      Due_Date__c = now.addDays(
        Integer.valueOf(member.Membership_Plan__r.Loan_Duration_Days__c)
      ),
      Status__c = 'Active',
      Renewal_Count__c = 0
    );
    insert loan;
    update new Book_Copy__c(Id = copy.Id, Status__c = 'Borrowed');
    if (
      blocking != null &&
      blocking.Status__c == 'Ready' &&
      blocking.Member__c == member.Id
    ) {
      blocking.Status__c = 'Fulfilled';
      blocking.Fulfilled_Date__c = now;
      update blocking;
    }
    return loan.Id;
  }
}
