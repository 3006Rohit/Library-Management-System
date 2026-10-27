public without sharing class LibraryReservationEtaService {
  private static final Integer DEFAULT_LOAN_DAYS = 14;

  /**
   * Recalculates reservation estimates for one or more books. Estimates are
   * deliberately deterministic and explainable: available copies are first,
   * then known active-loan due dates, then a conservative default duration.
   * The result is an operational estimate, not a promise of availability.
   */
  public static void recalculateForBook(Id bookId) {
    if (bookId == null)
      return;
    recalculateForBooks(new Set<Id>{ bookId });
  }

  public static void recalculateForBooks(Set<Id> bookIds) {
    if (bookIds == null || bookIds.isEmpty())
      return;

    Datetime now = System.now();
    Map<Id, Integer> availableByBook = new Map<Id, Integer>();
    for (AggregateResult row : [
      SELECT Book__c bookId, COUNT(Id) total
      FROM Book_Copy__c
      WHERE Book__c IN :bookIds AND Status__c = 'Available'
      GROUP BY Book__c
    ]) {
      availableByBook.put(
        (Id) row.get('bookId'),
        Integer.valueOf(row.get('total'))
      );
    }

    Map<Id, List<Datetime>> dueDatesByBook = new Map<Id, List<Datetime>>();
    for (Borrow_Record__c loan : [
      SELECT Book_Copy__r.Book__c, Due_Date__c
      FROM Borrow_Record__c
      WHERE
        Book_Copy__r.Book__c IN :bookIds
        AND Return_Date__c = NULL
        AND Status__c IN ('Active', 'Overdue')
        AND Due_Date__c != NULL
      ORDER BY Due_Date__c ASC, Id ASC
    ]) {
      Id bookId = loan.Book_Copy__r.Book__c;
      if (!dueDatesByBook.containsKey(bookId))
        dueDatesByBook.put(bookId, new List<Datetime>());
      dueDatesByBook.get(bookId).add(loan.Due_Date__c);
    }

    Map<Id, List<Reservation__c>> activeByBook = new Map<Id, List<Reservation__c>>();
    for (Reservation__c reservation : [
      SELECT
        Id,
        Book__c,
        Status__c,
        Queue_Position__c,
        Ready_Date__c,
        Estimated_Available_Date__c,
        ETA_Confidence__c,
        ETA_Last_Calculated__c,
        ETA_Reason__c
      FROM Reservation__c
      WHERE Book__c IN :bookIds AND Status__c IN ('Pending', 'Ready')
      ORDER BY Book__c, Reservation_Date__c ASC, Id ASC
    ]) {
      if (!activeByBook.containsKey(reservation.Book__c))
        activeByBook.put(reservation.Book__c, new List<Reservation__c>());
      activeByBook.get(reservation.Book__c).add(reservation);
    }

    List<Reservation__c> updates = new List<Reservation__c>();
    for (Id bookId : activeByBook.keySet()) {
      Integer availableCopies = availableByBook.containsKey(bookId)
        ? availableByBook.get(bookId)
        : 0;
      List<Datetime> dueDates = dueDatesByBook.containsKey(bookId)
        ? dueDatesByBook.get(bookId)
        : new List<Datetime>();
      Integer pendingPosition = 1;

      for (Reservation__c reservation : activeByBook.get(bookId)) {
        Datetime estimate;
        String confidence;
        String reason;

        if (reservation.Status__c == 'Ready') {
          estimate = reservation.Ready_Date__c == null
            ? now
            : reservation.Ready_Date__c;
          confidence = 'High';
          reason = 'A copy is assigned and ready for pickup.';
        } else {
          Integer position = pendingPosition++;
          EtaResult result = estimateFor(
            position,
            availableCopies,
            dueDates,
            now
          );
          estimate = result.estimatedDate;
          confidence = result.confidence;
          reason =
            'Queue position ' +
            String.valueOf(position) +
            '. ' +
            result.reason;
        }

        if (
          sameMoment(reservation.Estimated_Available_Date__c, estimate) &&
          reservation.ETA_Confidence__c == confidence &&
          reservation.ETA_Reason__c == reason &&
          reservation.ETA_Last_Calculated__c != null &&
          reservation.ETA_Last_Calculated__c.addMinutes(1) > now
        )
          continue;

        updates.add(
          new Reservation__c(
            Id = reservation.Id,
            Estimated_Available_Date__c = estimate,
            ETA_Confidence__c = confidence,
            ETA_Last_Calculated__c = now,
            ETA_Reason__c = reason
          )
        );
      }
    }

    if (!updates.isEmpty())
      Database.update(updates, AccessLevel.SYSTEM_MODE);
  }

  @TestVisible
  private class EtaResult {
    Datetime estimatedDate;
    String confidence;
    String reason;

    EtaResult(Datetime estimatedDate, String confidence, String reason) {
      this.estimatedDate = estimatedDate;
      this.confidence = confidence;
      this.reason = reason;
    }
  }

  @TestVisible
  private static EtaResult estimateFor(
    Integer position,
    Integer availableCopies,
    List<Datetime> dueDates,
    Datetime now
  ) {
    if (position <= availableCopies)
      return new EtaResult(
        now,
        'High',
        'An eligible copy is currently available.'
      );

    Integer dueDateIndex = position - availableCopies - 1;
    if (!dueDates.isEmpty() && dueDateIndex < dueDates.size()) {
      Datetime dueDate = dueDates[dueDateIndex];
      return new EtaResult(
        dueDate < now ? now : dueDate,
        'Medium',
        'Based on the next known active-loan due date.'
      );
    }

    if (!dueDates.isEmpty()) {
      Datetime lastDueDate = dueDates[dueDates.size() - 1];
      Integer additionalLoans = dueDateIndex - dueDates.size() + 1;
      return new EtaResult(
        (lastDueDate < now ? now : lastDueDate)
          .addDays(additionalLoans * DEFAULT_LOAN_DAYS),
        'Low',
        'Uses known due dates plus the default loan duration for later queue positions.'
      );
    }

    return new EtaResult(
      now.addDays(position * DEFAULT_LOAN_DAYS),
      'Low',
      'No active-loan due date is available; uses the default loan duration.'
    );
  }

  private static Boolean sameMoment(Datetime left, Datetime right) {
    if (left == null || right == null)
      return left == right;
    return left.getTime() == right.getTime();
  }
}
