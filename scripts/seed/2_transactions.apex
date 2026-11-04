// Stage 2: borrow records (200), fines (45), reservations (50) for the seeded members/copies.
if ([SELECT COUNT() FROM Borrow_Record__c WHERE Member__r.Email__c LIKE '%@seed.library.test'] > 0) {
    throw new DmlException('Stage 2 already loaded - run cleanup first.');
}
List<Member__c> members = [
    SELECT Id, Status__c, Membership_Plan__r.Loan_Duration_Days__c, Membership_Plan__r.Fine_Per_Day__c, Membership_Plan__r.Renewal_Limit__c
    FROM Member__c WHERE Email__c LIKE '%@seed.library.test' ORDER BY Email__c
];
List<Member__c> activeMembers = new List<Member__c>();
for (Member__c mem : members) { if (mem.Status__c == 'Active') { activeMembers.add(mem); } }
List<Book_Copy__c> copies = [SELECT Id, Book__c, Status__c, Price__c FROM Book_Copy__c WHERE Barcode__c LIKE 'SEED-%' ORDER BY Barcode__c];
List<Book_Copy__c> freePool = new List<Book_Copy__c>();
for (Book_Copy__c c : copies) { if (c.Status__c == 'Available') { freePool.add(c); } }
Integer pool = 0;
Datetime now = Datetime.now();

List<Borrow_Record__c> borrows = new List<Borrow_Record__c>();
List<Member__c> borrowMember = new List<Member__c>();
List<Book_Copy__c> toBorrowed = new List<Book_Copy__c>();
List<Book_Copy__c> toLost = new List<Book_Copy__c>();
for (Integer k = 0; k < 200; k++) {
    String st = 'Returned';
    if (k >= 120 && k < 165) { st = 'Active'; }
    else if (k >= 165 && k < 190) { st = 'Overdue'; }
    else if (k >= 190 && k < 193) { st = 'Lost'; }
    else if (k >= 193 && k < 197) { st = 'Pending'; }
    else if (k >= 197) { st = 'Rejected'; }
    Boolean needsOwnCopy = st == 'Active' || st == 'Overdue' || st == 'Lost';
    Member__c mem = needsOwnCopy ? activeMembers[Math.mod(k * 7, activeMembers.size())] : members[Math.mod(k * 7, members.size())];
    Integer loan = Integer.valueOf(mem.Membership_Plan__r.Loan_Duration_Days__c);
    Integer renewMax = Integer.valueOf(mem.Membership_Plan__r.Renewal_Limit__c);
    Book_Copy__c copy;
    if (needsOwnCopy) {
        copy = freePool[pool];
        pool++;
        if (st == 'Lost') { toLost.add(copy); } else { toBorrowed.add(copy); }
    } else {
        copy = copies[Math.mod(k * 13, copies.size())];
    }
    Datetime borrowDate; Datetime dueDate; Datetime returnDate = null;
    if (st == 'Returned') {
        borrowDate = now.addDays(-(15 + Math.mod(k * 3, 240)));
        dueDate = borrowDate.addDays(loan);
        returnDate = Math.mod(k, 4) == 0 ? dueDate.addDays(2 + Math.mod(k, 12)) : borrowDate.addDays(1 + Math.mod(k, loan));
    } else if (st == 'Active') {
        borrowDate = now.addDays(-Math.mod(k, Math.max(loan - 2, 1)));
        dueDate = borrowDate.addDays(loan);
    } else if (st == 'Overdue') {
        borrowDate = now.addDays(-(loan + 2 + Math.mod(k, 30)));
        dueDate = borrowDate.addDays(loan);
    } else if (st == 'Lost') {
        borrowDate = now.addDays(-(45 + Math.mod(k, 30)));
        dueDate = borrowDate.addDays(loan);
    } else {
        borrowDate = now.addDays(-Math.mod(k, 5));
        dueDate = borrowDate.addDays(loan);
    }
    Integer renewals = Math.min(Math.mod(k, 3), renewMax);
    borrows.add(new Borrow_Record__c(
        Member__c = mem.Id,
        Book_Copy__c = copy.Id,
        Borrow_Date__c = borrowDate,
        Due_Date__c = dueDate,
        Return_Date__c = returnDate,
        Status__c = st,
        Renewal_Count__c = renewals,
        Last_Renewed_Date__c = renewals > 0 ? borrowDate.addDays(loan - 1) : null,
        Notes__c = 'SEED: sample ' + st.toLowerCase() + ' loan'
    ));
    borrowMember.add(mem);
}
insert borrows;
for (Book_Copy__c c : toBorrowed) { c.Status__c = 'Borrowed'; }
for (Book_Copy__c c : toLost) { c.Status__c = 'Lost'; }
List<Book_Copy__c> copyUpdates = new List<Book_Copy__c>();
copyUpdates.addAll(toBorrowed);
copyUpdates.addAll(toLost);
update copyUpdates;

// ---- Fines (45) ----
List<String> fineStates = new List<String>{'Unpaid', 'Paid', 'Partially Paid', 'Waived'};
List<Fine__c> fines = new List<Fine__c>();
Integer lateDone = 0; Integer overdueDone = 0; Integer lostDone = 0; Integer damagedDone = 0;
for (Integer k = 0; k < borrows.size(); k++) {
    Borrow_Record__c br = borrows[k];
    Member__c mem = borrowMember[k];
    Decimal rate = mem.Membership_Plan__r.Fine_Per_Day__c;
    String fType = null; Decimal amount = 0; String fStatus = fineStates[Math.mod(k, 4)]; Date generated = Date.today();
    if (br.Status__c == 'Returned' && Math.mod(k, 4) == 0 && lateDone < 25) {
        Integer lateDays = br.Return_Date__c > br.Due_Date__c ? Integer.valueOf((br.Return_Date__c.getTime() - br.Due_Date__c.getTime()) / 86400000) : 1;
        fType = 'Overdue'; amount = Math.max(lateDays, 1) * rate; generated = br.Return_Date__c.date(); lateDone++;
    } else if (br.Status__c == 'Overdue' && overdueDone < 12) {
        Integer days = Integer.valueOf((now.getTime() - br.Due_Date__c.getTime()) / 86400000);
        fType = 'Overdue'; amount = Math.max(days, 1) * rate; fStatus = 'Unpaid'; overdueDone++;
    } else if (br.Status__c == 'Lost' && lostDone < 3) {
        fType = 'Lost Book'; amount = 500; fStatus = lostDone == 0 ? 'Paid' : 'Unpaid'; generated = br.Due_Date__c.date(); lostDone++;
    } else if (br.Status__c == 'Returned' && Math.mod(k, 4) != 0 && Math.mod(k, 9) == 1 && damagedDone < 5) {
        fType = 'Damaged Book'; amount = 250; generated = br.Return_Date__c.date(); damagedDone++;
    }
    if (fType == null) { continue; }
    Decimal paid = 0; Date paidDate = null;
    if (fStatus == 'Paid') { paid = amount; paidDate = generated.addDays(3); }
    else if (fStatus == 'Partially Paid') { paid = (amount / 2).setScale(0); paidDate = generated.addDays(5); }
    fines.add(new Fine__c(
        Member__c = mem.Id,
        Borrow_Record__c = br.Id,
        Fine_Type__c = fType,
        Amount__c = amount,
        Paid_Amount__c = paid,
        Paid_Date__c = paidDate,
        Status__c = fStatus,
        Generated_Date__c = generated,
        Notes__c = 'SEED: ' + fType.toLowerCase() + ' fine'
    ));
}
insert fines;

// ---- Reservations (50) ----
List<Book__c> books = [SELECT Id FROM Book__c WHERE ISBN__c LIKE '97820%' ORDER BY ISBN__c];
List<Book_Copy__c> readyPool = new List<Book_Copy__c>();
for (Book_Copy__c c : copies) { if (c.Status__c == 'Available') { readyPool.add(c); } }
Integer rp = pool;
List<Reservation__c> reservations = new List<Reservation__c>();
List<Book_Copy__c> reserveCopies = new List<Book_Copy__c>();
Map<Id, Integer> queue = new Map<Id, Integer>();
List<String> etaConf = new List<String>{'High', 'Medium', 'Low'};
for (Integer r = 0; r < 50; r++) {
    String st = 'Pending';
    if (r >= 20 && r < 28) { st = 'Ready'; }
    else if (r >= 28 && r < 38) { st = 'Fulfilled'; }
    else if (r >= 38 && r < 44) { st = 'Cancelled'; }
    else if (r >= 44) { st = 'Expired'; }
    Member__c mem = activeMembers[Math.mod(r * 5 + 2, activeMembers.size())];
    Book__c bk = books[Math.mod(r * 3, books.size())];
    Datetime resDate = now.addDays(-Math.mod(r * 3, 30));
    Reservation__c res = new Reservation__c(Member__c = mem.Id, Book__c = bk.Id, Status__c = st, Reservation_Date__c = resDate);
    if (st == 'Pending') {
        Integer pos = queue.containsKey(bk.Id) ? queue.get(bk.Id) + 1 : 1;
        queue.put(bk.Id, pos);
        res.Queue_Position__c = pos;
        res.Expiry_Date__c = resDate.addDays(30);
        res.ETA_Confidence__c = etaConf[Math.mod(r, 3)];
        res.ETA_Reason__c = 'Estimated from current due dates';
        res.ETA_Last_Calculated__c = now;
        res.Estimated_Available_Date__c = now.addDays(5 + Math.mod(r, 20));
    } else if (st == 'Ready') {
        // readyPool shares freePool's order, so skip the first `pool` copies already lent out.
        Book_Copy__c held = readyPool[pool + (r - 20)];
        res.Book__c = held.Book__c;
        res.Book_Copy__c = held.Id;
        res.Ready_Date__c = now.addDays(-1);
        res.Expiry_Date__c = now.addDays(2);
        held.Status__c = 'Reserved';
        reserveCopies.add(held);
    } else if (st == 'Fulfilled') {
        res.Ready_Date__c = resDate.addDays(4);
        res.Fulfilled_Date__c = resDate.addDays(5);
        res.Expiry_Date__c = resDate.addDays(7);
    } else if (st == 'Expired') {
        res.Ready_Date__c = resDate.addDays(-12);
        res.Expiry_Date__c = now.addDays(-3);
    } else {
        res.Expiry_Date__c = resDate.addDays(30);
    }
    reservations.add(res);
}
insert reservations;
update reserveCopies;
System.debug('SEED2 borrows=' + borrows.size() + ' fines=' + fines.size() + ' reservations=' + reservations.size() + ' reservedCopies=' + reserveCopies.size());
