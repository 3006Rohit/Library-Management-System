// Stage 3: reviews (55), reading-list/wishlist (70), rooms (6), room bookings (23).
// All stored as Library_Scan_Transaction__c rows, matching the services' JSON payloads.
if ([SELECT COUNT() FROM Library_Scan_Transaction__c WHERE Idempotency_Key__c LIKE 'ROOM:SEED%'] > 0) {
    throw new DmlException('Stage 3 already loaded - run cleanup first.');
}
List<Member__c> members = [SELECT Id, Status__c FROM Member__c WHERE Email__c LIKE '%@seed.library.test' ORDER BY Email__c];
List<Member__c> activeMembers = new List<Member__c>();
for (Member__c mem : members) { if (mem.Status__c == 'Active') { activeMembers.add(mem); } }
List<Book__c> books = [SELECT Id FROM Book__c WHERE ISBN__c LIKE '97820%' ORDER BY ISBN__c];
Datetime now = Datetime.now();
List<Library_Scan_Transaction__c> rows = new List<Library_Scan_Transaction__c>();

// ---- Reviews ----
List<Integer> ratings = new List<Integer>{5, 4, 5, 3, 4, 5, 2, 4, 1, 4};
List<String> texts = new List<String>{
    'Gripping from the first page, I could not put it down.',
    'Well researched and clearly written. Recommended.',
    'A solid read, though the middle drags a little.',
    'Beautiful prose and memorable characters throughout.',
    'Useful ideas, but I expected more depth in places.',
    'Not for me, the pacing felt uneven and slow.',
    'Great introduction to the subject for new readers.',
    'Thoughtful and surprising, I will read it again.'
};
Set<String> seen = new Set<String>();
Integer made = 0; Integer r = 0;
while (made < 55) {
    Member__c mem = members[Math.mod(r * 3, members.size())];
    Book__c bk = books[Math.mod(r * 7 + made, books.size())];
    r++;
    String key = 'BOOK_REVIEW:' + mem.Id + ':' + bk.Id;
    if (seen.contains(key)) { continue; }
    seen.add(key);
    String rs = made < 40 ? 'Published' : (made < 50 ? 'Pending' : 'Rejected');
    rows.add(new Library_Scan_Transaction__c(
        Idempotency_Key__c = key,
        Operation__c = 'Book Review',
        Member__c = mem.Id,
        Status__c = 'Completed',
        Created_At__c = now.addDays(-Math.mod(made * 5, 120)),
        Result_Message__c = JSON.serialize(new Map<String, Object>{
            'b' => String.valueOf(bk.Id),
            'r' => ratings[Math.mod(made, ratings.size())],
            's' => rs,
            't' => texts[Math.mod(made, texts.size())]
        }).left(255)
    ));
    made++;
}

// ---- Reading list / wishlist ----
List<String> states = new List<String>{'Want to Read', 'Want to Read', 'Currently Reading', 'Completed', 'Abandoned'};
List<String> notes = new List<String>{null, 'Recommended by a friend', 'For the book club', null, 'Check sequel', 'Gift idea'};
made = 0; r = 0;
while (made < 70) {
    Member__c mem = members[Math.mod(r * 11 + 1, members.size())];
    Book__c bk = books[Math.mod(r * 5 + 3, books.size())];
    r++;
    String key = 'ENGAGEMENT:' + mem.Id + ':' + bk.Id;
    if (seen.contains(key)) { continue; }
    seen.add(key);
    String state = states[Math.mod(made, states.size())];
    rows.add(new Library_Scan_Transaction__c(
        Idempotency_Key__c = key,
        Operation__c = 'Reading List',
        Member__c = mem.Id,
        Status__c = 'Completed',
        Created_At__c = now.addDays(-Math.mod(made * 4, 150)),
        Result_Message__c = JSON.serialize(new Map<String, Object>{
            'bookId' => String.valueOf(bk.Id),
            'state' => state,
            'notes' => notes[Math.mod(made, notes.size())],
            'rating' => state == 'Completed' ? ratings[Math.mod(made, ratings.size())] : null,
            'notify' => Math.mod(made, 3) == 0
        }).left(255)
    ));
    made++;
}
insert rows;

// ---- Rooms ----
List<List<Object>> roomDefs = new List<List<Object>>{
    new List<Object>{'Quiet Study Hall', 'Ground Floor', 24, 'Wi-Fi, Power sockets', 'Shared'},
    new List<Object>{'Group Project Room A', 'First Floor', 8, 'Whiteboard, Projector', 'Shared'},
    new List<Object>{'Group Project Room B', 'First Floor', 10, 'Whiteboard, Display', 'Shared'},
    new List<Object>{'Digital Lab', 'Second Floor', 16, 'PCs, Scanner, Wi-Fi', 'Shared'},
    new List<Object>{'Focus Pod 1', 'Second Floor', 1, 'Desk lamp, Power socket', 'Private'},
    new List<Object>{'Focus Pod 2', 'Second Floor', 1, 'Desk lamp, Power socket', 'Private'}
};
List<Library_Scan_Transaction__c> rooms = new List<Library_Scan_Transaction__c>();
for (Integer i = 0; i < roomDefs.size(); i++) {
    List<Object> d = roomDefs[i];
    rooms.add(new Library_Scan_Transaction__c(
        Idempotency_Key__c = 'ROOM:SEED' + String.valueOf(100 + i).substring(1),
        Operation__c = 'Library Room',
        Status__c = 'Published',
        Created_At__c = now.addDays(-60),
        Result_Message__c = JSON.serialize(new Map<String, Object>{
            'n' => d[0], 'l' => d[1], 'c' => d[2], 'e' => d[3], 't' => d[4]
        }).left(255)
    ));
}
insert rooms;

// ---- Room bookings: 20 upcoming + 3 cancelled past, one seat per member per slot ----
List<String> purposes = new List<String>{'Exam preparation', 'Group project', 'Reading session', 'Thesis writing', 'Study circle'};
List<Library_Scan_Transaction__c> bookings = new List<Library_Scan_Transaction__c>();
for (Integer b = 0; b < 23; b++) {
    Library_Scan_Transaction__c room = rooms[Math.mod(b, rooms.size())];
    Integer cap = Integer.valueOf(((List<Object>) roomDefs[Math.mod(b, rooms.size())])[2]);
    Integer seat = 1 + Math.mod(b * 3, cap);
    Boolean past = b >= 20;
    Datetime startAt = Datetime.newInstance(Date.today().addDays(past ? -(1 + b - 20) : 1 + Math.mod(b, 14)), Time.newInstance(9 + Math.mod(b * 2, 8), 0, 0, 0));
    Datetime endAt = startAt.addHours(2);
    Member__c mem = activeMembers[Math.mod(b, activeMembers.size())];
    bookings.add(new Library_Scan_Transaction__c(
        Idempotency_Key__c = 'ROOM_BOOK:' + mem.Id + ':' + room.Id + ':' + seat + ':' + String.valueOf(startAt),
        Operation__c = 'Room Booking',
        Member__c = mem.Id,
        Status__c = past ? 'Canceled' : 'Booked',
        Created_At__c = now.addDays(past ? -8 : -Math.mod(b, 5)),
        Result_Message__c = JSON.serialize(new Map<String, Object>{
            'r' => String.valueOf(room.Id), 'k' => seat, 's' => String.valueOf(startAt), 'e' => String.valueOf(endAt), 'p' => purposes[Math.mod(b, purposes.size())]
        }).left(255)
    ));
}
insert bookings;
System.debug('SEED3 reviewsAndWishlist=' + rows.size() + ' rooms=' + rooms.size() + ' bookings=' + bookings.size());
