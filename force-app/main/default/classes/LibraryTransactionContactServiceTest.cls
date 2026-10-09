@IsTest
private class LibraryTransactionContactServiceTest {
    @TestSetup
    static void createData() {
        Contact firstContact = new Contact(FirstName = 'Member', LastName = 'One');
        Contact secondContact = new Contact(FirstName = 'Member', LastName = 'Two');
        insert new List<Contact>{ firstContact, secondContact };

        insert new List<Member__c>{
            new Member__c(Contact__c = firstContact.Id, First_Name__c = 'Member', Last_Name__c = 'One'),
            new Member__c(Contact__c = secondContact.Id, First_Name__c = 'Member', Last_Name__c = 'Two')
        };
    }

    @IsTest
    static void synchronizesAllTransactionTypesAndMemberChanges() {
        List<Member__c> members = [SELECT Id, Contact__c FROM Member__c ORDER BY CreatedDate];
        Id firstMemberId = members[0].Id;
        Id secondMemberId = members[1].Id;
        Id firstContactId = members[0].Contact__c;
        Id secondContactId = members[1].Contact__c;

        Borrow_Record__c borrow = new Borrow_Record__c(Member__c = firstMemberId);
        Reservation__c reservation = new Reservation__c(Member__c = firstMemberId);
        Fine__c fine = new Fine__c(Member__c = firstMemberId, Fine_Type__c = 'Other', Amount__c = 10);
        insert new List<SObject>{ borrow, reservation, fine };

        borrow = [SELECT Contact__c FROM Borrow_Record__c WHERE Id = :borrow.Id];
        reservation = [SELECT Contact__c FROM Reservation__c WHERE Id = :reservation.Id];
        fine = [SELECT Contact__c FROM Fine__c WHERE Id = :fine.Id];
        System.assertEquals(firstContactId, borrow.Contact__c);
        System.assertEquals(firstContactId, reservation.Contact__c);
        System.assertEquals(firstContactId, fine.Contact__c);

        borrow.Member__c = secondMemberId;
        update borrow;
        System.assertEquals(secondContactId, [SELECT Contact__c FROM Borrow_Record__c WHERE Id = :borrow.Id].Contact__c);

        members[0].Contact__c = secondContactId;
        update members[0];
        System.assertEquals(secondContactId, [SELECT Contact__c FROM Reservation__c WHERE Id = :reservation.Id].Contact__c);
        System.assertEquals(secondContactId, [SELECT Contact__c FROM Fine__c WHERE Id = :fine.Id].Contact__c);

        members[0].Contact__c = null;
        update members[0];
        System.assertEquals(null, [SELECT Contact__c FROM Reservation__c WHERE Id = :reservation.Id].Contact__c);
        System.assertEquals(null, [SELECT Contact__c FROM Fine__c WHERE Id = :fine.Id].Contact__c);
    }

    @IsTest
    static void clearsContactWhenMemberIsCleared() {
        Member__c member = [SELECT Id FROM Member__c LIMIT 1];
        Borrow_Record__c borrow = new Borrow_Record__c(Member__c = member.Id);
        insert borrow;
        borrow.Member__c = null;
        update borrow;
        System.assertEquals(null, [SELECT Contact__c FROM Borrow_Record__c WHERE Id = :borrow.Id].Contact__c);
    }
}
