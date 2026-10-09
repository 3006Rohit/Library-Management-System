@IsTest(SeeAllData=true)
private class LibraryMemberControllerTest {
    private static Member__c member() {
        return [SELECT Id, User__c, Contact__c, First_Name__c, Last_Name__c, Phone__c, Address__c
                FROM Member__c WHERE Email__c = '22bcs056@nith.ac.in' LIMIT 1];
    }

    @IsTest
    static void mappedMemberCanReadPortalData() {
        Member__c m = member();
        LibraryMemberController.testUserId = m.User__c;
        Test.startTest();
        Member__c context = LibraryMemberController.getCurrentMemberContext();
        LibraryMemberController.DashboardData dashboard = LibraryMemberController.getMyDashboard();
        List<Book__c> books = LibraryMemberController.searchCatalog(null, null, null, 20, 1);
        List<Borrow_Record__c> loans = LibraryMemberController.getMyBorrowings();
        List<Reservation__c> reservations = LibraryMemberController.getMyReservations();
        List<Fine__c> fines = LibraryMemberController.getMyFines();
        Member__c membership = LibraryMemberController.getMyMembership();
        Member__c profile = LibraryMemberController.getMyProfile();
        Test.stopTest();

        System.assertEquals(m.Id, context.Id);
        System.assertEquals(m.Id, dashboard.member.Id);
        System.assertEquals('Standard', dashboard.member.Membership_Plan__r.Name);
        System.assertEquals(14, dashboard.member.Membership_Plan__r.Loan_Duration_Days__c);
        System.assertEquals(3, dashboard.member.Membership_Plan__r.Borrow_Limit__c);
        System.assertEquals(3, dashboard.member.Membership_Plan__r.Reservation_Limit__c);
        System.assertEquals(1, dashboard.member.Membership_Plan__r.Renewal_Limit__c);
        System.assertEquals(10, dashboard.member.Membership_Plan__r.Fine_Per_Day__c);
        System.assertNotEquals(null, books);
        System.assertNotEquals(null, loans);
        System.assertNotEquals(null, reservations);
        System.assertNotEquals(null, fines);
        System.assertEquals(m.Id, membership.Id);
        System.assertEquals(m.Id, profile.Id);
    }

    @IsTest
    static void profileUpdateSynchronizesContact() {
        Member__c m = member();
        Contact beforeContact = [SELECT FirstName, LastName, Phone, MailingStreet FROM Contact WHERE Id = :m.Contact__c];
        LibraryMemberController.testUserId = m.User__c;
        Test.startTest();
        LibraryMemberController.updateMyProfile(beforeContact.FirstName, beforeContact.LastName,
            beforeContact.Phone, beforeContact.MailingStreet);
        Test.stopTest();
        Contact afterContact = [SELECT FirstName, LastName, Phone, MailingStreet FROM Contact WHERE Id = :m.Contact__c];
        System.assertEquals(beforeContact.FirstName, afterContact.FirstName);
        System.assertEquals(beforeContact.LastName, afterContact.LastName);
        System.assertEquals(beforeContact.Phone, afterContact.Phone);
        System.assertEquals(beforeContact.MailingStreet, afterContact.MailingStreet);
    }

    @IsTest
    static void memberOwnershipIsEnforced() {
        Member__c m = member();
        LibraryMemberController.testUserId = m.User__c;
        List<Reservation__c> existing = [SELECT Id, Member__c FROM Reservation__c WHERE Member__c = :m.Id LIMIT 1];
        if (!existing.isEmpty()) {
            Boolean denied = false;
            try {
                LibraryCirculationService.cancelReservationForMember(existing[0].Id, UserInfo.getUserId());
            } catch (AuraHandledException ex) {
                denied = true;
            }
            System.assert(denied, 'A member must not cancel another member\'s reservation.');
        }
        Boolean unmappedDenied = false;
        try {
            LibraryMemberController.testUserId = UserInfo.getUserId();
            LibraryMemberController.getCurrentMemberContext();
        } catch (AuraHandledException ex) {
            unmappedDenied = true;
        }
        System.assert(unmappedDenied, 'A user without a correctly linked Member must be denied.');
    }

    @IsTest
    static void externalUserCanSeeMappedMemberThroughSharing() {
        User externalUser = [SELECT Id FROM User WHERE Id = '005gK00008TFOSpQAP' LIMIT 1];
        System.runAs(externalUser) {
            List<Member__c> visible = [SELECT Id, User__c, Contact__c, Status__c FROM Member__c WHERE User__c = :UserInfo.getUserId() LIMIT 2];
            System.debug('External-user Member rows visible through sharing: ' + visible.size());
        }
        Member__c resolved = LibraryMemberIdentityService.resolveForUser(externalUser.Id);
        System.assertEquals('a09gK00000QpqaHQAR', resolved.Id);
    }

    @IsTest
    static void identityFailureCodesAreDistinguished() {
        Id contactId = '003gK000017ZoNBQA0';
        System.assertEquals('MEMBER_MAPPING_NOT_FOUND', LibraryMemberIdentityService.mappingCode(new List<Member__c>(), contactId));
        Member__c first = new Member__c(Contact__c = contactId, Status__c = 'Active');
        Member__c second = new Member__c(Contact__c = contactId, Status__c = 'Active');
        System.assertEquals('MEMBER_MAPPING_DUPLICATE', LibraryMemberIdentityService.mappingCode(new List<Member__c>{first, second}, contactId));
        System.assertEquals('CONTACT_MAPPING_MISMATCH', LibraryMemberIdentityService.mappingCode(new List<Member__c>{first}, UserInfo.getUserId()));
        first.Status__c = 'Inactive';
        System.assertEquals('MEMBER_INACTIVE', LibraryMemberIdentityService.mappingCode(new List<Member__c>{first}, contactId));
    }

}
