public without sharing class LibraryReservationWorkflowService {
  public static Boolean prepareReservation(Id reservationId) {
    List<Reservation__c> reservations = [
      SELECT Id, Book__c, Status__c
      FROM Reservation__c
      WHERE Id = :reservationId
      LIMIT 1
    ];
    if (reservations.isEmpty() || reservations[0].Status__c != 'Pending')
      throw new AuraHandledException(
        'Only a waiting reservation can be prepared.'
      );
    promoteAvailableReservations(reservations[0].Book__c);
    return [SELECT Status__c FROM Reservation__c WHERE Id = :reservationId]
      .Status__c == 'Ready';
  }

  public static void promoteAvailableReservations(Id bookId) {
    if (bookId == null)
      return;
    List<Book__c> lockedBook = [
      SELECT Id
      FROM Book__c
      WHERE Id = :bookId
      LIMIT 1
      FOR UPDATE
    ];
    if (lockedBook.isEmpty())
      return;
    List<Book_Copy__c> copies = [
      SELECT Id
      FROM Book_Copy__c
      WHERE Book__c = :bookId AND Status__c = 'Available'
      ORDER BY Name
      LIMIT 50
    ];
    List<Reservation__c> pending = [
      SELECT
        Id,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Member__r.Email__c,
        Queue_Position__c
      FROM Reservation__c
      WHERE Book__c = :bookId AND Status__c = 'Pending'
      ORDER BY Reservation_Date__c ASC, Id ASC
      LIMIT 50
    ];
    Integer count = Math.min(copies.size(), pending.size());
    if (count == 0)
      return;
    Datetime readyAt = System.now();
    List<Reservation__c> reservationUpdates = new List<Reservation__c>();
    List<Book_Copy__c> copyUpdates = new List<Book_Copy__c>();
    for (Integer index = 0; index < count; index++) {
      Reservation__c reservation = pending[index];
      reservation.Status__c = 'Ready';
      reservation.Book_Copy__c = copies[index].Id;
      reservation.Queue_Position__c = null;
      reservation.Ready_Date__c = readyAt;
      reservation.Expiry_Date__c = readyAt.addDays(
        LibraryPolicyService.holdDurationDays()
      );
      reservationUpdates.add(reservation);
      copyUpdates.add(
        new Book_Copy__c(Id = copies[index].Id, Status__c = 'Reserved')
      );
    }
    Database.update(reservationUpdates, AccessLevel.SYSTEM_MODE);
    Database.update(copyUpdates, AccessLevel.SYSTEM_MODE);
    for (Reservation__c reservation : reservationUpdates) {
      LibraryReservationAuditService.record(
        reservation.Id,
        'Promoted',
        'Pending',
        'Ready',
        reservation.Queue_Position__c,
        'An available copy was assigned.'
      );
      notifyReady(reservation);
    }
    LibraryReservationEtaService.recalculateForBook(bookId);
  }

  private static void notifyReady(Reservation__c reservation) {
    if (
      Test.isRunningTest() ||
      reservation.Member__r == null ||
      String.isBlank(reservation.Member__r.Email__c)
    )
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
}
