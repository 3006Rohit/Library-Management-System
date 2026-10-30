public without sharing class LibraryTransactionContactService {
  public static void syncBorrowRecords(List<Borrow_Record__c> records) {
    syncContacts(records, 'Borrow_Record__c');
  }

  public static void syncReservations(List<Reservation__c> records) {
    syncContacts(records, 'Reservation__c');
  }

  public static void syncFines(List<Fine__c> records) {
    syncContacts(records, 'Fine__c');
  }

  public static void syncMembershipPayments(
    List<Membership_Payment__c> records
  ) {
    syncContacts(records, 'Membership_Payment__c');
  }

  public static void syncMemberNotifications(
    List<Member_Notification__c> records
  ) {
    syncContacts(records, 'Member_Notification__c');
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
      record.put(
        'Contact__c',
        memberId == null ? null : contactByMember.get(memberId)
      );
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
      WITH SYSTEM_MODE
    ];
    List<Reservation__c> reservations = [
      SELECT Id, Member__c, Contact__c
      FROM Reservation__c
      WHERE Member__c IN :changedMemberIds
      WITH SYSTEM_MODE
    ];
    List<Fine__c> fines = [
      SELECT Id, Member__c, Contact__c
      FROM Fine__c
      WHERE Member__c IN :changedMemberIds
      WITH SYSTEM_MODE
    ];
    List<Membership_Payment__c> membershipPayments = [
      SELECT Id, Member__c
      FROM Membership_Payment__c
      WHERE Member__c IN :changedMemberIds
      WITH SYSTEM_MODE
    ];
    List<Member_Notification__c> memberNotifications = [
      SELECT Id, Member__c
      FROM Member_Notification__c
      WHERE Member__c IN :changedMemberIds
      WITH SYSTEM_MODE
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
    for (Membership_Payment__c record : membershipPayments) {
      record.put('Contact__c', contactByMember.get(record.Member__c));
    }
    for (Member_Notification__c record : memberNotifications) {
      record.put('Contact__c', contactByMember.get(record.Member__c));
    }

    if (!borrowRecords.isEmpty()) {
      Database.update(borrowRecords, AccessLevel.SYSTEM_MODE);
    }
    if (!reservations.isEmpty()) {
      Database.update(reservations, AccessLevel.SYSTEM_MODE);
    }
    if (!fines.isEmpty()) {
      Database.update(fines, AccessLevel.SYSTEM_MODE);
    }
    if (!membershipPayments.isEmpty()) {
      Database.update(membershipPayments, AccessLevel.SYSTEM_MODE);
    }
    if (!memberNotifications.isEmpty()) {
      Database.update(memberNotifications, AccessLevel.SYSTEM_MODE);
    }
  }

  private static Map<Id, Id> getContactByMember(Set<Id> memberIdSet) {
    Map<Id, Id> contactByMember = new Map<Id, Id>();
    if (memberIdSet.isEmpty()) {
      return contactByMember;
    }
    // This service is invoked by transaction-maintenance triggers. The
    // originating Experience Cloud guest intentionally has no direct
    // Member__c CRUD/FLS, so make the trusted trigger lookup explicitly
    // system-mode instead of inheriting the initiating user's API access.
    List<Member__c> members = (List<Member__c>) Database.queryWithBinds(
      'SELECT Id, Contact__c FROM Member__c WHERE Id IN :memberIds',
      new Map<String, Object>{ 'memberIds' => memberIdSet },
      AccessLevel.SYSTEM_MODE
    );
    for (Member__c member : members) {
      contactByMember.put(member.Id, member.Contact__c);
    }
    return contactByMember;
  }
}
