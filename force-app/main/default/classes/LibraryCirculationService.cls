public without sharing class LibraryCirculationService {
  public static Id checkout(Id memberId, Id copyId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
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
      WHERE Id = :memberId
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
        Member__c = :memberId
        AND Return_Date__c = NULL
        AND Status__c IN ('Active', 'Overdue')
      FOR UPDATE
    ];
    Decimal outstanding = 0;
    for (Fine__c fine : [
      SELECT Balance__c
      FROM Fine__c
      WHERE Member__c = :memberId AND Status__c IN ('Unpaid', 'Partially Paid')
    ])
      outstanding += fine.Balance__c == null ? 0 : fine.Balance__c;
    Reservation__c blocking;
    List<Reservation__c> reservations = [
      SELECT Id, Member__c, Status__c, Book_Copy__c
      FROM Reservation__c
      WHERE Book__c = :copy.Book__c AND Status__c IN ('Pending', 'Ready')
      ORDER BY Reservation_Date__c ASC, Id ASC
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
      blocking.Member__c == memberId &&
      blocking.Book_Copy__c != null &&
      blocking.Book_Copy__c != copyId
    )
      throw new AuraHandledException(
        'This reservation is ready on a different copy.'
      );
    Datetime now = System.now();
    Borrow_Record__c loan = new Borrow_Record__c(
      Member__c = member.Id,
      Book_Copy__c = copy.Id,
      Contact__c = member.Contact__c,
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
      blocking.Member__c == memberId
    ) {
      blocking.Status__c = 'Fulfilled';
      blocking.Queue_Position__c = null;
      blocking.Fulfilled_Date__c = now;
      update blocking;
      // The fulfilled reservation leaves the active queue. Re-number the
      // remaining reservations so the next member becomes position 1.
      resequenceQueue(copy.Book__c);
    }
    return loan.Id;
  }

  public static void returnLoan(Id loanId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Borrow_Record__c loan = [
      SELECT
        Id,
        Member__c,
        Book_Copy__c,
        Contact__c,
        Borrow_Date__c,
        Due_Date__c,
        Return_Date__c,
        Status__c,
        Member__r.Membership_Plan__r.Fine_Per_Day__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
      FOR UPDATE
    ];
    if (loan.Return_Date__c != null || loan.Status__c == 'Returned')
      throw new AuraHandledException('Loan has already been returned.');
    Book_Copy__c copy = [
      SELECT Id, Book__c, Status__c
      FROM Book_Copy__c
      WHERE Id = :loan.Book_Copy__c
      FOR UPDATE
    ];
    Datetime now = System.now();
    loan.Return_Date__c = now;
    loan.Status__c = 'Returned';
    update new Borrow_Record__c(
      Id = loan.Id,
      Return_Date__c = now,
      Status__c = 'Returned'
    );
    if (
      loan.Due_Date__c != null &&
      now > loan.Due_Date__c &&
      loan.Member__r.Membership_Plan__r.Fine_Per_Day__c != null
    ) {
      Integer days = loan.Due_Date__c.date().daysBetween(now.date());
      if (
        [
          SELECT COUNT()
          FROM Fine__c
          WHERE Borrow_Record__c = :loan.Id AND Fine_Type__c = 'Overdue'
        ] == 0
      )
        insert new Fine__c(
          Member__c = loan.Member__c,
          Borrow_Record__c = loan.Id,
          Contact__c = loan.Contact__c,
          Fine_Type__c = 'Overdue',
          Amount__c = days * loan.Member__r.Membership_Plan__r.Fine_Per_Day__c,
          Paid_Amount__c = 0,
          Status__c = 'Unpaid',
          Generated_Date__c = Date.today()
        );
    }
    List<Reservation__c> pending = [
      SELECT
        Id,
        Member__c,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Member__r.Email__c,
        Queue_Position__c
      FROM Reservation__c
      WHERE Book__c = :copy.Book__c AND Status__c = 'Pending'
      ORDER BY Reservation_Date__c ASC, Id ASC
      LIMIT 1
    ];
    if (pending.isEmpty()) {
      update new Book_Copy__c(Id = copy.Id, Status__c = 'Available');
      notifyReplacementMembers(copy.Book__c);
    } else {
      Reservation__c next = pending[0];
      next.Status__c = 'Ready';
      next.Book_Copy__c = copy.Id;
      next.Queue_Position__c = null;
      next.Ready_Date__c = now;
      next.Expiry_Date__c = now.addDays(
        LibraryPolicyService.holdDurationDays()
      );
      update next;
      LibraryReservationAuditService.record(
        next.Id,
        'Promoted',
        'Pending',
        'Ready',
        next.Queue_Position__c,
        'A returned copy became available.'
      );
      notifyReady(next);
      update new Book_Copy__c(Id = copy.Id, Status__c = 'Reserved');
      resequenceQueue(copy.Book__c);
    }
  }

  public static void renewLoan(Id loanId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Borrow_Record__c loan = [
      SELECT
        Id,
        Member__c,
        Due_Date__c,
        Status__c,
        Renewal_Count__c,
        Member__r.Status__c,
        Member__r.Membership_End_Date__c,
        Member__r.Membership_Plan__r.Renewal_Limit__c,
        Member__r.Membership_Plan__r.Loan_Duration_Days__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
      FOR UPDATE
    ];
    if (loan.Status__c != 'Active' && loan.Status__c != 'Overdue')
      throw new AuraHandledException('Only an active loan can be renewed.');
    if (
      loan.Member__r.Status__c != 'Active' ||
      loan.Member__r.Membership_End_Date__c < Date.today()
    )
      throw new AuraHandledException('Member is not eligible for renewal.');
    if (
      loan.Member__r.Membership_Plan__r.Renewal_Limit__c == null ||
      loan.Renewal_Count__c >=
      loan.Member__r.Membership_Plan__r.Renewal_Limit__c
    )
      throw new AuraHandledException('Renewal limit has been reached.');
    Integer blockingReservations = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE
        Book_Copy__c IN (
          SELECT Book_Copy__c
          FROM Borrow_Record__c
          WHERE Id = :loan.Id
        )
        AND Status__c = 'Pending'
        AND Member__c != :loan.Member__c
    ];
    if (blockingReservations > 0)
      throw new AuraHandledException(
        'A reservation from another member blocks renewal.'
      );
    loan.Due_Date__c = loan.Due_Date__c.addDays(
      Integer.valueOf(loan.Member__r.Membership_Plan__r.Loan_Duration_Days__c)
    );
    loan.Renewal_Count__c = (loan.Renewal_Count__c == null
      ? 1
      : loan.Renewal_Count__c + 1);
    loan.Last_Renewed_Date__c = System.now();
    loan.Status__c = 'Active';
    update new Borrow_Record__c(
      Id = loan.Id,
      Due_Date__c = loan.Due_Date__c,
      Renewal_Count__c = loan.Renewal_Count__c,
      Last_Renewed_Date__c = loan.Last_Renewed_Date__c,
      Status__c = 'Active'
    );
  }

  public static void recordFinePayment(Id fineId, Decimal amount) {
    LibraryPolicyService.require('Manage_Library_Fines');
    if (amount == null || amount <= 0)
      throw new AuraHandledException('Payment must be greater than zero.');
    Fine__c fine = [
      SELECT Id, Amount__c, Paid_Amount__c, Status__c
      FROM Fine__c
      WHERE Id = :fineId
      FOR UPDATE
    ];
    Decimal paid = fine.Paid_Amount__c == null ? 0 : fine.Paid_Amount__c;
    Decimal balance = (fine.Amount__c == null ? 0 : fine.Amount__c) - paid;
    if (amount > balance)
      throw new AuraHandledException(
        'Payment cannot exceed the outstanding balance.'
      );
    fine.Paid_Amount__c = paid + amount;
    fine.Status__c = fine.Paid_Amount__c >= fine.Amount__c
      ? 'Paid'
      : 'Partially Paid';
    if (fine.Status__c == 'Paid')
      fine.Paid_Date__c = Date.today();
    update fine;
  }

  public static void waiveFine(Id fineId, String reason) {
    LibraryPolicyService.require('Manage_Library_Fines');
    Fine__c fine = [
      SELECT Id, Status__c, Notes__c
      FROM Fine__c
      WHERE Id = :fineId
      FOR UPDATE
    ];
    if (fine.Status__c == 'Paid' || fine.Status__c == 'Waived')
      throw new AuraHandledException('This fine cannot be waived.');
    fine.Status__c = 'Waived';
    fine.Notes__c = String.isBlank(reason)
      ? 'Waived by librarian.'
      : reason.trim();
    update fine;
  }

  public static Id createReservation(Id memberId, Id bookId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Member__c member = [
      SELECT
        Id,
        Contact__c,
        Status__c,
        Membership_End_Date__c,
        Membership_Plan__r.Active__c,
        Membership_Plan__r.Reservation_Limit__c
      FROM Member__c
      WHERE Id = :memberId
    ];
    if (
      member.Status__c != 'Active' ||
      member.Membership_End_Date__c < Date.today()
    )
      throw new AuraHandledException(
        'Member is not eligible for reservations.'
      );
    Integer activeCount = systemReservationCount(
      'SELECT COUNT(Id) total FROM Reservation__c ' +
      'WHERE Member__c = :memberId AND Status__c IN (\'Pending\', \'Ready\')',
      new Map<String, Object>{ 'memberId' => memberId }
    );
    if (
      member.Membership_Plan__r.Reservation_Limit__c != null &&
      activeCount >= member.Membership_Plan__r.Reservation_Limit__c
    )
      throw new AuraHandledException('Reservation limit has been reached.');
    List<Book__c> lockedBooks = [
      SELECT Id
      FROM Book__c
      WHERE Id = :bookId
      LIMIT 1
      FOR UPDATE
    ];
    if (lockedBooks.isEmpty())
      throw new AuraHandledException('Book was not found.');
    if (
      systemReservationCount(
        'SELECT COUNT(Id) total FROM Reservation__c ' +
          'WHERE Member__c = :memberId AND Book__c = :bookId ' +
          'AND Status__c IN (\'Pending\', \'Ready\')',
        new Map<String, Object>{ 'memberId' => memberId, 'bookId' => bookId }
      ) > 0
    )
      throw new AuraHandledException(
        'Member already has an active reservation for this book.'
      );
    Integer position =
      systemReservationCount(
        'SELECT COUNT(Id) total FROM Reservation__c ' +
        'WHERE Book__c = :bookId AND Status__c = \'Pending\'',
        new Map<String, Object>{ 'bookId' => bookId }
      ) + 1;
    Reservation__c reservation = new Reservation__c(
      Member__c = memberId,
      Book__c = bookId,
      Contact__c = member.Contact__c,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = position
    );
    insert reservation;
    LibraryReservationAuditService.record(
      reservation.Id,
      'Created',
      null,
      'Pending',
      position,
      'Reservation entered the queue.'
    );
    resequenceQueue(bookId);
    return reservation.Id;
  }

  public static void cancelReservation(Id reservationId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Reservation__c reservation = [
      SELECT Id, Status__c, Book__c, Book_Copy__c, Queue_Position__c
      FROM Reservation__c
      WHERE Id = :reservationId
      FOR UPDATE
    ];
    if (
      reservation.Status__c == 'Fulfilled' ||
      reservation.Status__c == 'Expired' ||
      reservation.Status__c == 'Cancelled'
    )
      throw new AuraHandledException('This reservation cannot be cancelled.');
    String previous = reservation.Status__c;
    Id releasedCopy = reservation.Book_Copy__c;
    reservation.Status__c = 'Cancelled';
    reservation.Book_Copy__c = null;
    reservation.Queue_Position__c = null;
    update reservation;
    LibraryReservationAuditService.record(
      reservation.Id,
      'Cancelled',
      previous,
      'Cancelled',
      reservation.Queue_Position__c,
      'Cancelled by librarian.'
    );
    if (releasedCopy != null)
      promoteNext(reservation.Book__c, releasedCopy);
    resequenceQueue(reservation.Book__c);
  }

  public static Integer processExpiredReservations() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    return processExpiredReservationsInternal(null);
  }

  public static Integer processExpiredReservationsBatch(
    Set<Id> reservationIds
  ) {
    return processExpiredReservationsInternal(reservationIds);
  }

  private static Integer processExpiredReservationsInternal(
    Set<Id> reservationIds
  ) {
    DateTime now = System.now();
    List<Reservation__c> expired = reservationIds == null
      ? [
          SELECT Id, Book__c, Book_Copy__c, Status__c
          FROM Reservation__c
          WHERE Status__c = 'Ready' AND Expiry_Date__c < :now
          LIMIT 100
          FOR UPDATE
        ]
      : [
          SELECT Id, Book__c, Book_Copy__c, Status__c
          FROM Reservation__c
          WHERE
            Id IN :reservationIds
            AND Status__c = 'Ready'
            AND Expiry_Date__c < :now
          FOR UPDATE
        ];
    if (expired.isEmpty())
      return 0;
    Set<Id> bookIds = new Set<Id>();
    for (Reservation__c row : expired)
      if (row.Book__c != null)
        bookIds.add(row.Book__c);
    Map<Id, List<Reservation__c>> pendingByBook = new Map<Id, List<Reservation__c>>();
    for (Reservation__c row : [
      SELECT
        Id,
        Book__c,
        Member__c,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Member__r.Email__c,
        Queue_Position__c
      FROM Reservation__c
      WHERE Book__c IN :bookIds AND Status__c = 'Pending'
      ORDER BY Reservation_Date__c ASC, Id ASC
    ]) {
      if (!pendingByBook.containsKey(row.Book__c))
        pendingByBook.put(row.Book__c, new List<Reservation__c>());
      pendingByBook.get(row.Book__c).add(row);
    }
    List<Reservation__c> expiredUpdates = new List<Reservation__c>();
    List<Reservation__c> promoted = new List<Reservation__c>();
    List<Book_Copy__c> copyUpdates = new List<Book_Copy__c>();
    List<Reservation_Audit__c> audits = new List<Reservation_Audit__c>();
    List<LibraryMemberNotificationService.NotificationInput> notifications = new List<LibraryMemberNotificationService.NotificationInput>();
    for (Reservation__c row : expired) {
      Id copyId = row.Book_Copy__c;
      row.Status__c = 'Expired';
      row.Queue_Position__c = null;
      row.Book_Copy__c = null;
      expiredUpdates.add(row);
      if (copyId == null)
        continue;
      List<Reservation__c> queue = pendingByBook.get(row.Book__c);
      if (queue == null || queue.isEmpty()) {
        copyUpdates.add(new Book_Copy__c(Id = copyId, Status__c = 'Available'));
        continue;
      }
      Reservation__c next = queue.remove(0);
      next.Status__c = 'Ready';
      next.Book_Copy__c = copyId;
      next.Queue_Position__c = null;
      next.Ready_Date__c = now;
      next.Expiry_Date__c = now.addDays(
        LibraryPolicyService.holdDurationDays()
      );
      promoted.add(next);
      copyUpdates.add(new Book_Copy__c(Id = copyId, Status__c = 'Reserved'));
      audits.add(
        new Reservation_Audit__c(
          Reservation__c = next.Id,
          Action__c = 'Promoted',
          From_Status__c = 'Pending',
          To_Status__c = 'Ready',
          Queue_Position__c = null,
          Actor__c = UserInfo.getUserId(),
          Occurred_At__c = now,
          Notes__c = 'An expired hold released a copy.'
        )
      );
      notifications.add(
        new LibraryMemberNotificationService.NotificationInput(
          next.Member__c,
          'Reservation Ready',
          'Your library reservation is ready',
          'A reserved book is ready for pickup. Please sign in to the Library portal for details.',
          next.Id,
          'READY-' + String.valueOf(next.Id) + '-' + String.valueOf(now.date()),
          next.Member__r.Email__c
        )
      );
    }
    Database.update(expiredUpdates, AccessLevel.SYSTEM_MODE);
    if (!promoted.isEmpty())
      Database.update(promoted, AccessLevel.SYSTEM_MODE);
    if (!copyUpdates.isEmpty())
      Database.update(copyUpdates, AccessLevel.SYSTEM_MODE);
    if (!audits.isEmpty())
      Database.insert(audits, AccessLevel.SYSTEM_MODE);
    LibraryMemberNotificationService.createAll(notifications);
    List<Reservation__c> remaining = [
      SELECT Id, Book__c, Status__c, Queue_Position__c
      FROM Reservation__c
      WHERE Book__c IN :bookIds AND Status__c IN ('Pending', 'Ready')
      ORDER BY Book__c, Reservation_Date__c ASC, Id ASC
    ];
    List<Reservation__c> resequenced = new List<Reservation__c>();
    Id currentBook;
    Integer position = 1;
    for (Reservation__c row : remaining) {
      if (row.Book__c != currentBook) {
        currentBook = row.Book__c;
        position = 1;
      }
      Decimal target = row.Status__c == 'Pending' ? position : null;
      if (row.Queue_Position__c != target)
        resequenced.add(
          new Reservation__c(Id = row.Id, Queue_Position__c = target)
        );
      if (row.Status__c == 'Pending')
        position++;
    }
    if (!resequenced.isEmpty())
      Database.update(resequenced, AccessLevel.SYSTEM_MODE);
    return expiredUpdates.size();
  }

  public static void renewLoanForMember(Id loanId, Id memberId) {
    Borrow_Record__c loan = [
      SELECT
        Id,
        Member__c,
        Due_Date__c,
        Status__c,
        Renewal_Count__c,
        Member__r.Status__c,
        Member__r.Membership_End_Date__c,
        Member__r.Membership_Plan__r.Renewal_Limit__c,
        Member__r.Membership_Plan__r.Loan_Duration_Days__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
      FOR UPDATE
    ];
    if (loan.Member__c != memberId)
      throw new AuraHandledException(
        'This loan does not belong to the current member.'
      );
    if (loan.Status__c != 'Active' && loan.Status__c != 'Overdue')
      throw new AuraHandledException('Only an active loan can be renewed.');
    if (
      loan.Member__r.Status__c != 'Active' ||
      loan.Member__r.Membership_End_Date__c < Date.today()
    )
      throw new AuraHandledException('Member is not eligible for renewal.');
    if (
      loan.Member__r.Membership_Plan__r.Renewal_Limit__c == null ||
      loan.Renewal_Count__c >=
      loan.Member__r.Membership_Plan__r.Renewal_Limit__c
    )
      throw new AuraHandledException('Renewal limit has been reached.');
    List<AggregateResult> blockingRows = (List<AggregateResult>) Database.queryWithBinds(
      'SELECT COUNT(Id) total FROM Reservation__c ' +
        'WHERE Book_Copy__c IN (SELECT Book_Copy__c FROM Borrow_Record__c WHERE Id = :loanId) ' +
        'AND Status__c = \'Pending\' AND Member__c != :memberId',
      new Map<String, Object>{
        'loanId' => loan.Id,
        'memberId' => loan.Member__c
      },
      AccessLevel.SYSTEM_MODE
    );
    Integer blockingReservations = blockingRows.isEmpty()
      ? 0
      : Integer.valueOf(blockingRows[0].get('total'));
    if (blockingReservations > 0)
      throw new AuraHandledException(
        'A reservation from another member blocks renewal.'
      );
    loan.Due_Date__c = loan.Due_Date__c.addDays(
      Integer.valueOf(loan.Member__r.Membership_Plan__r.Loan_Duration_Days__c)
    );
    loan.Renewal_Count__c = (loan.Renewal_Count__c == null
      ? 1
      : loan.Renewal_Count__c + 1);
    loan.Last_Renewed_Date__c = System.now();
    loan.Status__c = 'Active';
    Database.update(
      new Borrow_Record__c(
        Id = loan.Id,
        Due_Date__c = loan.Due_Date__c,
        Renewal_Count__c = loan.Renewal_Count__c,
        Last_Renewed_Date__c = loan.Last_Renewed_Date__c,
        Status__c = 'Active'
      ),
      AccessLevel.SYSTEM_MODE
    );
  }

  public static Id createReservationForMember(Id memberId, Id bookId) {
    List<Member__c> members = [
      SELECT
        Id,
        Contact__c,
        Status__c,
        Membership_End_Date__c,
        Membership_Plan__r.Active__c,
        Membership_Plan__r.Reservation_Limit__c
      FROM Member__c
      WHERE Id = :memberId
      LIMIT 1
    ];
    if (members.isEmpty())
      throw new AuraHandledException(
        'The member account could not be found. Please sign out and sign in again.'
      );
    return createReservationForMember(members[0], bookId);
  }

  public static Id createReservationForMember(Member__c member, Id bookId) {
    if (member == null || member.Id == null)
      throw new AuraHandledException(
        'The member account could not be found. Please sign out and sign in again.'
      );
    if (
      member.Status__c != 'Active' ||
      member.Membership_End_Date__c < Date.today()
    )
      throw new AuraHandledException(
        'Member is not eligible for reservations.'
      );
    if (member.Membership_Plan__c == null)
      throw new AuraHandledException('Member does not have a membership plan.');
    Id memberId = member.Id;
    Decimal reservationLimit = member.Membership_Plan__r == null
      ? null
      : member.Membership_Plan__r.Reservation_Limit__c;
    Integer activeCount = systemReservationCount(
      'SELECT COUNT(Id) total FROM Reservation__c ' +
      'WHERE Member__c = :memberId AND Status__c IN (\'Pending\', \'Ready\')',
      new Map<String, Object>{ 'memberId' => memberId }
    );
    if (reservationLimit != null && activeCount >= reservationLimit)
      throw new AuraHandledException('Reservation limit has been reached.');
    List<Book__c> lockedBooks = [
      SELECT Id
      FROM Book__c
      WHERE Id = :bookId
      LIMIT 1
      FOR UPDATE
    ];
    if (lockedBooks.isEmpty())
      throw new AuraHandledException('Book was not found.');
    if (
      systemReservationCount(
        'SELECT COUNT(Id) total FROM Reservation__c ' +
          'WHERE Member__c = :memberId AND Book__c = :bookId ' +
          'AND Status__c IN (\'Pending\', \'Ready\')',
        new Map<String, Object>{ 'memberId' => memberId, 'bookId' => bookId }
      ) > 0
    )
      throw new AuraHandledException(
        'Member already has an active reservation for this book.'
      );
    Integer position =
      systemReservationCount(
        'SELECT COUNT(Id) total FROM Reservation__c ' +
        'WHERE Book__c = :bookId AND Status__c = \'Pending\'',
        new Map<String, Object>{ 'bookId' => bookId }
      ) + 1;
    Reservation__c reservation = new Reservation__c(
      Member__c = memberId,
      Book__c = bookId,
      Contact__c = member.Contact__c,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = position
    );
    Database.insert(reservation, AccessLevel.SYSTEM_MODE);
    LibraryReservationAuditService.record(
      reservation.Id,
      'Created',
      null,
      'Pending',
      position,
      'Reservation entered the queue.'
    );
    resequenceQueue(bookId);
    return reservation.Id;
  }

  public static void cancelReservationForMember(Id reservationId, Id memberId) {
    List<Reservation__c> ownedReservations = (List<Reservation__c>) Database.queryWithBinds(
      'SELECT Id, Member__c, Status__c, Book__c, Book_Copy__c, Queue_Position__c ' +
      'FROM Reservation__c WHERE Id = :reservationId FOR UPDATE',
      new Map<String, Object>{ 'reservationId' => reservationId },
      AccessLevel.SYSTEM_MODE
    );
    if (ownedReservations.isEmpty())
      throw new AuraHandledException('Reservation was not found.');
    Reservation__c reservation = ownedReservations[0];
    if (reservation.Member__c != memberId)
      throw new AuraHandledException(
        'This reservation does not belong to the current member.'
      );
    if (
      reservation.Status__c == 'Fulfilled' ||
      reservation.Status__c == 'Expired' ||
      reservation.Status__c == 'Cancelled'
    )
      throw new AuraHandledException('This reservation cannot be cancelled.');
    if (reservation.Status__c == 'Ready' && reservation.Book_Copy__c != null) {
      Id releasedCopy = reservation.Book_Copy__c;
      String previous = reservation.Status__c;
      reservation.Status__c = 'Cancelled';
      reservation.Book_Copy__c = null;
      reservation.Queue_Position__c = null;
      Database.update(reservation, AccessLevel.SYSTEM_MODE);
      LibraryReservationAuditService.record(
        reservation.Id,
        'Cancelled',
        previous,
        'Cancelled',
        reservation.Queue_Position__c,
        'Cancelled by member.'
      );
      promoteNext(reservation.Book__c, releasedCopy);
      resequenceQueue(reservation.Book__c);
    } else {
      String previous = reservation.Status__c;
      reservation.Status__c = 'Cancelled';
      reservation.Queue_Position__c = null;
      Database.update(reservation, AccessLevel.SYSTEM_MODE);
      LibraryReservationAuditService.record(
        reservation.Id,
        'Cancelled',
        previous,
        'Cancelled',
        reservation.Queue_Position__c,
        'Cancelled by member.'
      );
      resequenceQueue(reservation.Book__c);
    }
  }
  private static void promoteNext(Id bookId, Id copyId) {
    List<Reservation__c> next = [
      SELECT
        Id,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Member__r.Email__c,
        Queue_Position__c
      FROM Reservation__c
      WHERE Book__c = :bookId AND Status__c = 'Pending'
      ORDER BY Reservation_Date__c ASC, Id ASC
      LIMIT 1
    ];
    if (next.isEmpty()) {
      Database.update(
        new Book_Copy__c(Id = copyId, Status__c = 'Available'),
        AccessLevel.SYSTEM_MODE
      );
      return;
    }
    Reservation__c promoted = next[0];
    promoted.Status__c = 'Ready';
    promoted.Book_Copy__c = copyId;
    promoted.Queue_Position__c = null;
    promoted.Ready_Date__c = System.now();
    promoted.Expiry_Date__c = System.now()
      .addDays(LibraryPolicyService.holdDurationDays());
    Database.update(promoted, AccessLevel.SYSTEM_MODE);
    Database.update(
      new Book_Copy__c(Id = copyId, Status__c = 'Reserved'),
      AccessLevel.SYSTEM_MODE
    );
    LibraryReservationAuditService.record(
      promoted.Id,
      'Promoted',
      'Pending',
      'Ready',
      promoted.Queue_Position__c,
      'A released copy became available.'
    );
    notifyReady(promoted);
  }
  private static void resequenceQueue(Id bookId) {
    if (bookId == null)
      return;
    List<Reservation__c> rows = (List<Reservation__c>) Database.queryWithBinds(
      'SELECT Id, Status__c, Queue_Position__c FROM Reservation__c ' +
        'WHERE Book__c = :bookId AND Status__c IN (\'Pending\', \'Ready\') ' +
        'ORDER BY Reservation_Date__c ASC, Id ASC',
      new Map<String, Object>{ 'bookId' => bookId },
      AccessLevel.SYSTEM_MODE
    );
    List<Reservation__c> updates = new List<Reservation__c>();
    Integer position = 1;
    for (Reservation__c row : rows) {
      Decimal targetPosition = row.Status__c == 'Pending' ? position : null;
      if (row.Queue_Position__c != targetPosition)
        updates.add(
          new Reservation__c(Id = row.Id, Queue_Position__c = targetPosition)
        );
      if (row.Status__c == 'Pending')
        position++;
    }
    if (!updates.isEmpty()) {
      Database.SaveResult[] results = Database.update(
        updates,
        AccessLevel.SYSTEM_MODE
      );
      for (Database.SaveResult result : results) {
        if (!result.isSuccess()) {
          throw new AuraHandledException(
            'Unable to resequence the reservation queue.'
          );
        }
      }
    }
  }
  private static Integer systemReservationCount(
    String query,
    Map<String, Object> binds
  ) {
    List<AggregateResult> rows = (List<AggregateResult>) Database.queryWithBinds(
      query,
      binds,
      AccessLevel.SYSTEM_MODE
    );
    return rows.isEmpty() ? 0 : Integer.valueOf(rows[0].get('total'));
  }

  private static void notifyReady(Reservation__c reservation) {
    if (Test.isRunningTest() || String.isBlank(reservation.Member__r.Email__c))
      return;
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ reservation.Member__r.Email__c });
    email.setSubject('Your library reservation is ready');
    email.setPlainTextBody(
      'Hello ' +
        reservation.Member__r.First_Name__c +
        ' ' +
        reservation.Member__r.Last_Name__c +
        ',\n\nA reserved book is ready for pickup. Please sign in to the Library portal for details.'
    );
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
  }
  public static void reportDefectiveCopy(Id loanId, String notes) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    reportDefectiveCopyWithoutPermission(loanId, notes);
  }

  private static void reportDefectiveCopyWithoutPermission(
    Id loanId,
    String notes
  ) {
    Borrow_Record__c loan = [
      SELECT
        Id,
        Book_Copy__c,
        Status__c,
        Return_Date__c,
        Defect_Reported_Date__c,
        Notes__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
      FOR UPDATE
    ];
    if (
      loan.Return_Date__c != null ||
      (loan.Status__c != 'Active' &&
      loan.Status__c != 'Overdue')
    )
      throw new AuraHandledException(
        'Only an active loan can be reported for replacement.'
      );
    if (loan.Defect_Reported_Date__c != null)
      throw new AuraHandledException(
        'A replacement has already been reported for this loan.'
      );
    Book_Copy__c copy = [
      SELECT Id, Book__c, Status__c, Condition__c
      FROM Book_Copy__c
      WHERE Id = :loan.Book_Copy__c
      FOR UPDATE
    ];
    if (copy.Status__c != 'Borrowed')
      throw new AuraHandledException(
        'The borrowed copy is not in a replaceable state.'
      );
    Datetime reported = System.now();
    String entry = 'Defective copy reported ' + String.valueOf(reported) + '.';
    if (!String.isBlank(notes))
      entry += ' ' + notes.trim();
    loan.Defect_Reported_Date__c = reported;
    loan.Replacement_Required__c = true;
    loan.Notes__c = String.isBlank(loan.Notes__c)
      ? entry
      : loan.Notes__c + '\n' + entry;
    update new Book_Copy__c(
      Id = copy.Id,
      Status__c = 'Damaged',
      Condition__c = 'Poor'
    );
    update loan;
    notifyReplacementMembers(copy.Book__c);
  }

  public static void reportDefectiveCopyForMember(
    Id loanId,
    Id memberId,
    String notes
  ) {
    if (loanId == null || memberId == null)
      throw new AuraHandledException('A loan must be selected.');
    Borrow_Record__c loan = [
      SELECT Id, Member__c
      FROM Borrow_Record__c
      WHERE Id = :loanId AND Member__c = :memberId
      LIMIT 1
    ];
    reportDefectiveCopyWithoutPermission(loan.Id, notes);
  }

  public static void notifyReplacementMembers(Id bookId) {
    if (bookId == null)
      return;
    List<Borrow_Record__c> waiting = [
      SELECT Id, Member__c, Member__r.Email__c, Book_Copy__r.Book__r.Name
      FROM Borrow_Record__c
      WHERE
        Replacement_Required__c = TRUE
        AND Return_Date__c = NULL
        AND Book_Copy__r.Book__c = :bookId
    ];
    if (waiting.isEmpty())
      return;
    Integer available = [
      SELECT COUNT()
      FROM Book_Copy__c
      WHERE Book__c = :bookId AND Status__c = 'Available'
    ];
    if (available == 0)
      return;
    List<LibraryMemberNotificationService.NotificationInput> inputs = new List<LibraryMemberNotificationService.NotificationInput>();
    for (Borrow_Record__c row : waiting) {
      inputs.add(
        new LibraryMemberNotificationService.NotificationInput(
          row.Member__c,
          'Replacement Available',
          'Replacement copy available',
          'A replacement copy for ' +
            row.Book_Copy__r.Book__r.Name +
            ' is available. Please contact the library or wait for a librarian to assign it.',
          row.Id,
          'REPLACEMENT-AVAILABLE-' + String.valueOf(row.Id),
          row.Member__r.Email__c
        )
      );
    }
    LibraryMemberNotificationService.createAll(inputs);
  }
  public static void replaceDefectiveCopy(Id loanId, Id replacementCopyId) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Borrow_Record__c loan = [
      SELECT
        Id,
        Book_Copy__c,
        Due_Date__c,
        Status__c,
        Return_Date__c,
        Defect_Reported_Date__c,
        Replacement_Required__c,
        Notes__c
      FROM Borrow_Record__c
      WHERE Id = :loanId
      FOR UPDATE
    ];
    if (!loan.Replacement_Required__c || loan.Defect_Reported_Date__c == null)
      throw new AuraHandledException(
        'Report the defective copy before assigning a replacement.'
      );
    if (
      loan.Return_Date__c != null ||
      (loan.Status__c != 'Active' &&
      loan.Status__c != 'Overdue')
    )
      throw new AuraHandledException(
        'Only an active loan can receive a replacement copy.'
      );
    if (replacementCopyId == null || replacementCopyId == loan.Book_Copy__c)
      throw new AuraHandledException('Choose a different replacement copy.');
    Book_Copy__c oldCopy = [
      SELECT Id, Book__c
      FROM Book_Copy__c
      WHERE Id = :loan.Book_Copy__c
      FOR UPDATE
    ];
    Book_Copy__c replacement = [
      SELECT Id, Book__c, Status__c
      FROM Book_Copy__c
      WHERE Id = :replacementCopyId
      FOR UPDATE
    ];
    if (replacement.Book__c != oldCopy.Book__c)
      throw new AuraHandledException(
        'The replacement copy must belong to the same book.'
      );
    if (replacement.Status__c != 'Available')
      throw new AuraHandledException('The replacement copy is not available.');
    Datetime replaced = System.now();
    Integer delayDays = loan.Defect_Reported_Date__c.date()
      .daysBetween(replaced.date());
    if (delayDays < 0)
      throw new AuraHandledException(
        'The defect report date cannot be in the future.'
      );
    loan.Book_Copy__c = replacement.Id;
    loan.Replacement_Date__c = replaced;
    loan.Replacement_Days__c = delayDays;
    loan.Replacement_Required__c = false;
    loan.Due_Date__c = loan.Due_Date__c == null
      ? null
      : loan.Due_Date__c.addDays(delayDays);
    loan.Notes__c =
      loan.Notes__c +
      '\nReplacement copy assigned ' +
      String.valueOf(replaced) +
      '. Due date extended by ' +
      String.valueOf(delayDays) +
      ' day(s).';
    update new Book_Copy__c(Id = replacement.Id, Status__c = 'Borrowed');
    update loan;
  }
}
