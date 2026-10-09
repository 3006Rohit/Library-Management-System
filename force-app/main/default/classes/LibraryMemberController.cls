public with sharing class LibraryMemberController {
    @TestVisible private static Id testUserId;
    public class DashboardData { @AuraEnabled public Member__c member; @AuraEnabled public Integer activeLoans; @AuraEnabled public Integer dueSoon; @AuraEnabled public Integer overdueLoans; @AuraEnabled public Integer activeReservations; @AuraEnabled public Decimal outstandingFine; @AuraEnabled public List<Borrow_Record__c> loans; @AuraEnabled public List<Reservation__c> reservations; }
    private static Id userId(){return Test.isRunningTest()&&testUserId!=null?testUserId:UserInfo.getUserId();}
    private static Member__c currentMember(){return LibraryMemberIdentityService.resolve(userId());}
    @AuraEnabled(cacheable=true) public static Member__c getCurrentMemberContext(){return currentMember();}
    @AuraEnabled(cacheable=true) public static DashboardData getMyDashboard(){Member__c m=currentMember();try{DashboardData d=new DashboardData();d.member=m;d.loans=getMyBorrowings();d.reservations=getMyReservations();d.activeLoans=0;d.dueSoon=0;d.overdueLoans=0;d.activeReservations=0;d.outstandingFine=0;for(Borrow_Record__c l:d.loans)if(l.Return_Date__c==null){d.activeLoans++;if(l.Due_Date__c!=null&&l.Due_Date__c< System.now())d.overdueLoans++;else if(l.Due_Date__c!=null&&l.Due_Date__c<=System.now().addDays(3))d.dueSoon++;}for(Reservation__c r:d.reservations)if(r.Status__c=='Pending'||r.Status__c=='Ready')d.activeReservations++;for(Fine__c f:getMyFines())if(f.Status__c=='Unpaid'||f.Status__c=='Partially Paid')d.outstandingFine+=(f.Balance__c==null?0:f.Balance__c);return d;}catch(Exception ex){String detail=ex.getTypeName()+': '+ex.getMessage();System.debug(LoggingLevel.ERROR,'MEMBER_DATA_LOAD_FAILED: '+detail);throw new AuraHandledException('MEMBER_PORTAL_ERROR [MEMBER_DATA_LOAD_FAILED]: '+detail);}}
    @AuraEnabled(cacheable=true) public static List<Book__c> searchCatalog(String searchTerm,String categoryId,String availability,Integer pageSize,Integer pageNumber){
        currentMember();
        Integer size = (pageSize == null || pageSize < 1 || pageSize > 50) ? 20 : pageSize;
        Integer off = (pageNumber == null || pageNumber < 1) ? 0 : (pageNumber - 1) * size;
        String term = String.isBlank(searchTerm) ? null : '%' + searchTerm.trim() + '%';
        String q='SELECT Id,Name,ISBN__c,Publisher__c,Publication_Year__c,Edition__c,Language__c,Description__c,Cover_Image_URL__c,Total_Copies__c,Available_Copies__c,Status__c,(SELECT Author__r.Name FROM Book_Authors__r),(SELECT Book_Category__r.Name FROM Book_Category_Links__r) FROM Book__c';
        List<String> c=new List<String>();
        if(term!=null)c.add('(Name LIKE :term OR ISBN__c LIKE :term OR Id IN (SELECT Book__c FROM Book_Author__c WHERE Author__r.Name LIKE :term))');
        if(!String.isBlank(categoryId))c.add('Id IN (SELECT Book__c FROM Book_Category_Link__c WHERE Book_Category__c=:categoryId)');
        if(availability=='Available')c.add('Available_Copies__c>0');
        if(availability=='Unavailable')c.add('Available_Copies__c=0');
        if(!c.isEmpty())q+=' WHERE '+String.join(c,' AND ');
        q+=' ORDER BY Name LIMIT :size OFFSET :off';
        return Database.query(q);
    }
    @AuraEnabled(cacheable=true) public static List<Book_Category__c> getCatalogCategories(){currentMember();return [SELECT Id,Name,Description__c FROM Book_Category__c WHERE Active__c=true ORDER BY Name LIMIT 100];}
    @AuraEnabled(cacheable=true) public static Book__c getBookDetails(Id bookId){currentMember();return [SELECT Id,Name,ISBN__c,Publisher__c,Publication_Year__c,Edition__c,Language__c,Description__c,Cover_Image_URL__c,Total_Copies__c,Available_Copies__c,Status__c,(SELECT Author__r.Name FROM Book_Authors__r),(SELECT Book_Category__r.Name FROM Book_Category_Links__r) FROM Book__c WHERE Id=:bookId];}
    @AuraEnabled(cacheable=true) public static List<Borrow_Record__c> getMyBorrowings(){Member__c m=currentMember();return [SELECT Id,Name,Book_Copy__r.Name,Book_Copy__r.Barcode__c,Book_Copy__r.Book__r.Name,Borrow_Date__c,Due_Date__c,Return_Date__c,Status__c,Renewal_Count__c FROM Borrow_Record__c WHERE Member__c=:m.Id ORDER BY Borrow_Date__c DESC LIMIT 200];}
    @AuraEnabled public static void renewMyLoan(Id borrowRecordId){Member__c m=currentMember();LibraryCirculationService.renewLoanForMember(borrowRecordId,m.Id);}
    @AuraEnabled(cacheable=true) public static List<Reservation__c> getMyReservations(){Member__c m=currentMember();return [SELECT Id,Name,Book__r.Name,Book_Copy__r.Name,Reservation_Date__c,Queue_Position__c,Status__c,Ready_Date__c,Expiry_Date__c,Fulfilled_Date__c FROM Reservation__c WHERE Member__c=:m.Id ORDER BY Reservation_Date__c DESC LIMIT 200];}
    @AuraEnabled public static Id reserveBook(Id bookId){Member__c m=currentMember();return LibraryCirculationService.createReservationForMember(m.Id,bookId);}
    @AuraEnabled public static void cancelMyReservation(Id reservationId){Member__c m=currentMember();LibraryCirculationService.cancelReservationForMember(reservationId,m.Id);}
    @AuraEnabled(cacheable=true) public static List<Fine__c> getMyFines(){Member__c m=currentMember();return [SELECT Id,Name,Borrow_Record__r.Name,Borrow_Record__r.Book_Copy__r.Book__r.Name,Fine_Type__c,Amount__c,Paid_Amount__c,Balance__c,Status__c,Generated_Date__c,Paid_Date__c FROM Fine__c WHERE Member__c=:m.Id ORDER BY Generated_Date__c DESC LIMIT 200];}
    @AuraEnabled(cacheable=true) public static Member__c getMyMembership(){return currentMember();}
    @AuraEnabled(cacheable=true) public static Member__c getMyProfile(){return currentMember();}
    @AuraEnabled public static void updateMyProfile(String firstName,String lastName,String phone,String address){Member__c m=currentMember();User u=[SELECT ContactId FROM User WHERE Id=:userId()];m.First_Name__c=firstName;m.Last_Name__c=lastName;m.Phone__c=phone;m.Address__c=address;update m;if(u.ContactId!=null)update new Contact(Id=u.ContactId,FirstName=firstName,LastName=lastName,Phone=phone,MailingStreet=address);}
}
