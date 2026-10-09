@IsTest
public class LibraryTestDataFactory {
    public static Membership_Plan__c plan(String name) {
        Membership_Plan__c value = new Membership_Plan__c(Name=name, Active__c=true, Duration_Days__c=30, Borrow_Limit__c=5);
        insert value;
        return value;
    }

    public static Account communityAccount() {
        Account value = new Account(Name='Library Community Members');
        insert value;
        return value;
    }

    public static Library_Registration__c registration(Membership_Plan__c plan, String email, String state) {
        String key = email.trim().toLowerCase();
        Library_Registration__c value = new Library_Registration__c(
            First_Name__c='Test', Last_Name__c='Member', Email__c=key, Registration_Email_Key__c=key,
            Phone__c='+91 9876543210', Requested_Plan__c=plan.Id, Registration_Date__c=System.now(),
            Status__c='Pending', Provisioning_State__c=state);
        insert value;
        return value;
    }

    public static Contact contact(Account account, String email) {
        Contact value = new Contact(FirstName='Test', LastName='Member', Email=email, AccountId=account.Id);
        insert value;
        return value;
    }

    public static Member__c member(Contact contact, Membership_Plan__c plan, String email) {
        Member__c value = new Member__c(
            First_Name__c='Test', Last_Name__c='Member', Email__c=email, Contact__c=contact.Id,
            Membership_Plan__c=plan.Id, Registration_Date__c=Date.today(), Membership_Start_Date__c=Date.today(),
            Membership_End_Date__c=Date.today().addDays(30), Max_Borrow_Limit__c=5, Status__c='Active');
        insert value;
        return value;
    }
}
