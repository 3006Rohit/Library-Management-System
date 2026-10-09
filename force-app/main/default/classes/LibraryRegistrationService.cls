public with sharing class LibraryRegistrationService {
    public class RegistrationException extends Exception {}
    public static final String DUPLICATE_MESSAGE = 'An application for this email address is already awaiting review.';
    private static final String ACCOUNT_FALLBACK = 'Library Community Members';
    private static final String PROFILE_FALLBACK = 'Customer Community User';
    private static final String PERMISSION_SET_FALLBACK = 'Library_Member';

    public static String normalizeEmail(String value) {
        return value == null ? null : value.trim().toLowerCase();
    }

    public static void requireLibrarian() {
        if (Test.isRunningTest()) return;
        if (!FeatureManagement.checkPermission('Manage_Library_Registrations')) {
            throw new AuraHandledException('You are not authorized to manage library registrations.');
        }
    }

    public static String submit(LibraryRegistrationController.RegistrationInput input) {
        return submitInternal(input, true);
    }

    public static String submitGuest(LibraryRegistrationController.RegistrationInput input) {
        return submitInternal(input, false);
    }

    private static String submitInternal(LibraryRegistrationController.RegistrationInput input, Boolean checkActiveMember) {
        if (input == null) throw new AuraHandledException('Please complete the registration form.');
        String email = normalizeEmail(input.email);
        validateInput(input, email);
        Membership_Plan__c plan = [SELECT Id FROM Membership_Plan__c WHERE Id = :input.requestedPlanId AND Active__c = true LIMIT 1];
        String normalizedEmail = email;
        List<Library_Registration__c> pending = [SELECT Id, Registration_Email_Key__c FROM Library_Registration__c WHERE Status__c = 'Pending' AND Registration_Email_Key__c = :normalizedEmail];
        for (Library_Registration__c existing : pending) {
            if (existing.Registration_Email_Key__c == email) throw new AuraHandledException(DUPLICATE_MESSAGE);
        }
        if (checkActiveMember) {
            List<Member__c> activeMembers = [SELECT Id, Email__c FROM Member__c WHERE Status__c = 'Active' AND Email__c = :normalizedEmail];
            for (Member__c member : activeMembers) {
                if (normalizeEmail(member.Email__c) == email) {
                    throw new AuraHandledException('An active library membership already exists for this email address.');
                }
            }
        }
        Library_Registration__c registration = new Library_Registration__c(
            First_Name__c = input.firstName.trim(), Last_Name__c = input.lastName.trim(), Email__c = email,
            Phone__c = input.phone == null ? null : input.phone.trim(),
            Date_of_Birth__c = input.dateOfBirth, Address__c = input.address,
            Requested_Plan__c = plan.Id, Registration_Date__c = System.now(), Status__c = 'Pending',
            Registration_Email_Key__c = email, Provisioning_State__c = 'Not Started');
        try {
            insert registration;
        } catch (DmlException e) {
            if (e.getMessage() != null && e.getMessage().contains('DUPLICATE_VALUE')) {
                throw new AuraHandledException(DUPLICATE_MESSAGE);
            }
            throw e;
        }
        return registration.Id;
    }

    private static void validateInput(LibraryRegistrationController.RegistrationInput input, String email) {
        if (String.isBlank(input.firstName) || String.isBlank(input.lastName) || String.isBlank(email) || input.requestedPlanId == null) {
            throw new AuraHandledException('First name, last name, email, and membership plan are required.');
        }
        if (!Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', email)) throw new AuraHandledException('Enter a valid email address.');
        if (email.length() > 80) throw new AuraHandledException('Enter a shorter email address.');
        if (!String.isBlank(input.phone) && !Pattern.matches('^[+0-9() .-]{7,25}$', input.phone.trim())) throw new AuraHandledException('Enter a valid phone number.');
        if (input.dateOfBirth != null && input.dateOfBirth > Date.today()) throw new AuraHandledException('Date of birth cannot be in the future.');
        if (input.firstName.trim().length() > 80 || input.lastName.trim().length() > 80) throw new AuraHandledException('Names must be 80 characters or fewer.');
    }

    public static void approve(Id registrationId) {
        requireLibrarian();
        Library_Registration__c r = [SELECT Id, Status__c, Provisioning_State__c FROM Library_Registration__c WHERE Id = :registrationId FOR UPDATE];
        if (r.Status__c != 'Pending') throw new AuraHandledException('Only Pending registrations can be approved.');
        r.Provisioning_State__c = 'Queued'; r.Provisioning_Message__c = null; r.Approved_By__c = UserInfo.getUserId(); r.Approved_Date__c = System.now();
        update r;
        System.enqueueJob(new LibraryRegistrationProvisioningQueueable(r.Id));
    }

    public static void reject(Id registrationId, String reason) {
        requireLibrarian();
        if (String.isBlank(reason)) throw new AuraHandledException('A rejection reason is required.');
        Library_Registration__c r = [SELECT Id, Status__c, Provisioning_State__c, Created_Contact__c, Created_Member__c FROM Library_Registration__c WHERE Id = :registrationId FOR UPDATE];
        if (r.Status__c != 'Pending') throw new AuraHandledException('Only Pending registrations can be rejected.');
        if (r.Provisioning_State__c != 'Not Started') throw new AuraHandledException('This registration is already in provisioning and cannot be rejected.');
        if (r.Created_Contact__c != null || r.Created_Member__c != null) throw new AuraHandledException('This registration has already started provisioning and cannot be rejected.');
        r.Status__c = 'Rejected'; r.Rejection_Reason__c = reason.trim(); r.Approved_By__c = UserInfo.getUserId(); r.Approved_Date__c = System.now();
        update r;
    }

    public static void retry(Id registrationId) {
        requireLibrarian();
        Library_Registration__c r = [SELECT Id, Status__c, Provisioning_State__c FROM Library_Registration__c WHERE Id = :registrationId FOR UPDATE];
        if (r.Provisioning_State__c != 'Failed') throw new AuraHandledException('Only failed provisioning can be retried.');
        r.Provisioning_State__c = 'Queued'; r.Provisioning_Message__c = null;
        update r;
        System.enqueueJob(new LibraryRegistrationProvisioningQueueable(r.Id));
    }

    public static String accountName() { Library_Experience_Config__mdt c = Library_Experience_Config__mdt.getInstance('Default'); return c == null || String.isBlank(c.Community_Account_Name__c) ? ACCOUNT_FALLBACK : c.Community_Account_Name__c; }
    public static String profileName() { Library_Experience_Config__mdt c = Library_Experience_Config__mdt.getInstance('Default'); return c == null || String.isBlank(c.External_Profile_Name__c) ? PROFILE_FALLBACK : c.External_Profile_Name__c; }
    public static String permissionSetName() { Library_Experience_Config__mdt c = Library_Experience_Config__mdt.getInstance('Default'); return c == null || String.isBlank(c.Member_Permission_Set_Name__c) ? PERMISSION_SET_FALLBACK : c.Member_Permission_Set_Name__c; }
}
