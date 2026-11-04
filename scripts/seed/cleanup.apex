// Removes everything created by scripts/seed/1..3 (matched by the SEED markers).
// Existing org data and the 3 original membership plans are left untouched.
List<Member__c> members = [SELECT Id FROM Member__c WHERE Email__c LIKE '%@seed.library.test'];
List<Book__c> books = [SELECT Id FROM Book__c WHERE ISBN__c LIKE '97820%'];
delete [SELECT Id FROM Fine__c WHERE Member__c IN :members];
delete [SELECT Id FROM Reservation__c WHERE Member__c IN :members];
delete [SELECT Id FROM Borrow_Record__c WHERE Member__c IN :members];
delete [SELECT Id FROM Library_Scan_Transaction__c WHERE Member__c IN :members];
delete [SELECT Id FROM Library_Scan_Transaction__c WHERE Idempotency_Key__c LIKE 'ROOM:SEED%'];
delete [SELECT Id FROM Book_Copy__c WHERE Book__c IN :books];
delete [SELECT Id FROM Book_Author__c WHERE Book__c IN :books];
delete [SELECT Id FROM Book_Category_Link__c WHERE Book__c IN :books];
delete books;
delete members;
delete [SELECT Id FROM Membership_Plan__c WHERE Name IN ('Student', 'Platinum') AND Id NOT IN (SELECT Membership_Plan__c FROM Member__c WHERE Membership_Plan__c != null)];
