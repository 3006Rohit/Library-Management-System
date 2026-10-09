public with sharing class LibraryTransactionContactService {
    public static void syncBorrowRecords(List<Borrow_Record__c> records) {
        syncContacts(records, 'Borrow_Record__c');
    }

    public static void syncReservations(List<Reservation__c> records) {
        syncContacts(records, 'Reservation__c');
    }

    public static void syncFines(List<Fine__c> records) {
        syncContacts(records, 'Fine__c');
    }

    private static void syncContacts(List<SObject> records, String objectName) {
        Set<Id> memberIds = new Set<Id>();
        for (SObject record : records) {
            Id memberId = (Id) record.get('Member__c');
            if (memberId != null) {
                memberIds.add(memberId);
            }
        }

        Map<Id, Id> contactByMember = getContactByMember(memberIds);
        for (SObject record : records) {
            Id memberId = (Id) record.get('Member__c');
            record.put('Contact__c', memberId == null ? null : contactByMember.get(memberId));
        }
    }

    public static void syncTransactionsForChangedMembers(
        List<Member__c> newMembers,
        Map<Id, Member__c> oldMembers
    ) {
        Set<Id> changedMemberIds = new Set<Id>();
        for (Member__c member : newMembers) {
            Member__c oldMember = oldMembers.get(member.Id);
            if (oldMember != null && oldMember.Contact__c != member.Contact__c) {
                changedMemberIds.add(member.Id);
            }
        }
        if (changedMemberIds.isEmpty()) {
            return;
        }

        Map<Id, Id> contactByMember = getContactByMember(changedMemberIds);
        List<Borrow_Record__c> borrowRecords = [
            SELECT Id, Member__c, Contact__c
            FROM Borrow_Record__c
            WHERE Member__c IN :changedMemberIds
        ];
        List<Reservation__c> reservations = [
            SELECT Id, Member__c, Contact__c
            FROM Reservation__c
            WHERE Member__c IN :changedMemberIds
        ];
        List<Fine__c> fines = [
            SELECT Id, Member__c, Contact__c
            FROM Fine__c
            WHERE Member__c IN :changedMemberIds
        ];

        for (Borrow_Record__c record : borrowRecords) {
            record.Contact__c = contactByMember.get(record.Member__c);
        }
        for (Reservation__c record : reservations) {
            record.Contact__c = contactByMember.get(record.Member__c);
        }
        for (Fine__c record : fines) {
            record.Contact__c = contactByMember.get(record.Member__c);
        }

        if (!borrowRecords.isEmpty()) {
            update borrowRecords;
        }
        if (!reservations.isEmpty()) {
            update reservations;
        }
        if (!fines.isEmpty()) {
            update fines;
        }
    }

    private static Map<Id, Id> getContactByMember(Set<Id> memberIds) {
        Map<Id, Id> contactByMember = new Map<Id, Id>();
        if (memberIds.isEmpty()) {
            return contactByMember;
        }
        for (Member__c member : [
            SELECT Id, Contact__c
            FROM Member__c
            WHERE Id IN :memberIds
        ]) {
            contactByMember.put(member.Id, member.Contact__c);
        }
        return contactByMember;
    }
}
