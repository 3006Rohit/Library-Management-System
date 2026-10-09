public without sharing class LibraryCirculationService {
    public static Id checkout(Id memberId, Id copyId) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Member__c member = [SELECT Id, Contact__c, Status__c, Membership_End_Date__c, Membership_Plan__c, Membership_Plan__r.Active__c, Membership_Plan__r.Borrow_Limit__c, Membership_Plan__r.Loan_Duration_Days__c FROM Member__c WHERE Id=:memberId FOR UPDATE];
        Book_Copy__c copy = [SELECT Id, Book__c, Status__c FROM Book_Copy__c WHERE Id=:copyId FOR UPDATE];
        List<Borrow_Record__c> activeLoans = [SELECT Id FROM Borrow_Record__c WHERE Member__c=:memberId AND Return_Date__c=null AND Status__c IN ('Active','Overdue') FOR UPDATE];
        Decimal outstanding = 0;
        for (Fine__c fine : [SELECT Balance__c FROM Fine__c WHERE Member__c=:memberId AND Status__c IN ('Unpaid','Partially Paid')]) outstanding += fine.Balance__c == null ? 0 : fine.Balance__c;
        Reservation__c blocking;
        List<Reservation__c> reservations = [SELECT Id, Member__c, Status__c, Book_Copy__c FROM Reservation__c WHERE Book__c=:copy.Book__c AND Status__c IN ('Pending','Ready') ORDER BY Reservation_Date__c ASC, Id ASC LIMIT 1];
        if (!reservations.isEmpty()) blocking = reservations[0];
        LibraryPolicyService.PolicyResult result = LibraryPolicyService.canBorrow(member, member.Membership_Plan__r, activeLoans.size(), outstanding, copy, blocking);
        if (!result.allowed) throw new AuraHandledException(result.message);
        if (blocking != null && blocking.Status__c == 'Ready' && blocking.Member__c == memberId && blocking.Book_Copy__c != null && blocking.Book_Copy__c != copyId) throw new AuraHandledException('This reservation is ready on a different copy.');
        Datetime now = System.now();
        Borrow_Record__c loan = new Borrow_Record__c(Member__c=member.Id, Book_Copy__c=copy.Id, Contact__c=member.Contact__c, Borrow_Date__c=now, Due_Date__c=now.addDays(Integer.valueOf(member.Membership_Plan__r.Loan_Duration_Days__c)), Status__c='Active', Renewal_Count__c=0);
        insert loan;
        update new Book_Copy__c(Id=copy.Id, Status__c='Borrowed');
        if (blocking != null && blocking.Status__c == 'Ready' && blocking.Member__c == memberId) { blocking.Status__c='Fulfilled'; blocking.Fulfilled_Date__c=now; update blocking; }
        return loan.Id;
    }

    public static void returnLoan(Id loanId) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Borrow_Record__c loan = [SELECT Id, Member__c, Book_Copy__c, Contact__c, Borrow_Date__c, Due_Date__c, Return_Date__c, Status__c, Member__r.Membership_Plan__r.Fine_Per_Day__c FROM Borrow_Record__c WHERE Id=:loanId FOR UPDATE];
        if (loan.Return_Date__c != null || loan.Status__c == 'Returned') throw new AuraHandledException('Loan has already been returned.');
        Book_Copy__c copy = [SELECT Id, Book__c, Status__c FROM Book_Copy__c WHERE Id=:loan.Book_Copy__c FOR UPDATE];
        Datetime now = System.now(); loan.Return_Date__c=now; loan.Status__c='Returned'; update new Borrow_Record__c(Id=loan.Id, Return_Date__c=now, Status__c='Returned');
        if (loan.Due_Date__c != null && now > loan.Due_Date__c && loan.Member__r.Membership_Plan__r.Fine_Per_Day__c != null) {
            Integer days = loan.Due_Date__c.date().daysBetween(now.date());
            if ([SELECT count() FROM Fine__c WHERE Borrow_Record__c=:loan.Id AND Fine_Type__c='Overdue'] == 0) insert new Fine__c(Member__c=loan.Member__c, Borrow_Record__c=loan.Id, Contact__c=loan.Contact__c, Fine_Type__c='Overdue', Amount__c=days * loan.Member__r.Membership_Plan__r.Fine_Per_Day__c, Paid_Amount__c=0, Status__c='Unpaid', Generated_Date__c=Date.today());
        }
        List<Reservation__c> pending = [SELECT Id, Member__c FROM Reservation__c WHERE Book__c=:copy.Book__c AND Status__c='Pending' ORDER BY Reservation_Date__c ASC, Id ASC LIMIT 1];
        if (pending.isEmpty()) { update new Book_Copy__c(Id=copy.Id, Status__c='Available'); }
        else { Reservation__c next = pending[0]; next.Status__c='Ready'; next.Book_Copy__c=copy.Id; next.Ready_Date__c=now; next.Expiry_Date__c=now.addDays(LibraryPolicyService.holdDurationDays()); update next; update new Book_Copy__c(Id=copy.Id, Status__c='Reserved'); }
    }

    public static void renewLoan(Id loanId) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Borrow_Record__c loan = [SELECT Id, Member__c, Due_Date__c, Status__c, Renewal_Count__c, Member__r.Status__c, Member__r.Membership_End_Date__c, Member__r.Membership_Plan__r.Renewal_Limit__c, Member__r.Membership_Plan__r.Loan_Duration_Days__c FROM Borrow_Record__c WHERE Id=:loanId FOR UPDATE];
        if (loan.Status__c != 'Active' && loan.Status__c != 'Overdue') throw new AuraHandledException('Only an active loan can be renewed.');
        if (loan.Member__r.Status__c != 'Active' || loan.Member__r.Membership_End_Date__c < Date.today()) throw new AuraHandledException('Member is not eligible for renewal.');
        if (loan.Member__r.Membership_Plan__r.Renewal_Limit__c == null || loan.Renewal_Count__c >= loan.Member__r.Membership_Plan__r.Renewal_Limit__c) throw new AuraHandledException('Renewal limit has been reached.');
        Integer blockingReservations=[SELECT count() FROM Reservation__c WHERE Book_Copy__c IN (SELECT Book_Copy__c FROM Borrow_Record__c WHERE Id=:loan.Id) AND Status__c='Pending' AND Member__c != :loan.Member__c];
        if (blockingReservations > 0) throw new AuraHandledException('A reservation from another member blocks renewal.');
        loan.Due_Date__c=loan.Due_Date__c.addDays(Integer.valueOf(loan.Member__r.Membership_Plan__r.Loan_Duration_Days__c)); loan.Renewal_Count__c=(loan.Renewal_Count__c == null ? 1 : loan.Renewal_Count__c + 1); loan.Last_Renewed_Date__c=System.now(); loan.Status__c='Active'; update new Borrow_Record__c(Id=loan.Id, Due_Date__c=loan.Due_Date__c, Renewal_Count__c=loan.Renewal_Count__c, Last_Renewed_Date__c=loan.Last_Renewed_Date__c, Status__c='Active');
    }

    public static void recordFinePayment(Id fineId, Decimal amount) {
        LibraryPolicyService.require('Manage_Library_Fines');
        if (amount == null || amount <= 0) throw new AuraHandledException('Payment must be greater than zero.');
        Fine__c fine=[SELECT Id,Amount__c,Paid_Amount__c,Status__c FROM Fine__c WHERE Id=:fineId FOR UPDATE]; Decimal paid=fine.Paid_Amount__c == null ? 0 : fine.Paid_Amount__c; Decimal balance=(fine.Amount__c == null ? 0 : fine.Amount__c)-paid; if (amount > balance) throw new AuraHandledException('Payment cannot exceed the outstanding balance.'); fine.Paid_Amount__c=paid+amount; fine.Status__c=fine.Paid_Amount__c >= fine.Amount__c ? 'Paid' : 'Partially Paid'; if (fine.Status__c == 'Paid') fine.Paid_Date__c=Date.today(); update fine;
    }

    public static void waiveFine(Id fineId, String reason) { LibraryPolicyService.require('Manage_Library_Fines'); Fine__c fine=[SELECT Id,Status__c,Notes__c FROM Fine__c WHERE Id=:fineId FOR UPDATE]; if (fine.Status__c == 'Paid' || fine.Status__c == 'Waived') throw new AuraHandledException('This fine cannot be waived.'); fine.Status__c='Waived'; fine.Notes__c=String.isBlank(reason) ? 'Waived by librarian.' : reason.trim(); update fine; }

    public static Id createReservation(Id memberId, Id bookId) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Member__c member=[SELECT Id,Contact__c,Status__c,Membership_End_Date__c,Membership_Plan__r.Active__c,Membership_Plan__r.Reservation_Limit__c FROM Member__c WHERE Id=:memberId];
        if (member.Status__c != 'Active' || member.Membership_End_Date__c < Date.today()) throw new AuraHandledException('Member is not eligible for reservations.');
        Integer activeCount=[SELECT count() FROM Reservation__c WHERE Member__c=:memberId AND Status__c IN ('Pending','Ready')];
        if (member.Membership_Plan__r.Reservation_Limit__c != null && activeCount >= member.Membership_Plan__r.Reservation_Limit__c) throw new AuraHandledException('Reservation limit has been reached.');
        if ([SELECT count() FROM Book__c WHERE Id=:bookId] == 0) throw new AuraHandledException('Book was not found.');
        if ([SELECT count() FROM Reservation__c WHERE Member__c=:memberId AND Book__c=:bookId AND Status__c IN ('Pending','Ready')] > 0) throw new AuraHandledException('Member already has an active reservation for this book.');
        Integer position=[SELECT count() FROM Reservation__c WHERE Book__c=:bookId AND Status__c IN ('Pending','Ready')]+1;
        Reservation__c reservation=new Reservation__c(Member__c=memberId,Book__c=bookId,Contact__c=member.Contact__c,Reservation_Date__c=System.now(),Status__c='Pending',Queue_Position__c=position);
        insert reservation; return reservation.Id;
    }

    public static void cancelReservation(Id reservationId) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Reservation__c reservation=[SELECT Id,Status__c FROM Reservation__c WHERE Id=:reservationId FOR UPDATE];
        if (reservation.Status__c == 'Fulfilled' || reservation.Status__c == 'Expired' || reservation.Status__c == 'Cancelled') throw new AuraHandledException('This reservation cannot be cancelled.');
        reservation.Status__c='Cancelled'; update reservation;
    }

    public static Integer processExpiredReservations() {
        LibraryPolicyService.require('Manage_Library_Circulation'); Integer processed=0;
        for (Reservation__c expired : [SELECT Id,Book__c,Book_Copy__c,Status__c FROM Reservation__c WHERE Status__c='Ready' AND Expiry_Date__c < :System.now() FOR UPDATE]) {
            expired.Status__c='Expired'; update expired; processed++;
            if (expired.Book_Copy__c != null) {
                List<Reservation__c> next=[SELECT Id FROM Reservation__c WHERE Book__c=:expired.Book__c AND Status__c='Pending' ORDER BY Reservation_Date__c ASC,Id ASC LIMIT 1];
                if (next.isEmpty()) update new Book_Copy__c(Id=expired.Book_Copy__c,Status__c='Available');
                else { Reservation__c promoted=next[0]; promoted.Status__c='Ready'; promoted.Book_Copy__c=expired.Book_Copy__c; promoted.Ready_Date__c=System.now(); promoted.Expiry_Date__c=System.now().addDays(LibraryPolicyService.holdDurationDays()); update promoted; }
            }
        }
        return processed;
    }

    public static void renewLoanForMember(Id loanId, Id memberId) {
        Borrow_Record__c loan=[SELECT Id,Member__c,Due_Date__c,Status__c,Renewal_Count__c,Member__r.Status__c,Member__r.Membership_End_Date__c,Member__r.Membership_Plan__r.Renewal_Limit__c,Member__r.Membership_Plan__r.Loan_Duration_Days__c FROM Borrow_Record__c WHERE Id=:loanId FOR UPDATE];
        if (loan.Member__c != memberId) throw new AuraHandledException('This loan does not belong to the current member.');
        if (loan.Status__c != 'Active' && loan.Status__c != 'Overdue') throw new AuraHandledException('Only an active loan can be renewed.');
        if (loan.Member__r.Status__c != 'Active' || loan.Member__r.Membership_End_Date__c < Date.today()) throw new AuraHandledException('Member is not eligible for renewal.');
        if (loan.Member__r.Membership_Plan__r.Renewal_Limit__c == null || loan.Renewal_Count__c >= loan.Member__r.Membership_Plan__r.Renewal_Limit__c) throw new AuraHandledException('Renewal limit has been reached.');
        if ([SELECT count() FROM Reservation__c WHERE Book_Copy__c IN (SELECT Book_Copy__c FROM Borrow_Record__c WHERE Id=:loan.Id) AND Status__c='Pending' AND Member__c != :loan.Member__c] > 0) throw new AuraHandledException('A reservation from another member blocks renewal.');
        loan.Due_Date__c=loan.Due_Date__c.addDays(Integer.valueOf(loan.Member__r.Membership_Plan__r.Loan_Duration_Days__c)); loan.Renewal_Count__c=(loan.Renewal_Count__c==null?1:loan.Renewal_Count__c+1); loan.Last_Renewed_Date__c=System.now(); loan.Status__c='Active'; update new Borrow_Record__c(Id=loan.Id,Due_Date__c=loan.Due_Date__c,Renewal_Count__c=loan.Renewal_Count__c,Last_Renewed_Date__c=loan.Last_Renewed_Date__c,Status__c='Active');
    }

    public static Id createReservationForMember(Id memberId, Id bookId) {
        Member__c member=[SELECT Id,Contact__c,Status__c,Membership_End_Date__c,Membership_Plan__r.Active__c,Membership_Plan__r.Reservation_Limit__c FROM Member__c WHERE Id=:memberId];
        if(member.Status__c!='Active'||member.Membership_End_Date__c<Date.today()) throw new AuraHandledException('Member is not eligible for reservations.');
        Integer activeCount=[SELECT count() FROM Reservation__c WHERE Member__c=:memberId AND Status__c IN ('Pending','Ready')]; if(member.Membership_Plan__r.Reservation_Limit__c!=null&&activeCount>=member.Membership_Plan__r.Reservation_Limit__c) throw new AuraHandledException('Reservation limit has been reached.');
        if([SELECT count() FROM Book__c WHERE Id=:bookId]==0) throw new AuraHandledException('Book was not found.'); if([SELECT count() FROM Reservation__c WHERE Member__c=:memberId AND Book__c=:bookId AND Status__c IN ('Pending','Ready')]>0) throw new AuraHandledException('Member already has an active reservation for this book.');
        Integer position=[SELECT count() FROM Reservation__c WHERE Book__c=:bookId AND Status__c IN ('Pending','Ready')]+1; Reservation__c reservation=new Reservation__c(Member__c=memberId,Book__c=bookId,Contact__c=member.Contact__c,Reservation_Date__c=System.now(),Status__c='Pending',Queue_Position__c=position); insert reservation; return reservation.Id;
    }

    public static void cancelReservationForMember(Id reservationId, Id memberId) {
        Reservation__c reservation=[SELECT Id,Member__c,Status__c,Book__c,Book_Copy__c FROM Reservation__c WHERE Id=:reservationId FOR UPDATE]; if(reservation.Member__c!=memberId) throw new AuraHandledException('This reservation does not belong to the current member.'); if(reservation.Status__c=='Fulfilled'||reservation.Status__c=='Expired'||reservation.Status__c=='Cancelled') throw new AuraHandledException('This reservation cannot be cancelled.');
        if(reservation.Status__c=='Ready'&&reservation.Book_Copy__c!=null){Id releasedCopy=reservation.Book_Copy__c;List<Reservation__c> next=[SELECT Id FROM Reservation__c WHERE Book__c=:reservation.Book__c AND Status__c='Pending' AND Id!=:reservation.Id ORDER BY Reservation_Date__c ASC,Id ASC LIMIT 1]; reservation.Status__c='Cancelled'; reservation.Book_Copy__c=null; update reservation; if(next.isEmpty()) update new Book_Copy__c(Id=releasedCopy,Status__c='Available'); else {Reservation__c promoted=next[0];promoted.Status__c='Ready';promoted.Book_Copy__c=releasedCopy;promoted.Ready_Date__c=System.now();promoted.Expiry_Date__c=System.now().addDays(LibraryPolicyService.holdDurationDays());update promoted;}} else {reservation.Status__c='Cancelled';update reservation;}
    }
    public static void reportDefectiveCopy(Id loanId, String notes) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Borrow_Record__c loan=[SELECT Id,Book_Copy__c,Status__c,Return_Date__c,Defect_Reported_Date__c,Notes__c FROM Borrow_Record__c WHERE Id=:loanId FOR UPDATE];
        if (loan.Return_Date__c != null || (loan.Status__c != 'Active' && loan.Status__c != 'Overdue')) throw new AuraHandledException('Only an active loan can be reported for replacement.');
        if (loan.Defect_Reported_Date__c != null) throw new AuraHandledException('A replacement has already been reported for this loan.');
        Book_Copy__c copy=[SELECT Id,Status__c,Condition__c FROM Book_Copy__c WHERE Id=:loan.Book_Copy__c FOR UPDATE];
        if (copy.Status__c != 'Borrowed') throw new AuraHandledException('The borrowed copy is not in a replaceable state.');
        Datetime reported=System.now(); String entry='Defective copy reported '+String.valueOf(reported)+'.'; if (!String.isBlank(notes)) entry+=' '+notes.trim();
        loan.Defect_Reported_Date__c=reported; loan.Replacement_Required__c=true; loan.Notes__c=String.isBlank(loan.Notes__c)?entry:loan.Notes__c+'\n'+entry;
        update new Book_Copy__c(Id=copy.Id,Status__c='Damaged',Condition__c='Poor'); update loan;
    }
    public static void replaceDefectiveCopy(Id loanId, Id replacementCopyId) {
        LibraryPolicyService.require('Manage_Library_Circulation');
        Borrow_Record__c loan=[SELECT Id,Book_Copy__c,Due_Date__c,Status__c,Return_Date__c,Defect_Reported_Date__c,Replacement_Required__c,Notes__c FROM Borrow_Record__c WHERE Id=:loanId FOR UPDATE];
        if (!loan.Replacement_Required__c || loan.Defect_Reported_Date__c == null) throw new AuraHandledException('Report the defective copy before assigning a replacement.');
        if (loan.Return_Date__c != null || (loan.Status__c != 'Active' && loan.Status__c != 'Overdue')) throw new AuraHandledException('Only an active loan can receive a replacement copy.');
        if (replacementCopyId == null || replacementCopyId == loan.Book_Copy__c) throw new AuraHandledException('Choose a different replacement copy.');
        Book_Copy__c oldCopy=[SELECT Id,Book__c FROM Book_Copy__c WHERE Id=:loan.Book_Copy__c FOR UPDATE]; Book_Copy__c replacement=[SELECT Id,Book__c,Status__c FROM Book_Copy__c WHERE Id=:replacementCopyId FOR UPDATE];
        if (replacement.Book__c != oldCopy.Book__c) throw new AuraHandledException('The replacement copy must belong to the same book.'); if (replacement.Status__c != 'Available') throw new AuraHandledException('The replacement copy is not available.');
        Datetime replaced=System.now(); Integer delayDays=loan.Defect_Reported_Date__c.date().daysBetween(replaced.date()); if (delayDays < 0) throw new AuraHandledException('The defect report date cannot be in the future.');
        loan.Book_Copy__c=replacement.Id; loan.Replacement_Date__c=replaced; loan.Replacement_Days__c=delayDays; loan.Replacement_Required__c=false; loan.Due_Date__c=loan.Due_Date__c == null ? null : loan.Due_Date__c.addDays(delayDays); loan.Notes__c=loan.Notes__c+'\nReplacement copy assigned '+String.valueOf(replaced)+'. Due date extended by '+String.valueOf(delayDays)+' day(s).';
        update new Book_Copy__c(Id=replacement.Id,Status__c='Borrowed'); update loan;
    }
}
