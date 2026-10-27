@IsTest
private class LibraryReservationEtaServiceTest {
  private class Fixture {
    Membership_Plan__c plan;
    Account account;
    Contact contact;
    Member__c member;
    Book__c book;
    Book_Copy__c copy;
  }

  private static Fixture fixture(String suffix, String copyStatus) {
    Fixture f = new Fixture();
    f.plan = new Membership_Plan__c(
      Name = 'ETA Plan ' + suffix,
      Active__c = true,
      Duration_Days__c = 365,
      Borrow_Limit__c = 5,
      Loan_Duration_Days__c = 14,
      Reservation_Limit__c = 5,
      Renewal_Limit__c = 1,
      Fine_Per_Day__c = 5
    );
    insert f.plan;
    f.account = new Account(Name = 'ETA Account ' + suffix);
    insert f.account;
    f.contact = new Contact(
      FirstName = 'ETA',
      LastName = suffix,
      Email = 'eta-' + suffix.toLowerCase() + '@example.com',
      AccountId = f.account.Id
    );
    insert f.contact;
    f.member = new Member__c(
      First_Name__c = 'ETA',
      Last_Name__c = suffix,
      Email__c = f.contact.Email,
      Contact__c = f.contact.Id,
      External_Auth_Id__c = 'eta-' + suffix,
      Email_Verified__c = true,
      Account_Status__c = 'Active',
      Membership_Plan__c = f.plan.Id,
      Registration_Date__c = Date.today(),
      Membership_Start_Date__c = Date.today(),
      Membership_End_Date__c = Date.today().addDays(365),
      Max_Borrow_Limit__c = 5,
      Status__c = 'Active'
    );
    insert f.member;
    f.book = new Book__c(
      Name = 'ETA Book ' + suffix,
      ISBN__c = 'ETA-' + suffix,
      Status__c = 'Active',
      Total_Copies__c = 1,
      Available_Copies__c = copyStatus == 'Available' ? 1 : 0
    );
    insert f.book;
    f.copy = new Book_Copy__c(
      Book__c = f.book.Id,
      Barcode__c = 'ETA-BAR-' + suffix,
      Status__c = copyStatus,
      Condition__c = 'Good'
    );
    insert f.copy;
    return f;
  }

  @IsTest
  static void usesKnownActiveLoanDueDate() {
    Fixture f = fixture('Due', 'Borrowed');
    Datetime dueDate = System.now().addDays(5);
    insert new Borrow_Record__c(
      Member__c = f.member.Id,
      Book_Copy__c = f.copy.Id,
      Contact__c = f.contact.Id,
      Borrow_Date__c = System.now().addDays(-2),
      Due_Date__c = dueDate,
      Status__c = 'Active',
      Renewal_Count__c = 0
    );
    Reservation__c reservation = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 1
    );
    insert reservation;

    Test.startTest();
    LibraryReservationEtaService.recalculateForBook(f.book.Id);
    Test.stopTest();

    reservation = [
      SELECT
        Estimated_Available_Date__c,
        ETA_Confidence__c,
        ETA_Last_Calculated__c,
        ETA_Reason__c
      FROM Reservation__c
      WHERE Id = :reservation.Id
    ];
    System.assertEquals(dueDate, reservation.Estimated_Available_Date__c);
    System.assertEquals('Medium', reservation.ETA_Confidence__c);
    System.assertNotEquals(null, reservation.ETA_Last_Calculated__c);
    System.assert(reservation.ETA_Reason__c.contains('known active-loan'));
  }

  @IsTest
  static void fallsBackConservativelyWhenNoReturnDateExists() {
    Fixture f = fixture('Fallback', 'Lost');
    Reservation__c first = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Reservation_Date__c = System.now().addMinutes(-2),
      Status__c = 'Pending',
      Queue_Position__c = 1
    );
    Reservation__c second = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Contact__c = f.contact.Id,
      Reservation_Date__c = System.now(),
      Status__c = 'Pending',
      Queue_Position__c = 2
    );
    insert new List<Reservation__c>{ first, second };

    LibraryReservationEtaService.recalculateForBook(f.book.Id);
    Set<Id> reservationIds = new Set<Id>{ first.Id, second.Id };
    List<Reservation__c> rows = [
      SELECT Estimated_Available_Date__c, ETA_Confidence__c
      FROM Reservation__c
      WHERE Id IN :reservationIds
      ORDER BY Estimated_Available_Date__c ASC
    ];
    System.assertEquals(2, rows.size());
    System.assertEquals('Low', rows[0].ETA_Confidence__c);
    System.assert(
      rows[1].Estimated_Available_Date__c > rows[0].Estimated_Available_Date__c
    );
  }

  @IsTest
  static void readyReservationUsesAssignmentTimeWithHighConfidence() {
    Fixture f = fixture('Ready', 'Reserved');
    Datetime readyAt = System.now().addMinutes(-10);
    Reservation__c reservation = new Reservation__c(
      Member__c = f.member.Id,
      Book__c = f.book.Id,
      Book_Copy__c = f.copy.Id,
      Contact__c = f.contact.Id,
      Reservation_Date__c = System.now().addDays(-1),
      Ready_Date__c = readyAt,
      Status__c = 'Ready',
      Expiry_Date__c = System.now().addDays(2)
    );
    insert reservation;

    LibraryReservationEtaService.recalculateForBook(f.book.Id);
    reservation = [
      SELECT Estimated_Available_Date__c, ETA_Confidence__c, ETA_Reason__c
      FROM Reservation__c
      WHERE Id = :reservation.Id
    ];
    System.assertEquals(readyAt, reservation.Estimated_Available_Date__c);
    System.assertEquals('High', reservation.ETA_Confidence__c);
    System.assert(reservation.ETA_Reason__c.contains('ready for pickup'));
  }
}
