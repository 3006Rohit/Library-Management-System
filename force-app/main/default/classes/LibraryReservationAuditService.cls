public without sharing class LibraryReservationAuditService {
  public static void record(
    Id reservationId,
    String action,
    String fromStatus,
    String toStatus,
    Decimal queuePosition,
    String notes
  ) {
    if (reservationId == null)
      return;
    try {
      Database.query(
        'SELECT Id,Reservation__c,Action__c,From_Status__c,To_Status__c,Queue_Position__c,Actor__c,Occurred_At__c,Notes__c FROM Reservation_Audit__c LIMIT 0'
      );
      Database.insert(
        new Reservation_Audit__c(
          Reservation__c = reservationId,
          Action__c = action,
          From_Status__c = fromStatus,
          To_Status__c = toStatus,
          Queue_Position__c = queuePosition,
          Actor__c = UserInfo.getUserId(),
          Occurred_At__c = System.now(),
          Notes__c = notes
        ),
        AccessLevel.SYSTEM_MODE
      );
    } catch (Exception error) {
      System.debug(
        LoggingLevel.ERROR,
        'RESERVATION_AUDIT_UNAVAILABLE: ' +
          error.getTypeName() +
          ': ' +
          error.getMessage()
      );
    }
  }
}
