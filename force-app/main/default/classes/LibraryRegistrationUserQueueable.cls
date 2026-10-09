public without sharing class LibraryRegistrationUserQueueable implements Queueable {
    private Id registrationId; private Id contactId; private Id memberId;
    public LibraryRegistrationUserQueueable(Id registrationId, Id contactId, Id memberId) { this.registrationId=registrationId; this.contactId=contactId; this.memberId=memberId; }
    public void execute(QueueableContext context) {
        try {
            Library_Registration__c r=[SELECT Id, Email__c FROM Library_Registration__c WHERE Id=:registrationId LIMIT 1];
            Contact c=[SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id=:contactId LIMIT 1];
            Member__c m=[SELECT Id, User__c FROM Member__c WHERE Id=:memberId LIMIT 1];
            User u = m.User__c == null ? findOrCreateUser(c) : [SELECT Id FROM User WHERE Id=:m.User__c LIMIT 1];
            PermissionSet ps=[SELECT Id FROM PermissionSet WHERE Name=:LibraryRegistrationService.permissionSetName() LIMIT 1];
            if ([SELECT count() FROM PermissionSetAssignment WHERE AssigneeId=:u.Id AND PermissionSetId=:ps.Id] == 0) insert new PermissionSetAssignment(AssigneeId=u.Id, PermissionSetId=ps.Id);
            System.enqueueJob(new LibraryRegistrationFinalizeQueueable(registrationId, memberId, u.Id));
        } catch (Exception e) { LibraryRegistrationFailureQueueable.record(registrationId, message(e)); }
    }
    private static User findOrCreateUser(Contact c) {
        List<User> existing=[SELECT Id FROM User WHERE ContactId=:c.Id LIMIT 1]; if (!existing.isEmpty()) return existing[0];
        Profile p=[SELECT Id FROM Profile WHERE Name=:LibraryRegistrationService.profileName() LIMIT 1];
        String normalizedEmail=LibraryRegistrationService.normalizeEmail(c.Email);
        Integer at=normalizedEmail.indexOf('@'); String localPart=normalizedEmail.substring(0, at); String domainPart=normalizedEmail.substring(at + 1);
        String tag='.library.'+UserInfo.getOrganizationId().substring(0, 8).toLowerCase();
        Integer maxLocalLength=80 - tag.length() - domainPart.length() - 1;
        if (maxLocalLength < 1) maxLocalLength=1;
        String username=localPart.left(Math.min(maxLocalLength, localPart.length()))+tag+'@'+domainPart;
        if ([SELECT count() FROM User WHERE Username=:username]>0) {
            String randomTag='.'+String.valueOf(Crypto.getRandomInteger()).replace('-','');
            Integer randomLocalLength=80 - randomTag.length() - domainPart.length() - 1;
            username=localPart.left(Math.min(randomLocalLength, localPart.length()))+randomTag+'@'+domainPart;
        }
        String alias=(c.FirstName.left(Math.min(3,c.FirstName.length()))+c.LastName).left(8);
        User u=new User(ContactId=c.Id, ProfileId=p.Id, FirstName=c.FirstName, LastName=c.LastName, Email=c.Email, Username=username, Alias=alias,
            CommunityNickname=(c.FirstName+'.'+c.LastName+'.'+String.valueOf(Crypto.getRandomInteger()).replace('-','')).left(40), TimeZoneSidKey='Asia/Kolkata', LocaleSidKey='en_US', EmailEncodingKey='UTF-8', LanguageLocaleKey='en_US');
        Database.DMLOptions options = new Database.DMLOptions();
        options.EmailHeader.triggerUserEmail = true;
        Database.insert(u, options);
        return u;
    }
    private static String message(Exception e) { return 'External user provisioning could not be completed. Contact library administration.'; }
}
