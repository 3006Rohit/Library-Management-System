// Stage 1: books (70), authors/category links, copies (170), members (50).
// Marker: ISBN 97820*, barcode SEED-*, member email *@seed.library.test
if ([SELECT COUNT() FROM Book__c WHERE ISBN__c LIKE '97820%'] > 0) {
    throw new DmlException('Seed data already present - run cleanup first.');
}

List<Membership_Plan__c> plans = [SELECT Id, Name, Borrow_Limit__c FROM Membership_Plan__c WHERE Active__c = true AND Name IN ('Basic', 'Standard', 'Premium') ORDER BY Name];
List<Author__c> authors = [SELECT Id FROM Author__c ORDER BY Name LIMIT 40];
List<Book_Category__c> cats = [SELECT Id, Name FROM Book_Category__c ORDER BY Name];

// ---- Books ----
List<String> adjs = new List<String>{'Silent', 'Broken', 'Golden', 'Hidden', 'Distant', 'Electric', 'Forgotten', 'Crimson', 'Wandering', 'Midnight'};
List<String> nouns = new List<String>{'Harbor', 'Algorithm', 'Orchard', 'Frontier', 'Compass', 'Archive', 'Meridian'};
List<String> publishers = new List<String>{'Northwind Press', 'Lumen Books', 'Harbor & Pine', 'Blue Lantern', 'Orbit House', 'Cedar Row'};
List<Book__c> books = new List<Book__c>();
Integer i = 0;
for (String noun : nouns) {
    for (String adj : adjs) {
        String lang = Math.mod(i, 9) == 0 ? 'Hindi' : (Math.mod(i, 23) == 5 ? 'Other' : 'English');
        Book_Category__c c = cats[Math.mod(i, cats.size())];
        books.add(new Book__c(
            Name = adj + ' ' + noun,
            ISBN__c = '9782000' + String.valueOf(100000 + i).substring(1),
            Publisher__c = publishers[Math.mod(i, publishers.size())],
            Publication_Year__c = 1990 + Math.mod(i * 7, 35),
            Edition__c = Math.mod(i, 4) == 0 ? '2nd' : '1st',
            Language__c = lang,
            Status__c = 'Active',
            Description__c = 'A ' + c.Name.toLowerCase() + ' title: ' + adj.toLowerCase() + ' ' + noun.toLowerCase() + ' for curious readers.'
        ));
        i++;
    }
}
insert books;

List<Book_Author__c> bookAuthors = new List<Book_Author__c>();
List<Book_Category_Link__c> catLinks = new List<Book_Category_Link__c>();
for (Integer b = 0; b < books.size(); b++) {
    Author__c a1 = authors[Math.mod(b, authors.size())];
    bookAuthors.add(new Book_Author__c(Book__c = books[b].Id, Author__c = a1.Id, Author_Order__c = 1, Book_Author_Key__c = books[b].Id + ':' + a1.Id));
    if (Math.mod(b, 5) == 0) {
        Author__c a2 = authors[Math.mod(b + 17, authors.size())];
        bookAuthors.add(new Book_Author__c(Book__c = books[b].Id, Author__c = a2.Id, Author_Order__c = 2, Book_Author_Key__c = books[b].Id + ':' + a2.Id));
    }
    Book_Category_Link__c l1 = new Book_Category_Link__c(Book__c = books[b].Id, Book_Category__c = cats[Math.mod(b, cats.size())].Id);
    l1.Book_Category_Key__c = l1.Book__c + ':' + l1.Book_Category__c;
    catLinks.add(l1);
    if (Math.mod(b, 4) == 0) {
        Book_Category_Link__c l2 = new Book_Category_Link__c(Book__c = books[b].Id, Book_Category__c = cats[Math.mod(b + 5, cats.size())].Id);
        l2.Book_Category_Key__c = l2.Book__c + ':' + l2.Book_Category__c;
        catLinks.add(l2);
    }
}
insert bookAuthors;
insert catLinks;

// ---- Copies (170) ----
List<String> conditions = new List<String>{'New', 'Good', 'Good', 'Fair', 'Good', 'Poor'};
List<Book_Copy__c> copies = new List<Book_Copy__c>();
Map<Integer, Integer> perBook = new Map<Integer, Integer>();
for (Integer j = 0; j < 170; j++) {
    Integer bi = Math.mod(j, books.size());
    Integer n = perBook.containsKey(bi) ? perBook.get(bi) + 1 : 1;
    perBook.put(bi, n);
    String status = 'Available';
    if (Math.mod(j, 57) == 5) { status = 'Damaged'; }
    else if (Math.mod(j, 61) == 7) { status = 'Maintenance'; }
    else if (Math.mod(j, 83) == 11) { status = 'Retired'; }
    copies.add(new Book_Copy__c(
        Book__c = books[bi].Id,
        Barcode__c = 'SEED-' + String.valueOf(1000 + bi).substring(1) + '-' + String.valueOf(100 + n).substring(1),
        Shelf_Location__c = 'S-' + String.valueOf(Math.mod(bi, 12) + 1) + '-' + String.valueOf(Math.mod(j, 8) + 1),
        Condition__c = status == 'Damaged' ? 'Poor' : conditions[Math.mod(j, conditions.size())],
        Price__c = 150 + Math.mod(j * 37, 850),
        Acquisition_Date__c = Date.today().addDays(-Math.mod(j * 11, 900)),
        Status__c = status
    ));
}
insert copies;

// ---- Members (50) ----
List<String> firsts = new List<String>{'Aarav', 'Isha', 'Kabir', 'Meera', 'Rohan', 'Sana', 'Vikram', 'Anaya', 'Dev', 'Nisha'};
List<String> lasts = new List<String>{'Sharma', 'Iyer', 'Khan', 'Patel', 'Nair'};
List<String> interests = new List<String>{'Fiction', 'Science', 'History', 'Technology', 'Fantasy', 'Business', 'Mystery', 'Philosophy'};
List<Member__c> members = new List<Member__c>();
Integer m = 0;
for (String last : lasts) {
    for (String first : firsts) {
        Membership_Plan__c plan = plans[Math.mod(m, plans.size())];
        Date start = Date.today().addDays(-(30 + Math.mod(m * 13, 330)));
        String status = 'Active';
        String acct = 'Active';
        Date endDate = start.addDays(365);
        if (Math.mod(m, 17) == 3) { status = 'Suspended'; acct = 'Suspended'; }
        else if (Math.mod(m, 19) == 4) { status = 'Expired'; acct = 'Inactive'; start = Date.today().addDays(-500); endDate = Date.today().addDays(-135); }
        String email = 'seed.member' + String.valueOf(100 + m).substring(1) + '@seed.library.test';
        members.add(new Member__c(
            First_Name__c = first,
            Last_Name__c = last,
            Email__c = email,
            Normalized_Email__c = email,
            Phone__c = '+91 90000 ' + String.valueOf(10000 + m * 37).substring(1),
            Date_of_Birth__c = Date.newInstance(1960 + Math.mod(m * 3, 45), 1 + Math.mod(m, 12), 1 + Math.mod(m, 27)),
            Address__c = (10 + m) + ' Library Lane, Pune, India',
            Membership_Plan__c = plan.Id,
            Membership_Start_Date__c = start,
            Membership_End_Date__c = endDate,
            Registration_Date__c = start,
            Max_Borrow_Limit__c = plan.Borrow_Limit__c,
            Status__c = status,
            Account_Status__c = acct,
            Email_Verified__c = true,
            Member_Type__c = 'Demo',
            Interests__c = interests[Math.mod(m, interests.size())] + ', ' + interests[Math.mod(m + 3, interests.size())]
        ));
        m++;
    }
}
insert members;
System.debug('SEED1 books=' + books.size() + ' copies=' + copies.size() + ' members=' + members.size() + ' plans=' + plans.size());
