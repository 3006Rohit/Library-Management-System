// Repair queue positions after switching to pending-only queue numbering.
Map<Id, List<Reservation__c>> byBook = new Map<Id, List<Reservation__c>>();
for (Reservation__c row : [
    SELECT Id, Book__c, Status__c, Queue_Position__c
    FROM Reservation__c
    WHERE Status__c IN ('Pending', 'Ready')
    ORDER BY Book__c, Reservation_Date__c ASC, Id ASC
]) {
    if (!byBook.containsKey(row.Book__c)) byBook.put(row.Book__c, new List<Reservation__c>());
    byBook.get(row.Book__c).add(row);
}
List<Reservation__c> updates = new List<Reservation__c>();
for (List<Reservation__c> rows : byBook.values()) {
    Integer position = 1;
    for (Reservation__c row : rows) {
        Decimal target = row.Status__c == 'Pending' ? position : null;
        if (row.Queue_Position__c != target)
            updates.add(new Reservation__c(Id = row.Id, Queue_Position__c = target));
        if (row.Status__c == 'Pending') position++;
    }
}
if (!updates.isEmpty()) update updates;
System.debug(LoggingLevel.INFO, 'Resequenced ' + updates.size() + ' reservation record(s).');
