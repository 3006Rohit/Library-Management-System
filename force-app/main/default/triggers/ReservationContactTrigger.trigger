trigger ReservationContactTrigger on Reservation__c (before insert, before update) {
    LibraryTransactionContactService.syncReservations(Trigger.new);
}
