global without sharing class LibraryReservationExpiryScheduler implements Schedulable {
  global void execute(SchedulableContext context) {
    Database.executeBatch(new LibraryReservationExpiryBatch(), 50);
  }
}
