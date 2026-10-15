// Adds a coherent, idempotent demo cohort to the connected library org.
// Re-running the script is safe: it exits without inserting duplicates when any
// member from this cohort already exists.

List<String> emails = new List<String>{
    'aarav.sharma.demo@example.com',
    'meera.iyer.demo@example.com',
    'kabir.khan.demo@example.com',
    'ananya.reddy.demo@example.com',
    'ishaan.patel.demo@example.com',
    'priya.nair.demo@example.com',
    'rohan.das.demo@example.com',
    'kavya.joshi.demo@example.com',
    'vihaan.mehta.demo@example.com',
    'sana.qureshi.demo@example.com'
};

Integer existingDemoMembers = [
    SELECT COUNT()
    FROM Member__c
    WHERE Email__c IN :emails
];
if (existingDemoMembers > 0) {
    System.debug(LoggingLevel.WARN,
        'Demo cohort was not inserted because ' + existingDemoMembers +
        ' matching member(s) already exist.');
} else {
    Map<String, Membership_Plan__c> plansByName = new Map<String, Membership_Plan__c>();
    for (Membership_Plan__c plan : [
        SELECT Id, Name, Borrow_Limit__c
        FROM Membership_Plan__c
        WHERE Active__c = TRUE AND Name IN ('Basic', 'Standard', 'Premium')
    ]) {
        plansByName.put(plan.Name, plan);
    }
    System.assertEquals(3, plansByName.size(),
        'Basic, Standard, and Premium membership plans must exist and be active.');

    List<Book_Copy__c> availableCopies = [
        SELECT Id, Book__c, Status__c
        FROM Book_Copy__c
        WHERE Status__c = 'Available' AND Book__r.Status__c = 'Active'
        ORDER BY Name
        LIMIT 20
    ];
    System.assert(availableCopies.size() >= 16,
        'At least 16 available copies are required for this demo cohort.');

    Date today = Date.today();
    Datetime nowValue = System.now();
    List<String> firstNames = new List<String>{
        'Aarav', 'Meera', 'Kabir', 'Ananya', 'Ishaan',
        'Priya', 'Rohan', 'Kavya', 'Vihaan', 'Sana'
    };
    List<String> lastNames = new List<String>{
        'Sharma', 'Iyer', 'Khan', 'Reddy', 'Patel',
        'Nair', 'Das', 'Joshi', 'Mehta', 'Qureshi'
    };
    List<String> planNames = new List<String>{
        'Basic', 'Standard', 'Premium', 'Basic', 'Standard',
        'Premium', 'Basic', 'Standard', 'Premium', 'Standard'
    };
    List<String> memberStatuses = new List<String>{
        'Active', 'Active', 'Active', 'Active', 'Active',
        'Active', 'Suspended', 'Active', 'Active', 'Expired'
    };
    List<String> accountStatuses = new List<String>{
        'Active', 'Active', 'Active', 'Active', 'Active',
        'Active', 'Suspended', 'Active', 'Active', 'Inactive'
    };
    List<String> interests = new List<String>{
        'Fiction;History', 'Biography;Travel', 'Science;Technology',
        'Mystery;Fiction', 'Business;Finance', 'Science Fiction;Technology',
        'History;Politics', 'Literature;Poetry', 'Technology;Business',
        'Art;Biography'
    };

    List<Member__c> members = new List<Member__c>();
    for (Integer i = 0; i < 10; i++) {
        Membership_Plan__c selectedPlan = plansByName.get(planNames[i]);
        Boolean isExpired = memberStatuses[i] == 'Expired';
        members.add(new Member__c(
            First_Name__c = firstNames[i],
            Last_Name__c = lastNames[i],
            Email__c = emails[i],
            Normalized_Email__c = emails[i],
            Phone__c = '+91 90000 ' + String.valueOf(11001 + i),
            Date_of_Birth__c = today.addYears(-(22 + i)).addDays(i * 19),
            Address__c = (101 + i) + ', Demo Library Lane, Bengaluru, Karnataka',
            Membership_Plan__c = selectedPlan.Id,
            Membership_Start_Date__c = isExpired ? today.addYears(-1).addMonths(-2) : today.addMonths(-(i + 1)),
            Membership_End_Date__c = isExpired ? today.addDays(-20) : today.addYears(1).addMonths(-(i + 1)),
            Registration_Date__c = today.addMonths(-(i + 1)),
            Status__c = memberStatuses[i],
            Account_Status__c = accountStatuses[i],
            Member_Type__c = 'Demo',
            Max_Borrow_Limit__c = selectedPlan.Borrow_Limit__c,
            Interests__c = interests[i]
        ));
    }
    insert members;

    // Borrowing history: returned, active, overdue, and lost records.
    List<Borrow_Record__c> borrows = new List<Borrow_Record__c>{
        new Borrow_Record__c(Member__c=members[0].Id, Book_Copy__c=availableCopies[0].Id, Borrow_Date__c=nowValue.addDays(-40), Due_Date__c=nowValue.addDays(-33), Return_Date__c=nowValue.addDays(-35), Status__c='Returned', Renewal_Count__c=0, Notes__c='Returned early in good condition.'),
        new Borrow_Record__c(Member__c=members[1].Id, Book_Copy__c=availableCopies[1].Id, Borrow_Date__c=nowValue.addDays(-5), Due_Date__c=nowValue.addDays(9), Status__c='Active', Renewal_Count__c=0, Notes__c='Current standard-plan loan.'),
        new Borrow_Record__c(Member__c=members[2].Id, Book_Copy__c=availableCopies[3].Id, Borrow_Date__c=nowValue.addDays(-35), Due_Date__c=nowValue.addDays(-14), Status__c='Overdue', Renewal_Count__c=1, Last_Renewed_Date__c=nowValue.addDays(-20), Notes__c='Overdue after one renewal.'),
        new Borrow_Record__c(Member__c=members[3].Id, Book_Copy__c=availableCopies[4].Id, Borrow_Date__c=nowValue.addDays(-55), Due_Date__c=nowValue.addDays(-48), Return_Date__c=nowValue.addDays(-44), Status__c='Returned', Renewal_Count__c=0, Notes__c='Returned four days late.'),
        new Borrow_Record__c(Member__c=members[4].Id, Book_Copy__c=availableCopies[5].Id, Borrow_Date__c=nowValue.addDays(-60), Due_Date__c=nowValue.addDays(-46), Status__c='Lost', Renewal_Count__c=0, Notes__c='Member reported the copy lost.'),
        new Borrow_Record__c(Member__c=members[5].Id, Book_Copy__c=availableCopies[6].Id, Borrow_Date__c=nowValue.addDays(-8), Due_Date__c=nowValue.addDays(13), Status__c='Active', Renewal_Count__c=0, Notes__c='First current premium-plan loan.'),
        new Borrow_Record__c(Member__c=members[5].Id, Book_Copy__c=availableCopies[7].Id, Borrow_Date__c=nowValue.addDays(-3), Due_Date__c=nowValue.addDays(18), Status__c='Active', Renewal_Count__c=0, Notes__c='Second current premium-plan loan.'),
        new Borrow_Record__c(Member__c=members[6].Id, Book_Copy__c=availableCopies[8].Id, Borrow_Date__c=nowValue.addDays(-75), Due_Date__c=nowValue.addDays(-68), Return_Date__c=nowValue.addDays(-69), Status__c='Returned', Renewal_Count__c=0, Notes__c='Completed loan before account suspension.'),
        new Borrow_Record__c(Member__c=members[7].Id, Book_Copy__c=availableCopies[9].Id, Borrow_Date__c=nowValue.addDays(-24), Due_Date__c=nowValue.addDays(-10), Status__c='Overdue', Renewal_Count__c=0, Notes__c='Overdue standard-plan loan.'),
        new Borrow_Record__c(Member__c=members[8].Id, Book_Copy__c=availableCopies[11].Id, Borrow_Date__c=nowValue.addDays(-80), Due_Date__c=nowValue.addDays(-59), Return_Date__c=nowValue.addDays(-62), Status__c='Returned', Renewal_Count__c=1, Last_Renewed_Date__c=nowValue.addDays(-70), Notes__c='Historical renewed loan.'),
        new Borrow_Record__c(Member__c=members[8].Id, Book_Copy__c=availableCopies[12].Id, Borrow_Date__c=nowValue.addDays(-2), Due_Date__c=nowValue.addDays(19), Status__c='Active', Renewal_Count__c=0, Notes__c='Current premium-plan loan.'),
        new Borrow_Record__c(Member__c=members[9].Id, Book_Copy__c=availableCopies[13].Id, Borrow_Date__c=nowValue.addDays(-100), Due_Date__c=nowValue.addDays(-86), Return_Date__c=nowValue.addDays(-83), Status__c='Returned', Renewal_Count__c=0, Notes__c='Returned with minor cover damage.')
    };
    insert borrows;

    // Pending, ready, fulfilled, cancelled, and expired reservation examples.
    List<Reservation__c> reservations = new List<Reservation__c>{
        new Reservation__c(Member__c=members[0].Id, Book__c=availableCopies[14].Book__c, Reservation_Date__c=nowValue.addDays(-2), Expiry_Date__c=nowValue.addDays(5), Queue_Position__c=1, Status__c='Pending'),
        new Reservation__c(Member__c=members[1].Id, Book__c=availableCopies[2].Book__c, Book_Copy__c=availableCopies[2].Id, Reservation_Date__c=nowValue.addDays(-4), Ready_Date__c=nowValue.addDays(-1), Expiry_Date__c=nowValue.addDays(2), Queue_Position__c=1, Status__c='Ready'),
        new Reservation__c(Member__c=members[2].Id, Book__c=availableCopies[15].Book__c, Reservation_Date__c=nowValue.addDays(-1), Expiry_Date__c=nowValue.addDays(6), Queue_Position__c=2, Status__c='Pending'),
        new Reservation__c(Member__c=members[3].Id, Book__c=availableCopies[4].Book__c, Reservation_Date__c=nowValue.addDays(-60), Ready_Date__c=nowValue.addDays(-58), Fulfilled_Date__c=nowValue.addDays(-55), Expiry_Date__c=nowValue.addDays(-55), Queue_Position__c=1, Status__c='Fulfilled'),
        new Reservation__c(Member__c=members[4].Id, Book__c=availableCopies[16].Book__c, Reservation_Date__c=nowValue.addDays(-18), Expiry_Date__c=nowValue.addDays(-11), Queue_Position__c=1, Status__c='Cancelled'),
        new Reservation__c(Member__c=members[5].Id, Book__c=availableCopies[17].Book__c, Reservation_Date__c=nowValue.addDays(-3), Expiry_Date__c=nowValue.addDays(4), Queue_Position__c=1, Status__c='Pending'),
        new Reservation__c(Member__c=members[6].Id, Book__c=availableCopies[18].Book__c, Reservation_Date__c=nowValue.addDays(-30), Expiry_Date__c=nowValue.addDays(-23), Queue_Position__c=1, Status__c='Expired'),
        new Reservation__c(Member__c=members[7].Id, Book__c=availableCopies[10].Book__c, Book_Copy__c=availableCopies[10].Id, Reservation_Date__c=nowValue.addDays(-3), Ready_Date__c=nowValue.addHours(-8), Expiry_Date__c=nowValue.addDays(3), Queue_Position__c=1, Status__c='Ready'),
        new Reservation__c(Member__c=members[8].Id, Book__c=availableCopies[11].Book__c, Reservation_Date__c=nowValue.addDays(-85), Ready_Date__c=nowValue.addDays(-82), Fulfilled_Date__c=nowValue.addDays(-80), Expiry_Date__c=nowValue.addDays(-79), Queue_Position__c=1, Status__c='Fulfilled'),
        new Reservation__c(Member__c=members[9].Id, Book__c=availableCopies[19].Book__c, Reservation_Date__c=nowValue.addDays(-45), Expiry_Date__c=nowValue.addDays(-38), Queue_Position__c=1, Status__c='Cancelled')
    };
    insert reservations;

    // Six members have fine histories spanning every payment state.
    insert new List<Fine__c>{
        new Fine__c(Member__c=members[2].Id, Borrow_Record__c=borrows[2].Id, Fine_Type__c='Overdue', Amount__c=280, Paid_Amount__c=0, Status__c='Unpaid', Generated_Date__c=today.addDays(-12), Notes__c='Fourteen overdue days at the premium daily rate.'),
        new Fine__c(Member__c=members[3].Id, Borrow_Record__c=borrows[3].Id, Fine_Type__c='Overdue', Amount__c=80, Paid_Amount__c=80, Status__c='Paid', Generated_Date__c=today.addDays(-44), Paid_Date__c=today.addDays(-40), Notes__c='Late-return fine settled in full.'),
        new Fine__c(Member__c=members[4].Id, Borrow_Record__c=borrows[4].Id, Fine_Type__c='Lost Book', Amount__c=900, Paid_Amount__c=300, Status__c='Partially Paid', Generated_Date__c=today.addDays(-30), Paid_Date__c=today.addDays(-7), Notes__c='Partial replacement payment received.'),
        new Fine__c(Member__c=members[6].Id, Borrow_Record__c=borrows[7].Id, Fine_Type__c='Other', Amount__c=50, Paid_Amount__c=0, Status__c='Waived', Generated_Date__c=today.addDays(-68), Notes__c='Administrative charge waived by librarian.'),
        new Fine__c(Member__c=members[7].Id, Borrow_Record__c=borrows[8].Id, Fine_Type__c='Overdue', Amount__c=200, Paid_Amount__c=0, Status__c='Unpaid', Generated_Date__c=today.addDays(-8), Notes__c='Outstanding overdue fine.'),
        new Fine__c(Member__c=members[9].Id, Borrow_Record__c=borrows[11].Id, Fine_Type__c='Damaged Book', Amount__c=350, Paid_Amount__c=350, Status__c='Paid', Generated_Date__c=today.addDays(-82), Paid_Date__c=today.addDays(-75), Notes__c='Minor cover damage charge paid.')
    };

    // Keep physical-copy availability aligned with live circulation records.
    for (Integer copyIndex : new List<Integer>{1, 3, 6, 7, 9, 12}) {
        availableCopies[copyIndex].Status__c = 'Borrowed';
    }
    availableCopies[5].Status__c = 'Lost';
    availableCopies[2].Status__c = 'Reserved';
    availableCopies[10].Status__c = 'Reserved';
    update availableCopies;

    System.debug(LoggingLevel.INFO,
        'Inserted 10 members, 12 borrow records, 10 reservations, and 6 fines.');
}
