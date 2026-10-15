global without sharing class LibraryNotificationScheduler implements Schedulable {
  global void execute(SchedulableContext context) {
    Date today = Date.today();
    Date soon = today.addDays(3);
    List<LibraryMemberNotificationService.NotificationInput> inputs = new List<LibraryMemberNotificationService.NotificationInput>();
    for (Borrow_Record__c loan : [
      SELECT
        Id,
        Member__c,
        Due_Date__c,
        Member__r.Email__c,
        Member__r.First_Name__c
      FROM Borrow_Record__c
      WHERE
        Return_Date__c = NULL
        AND Due_Date__c != NULL
        AND Due_Date__c <= :soon
      ORDER BY Due_Date__c, Id
      LIMIT 500
    ]) {
      Boolean overdue = loan.Due_Date__c < today;
      String type = overdue ? 'Overdue Loan' : 'Due Date';
      String subject = overdue
        ? 'Overdue library loan'
        : 'Library loan due soon';
      String message =
        'Hello ' +
        loan.Member__r.First_Name__c +
        ', your library loan is ' +
        (overdue
          ? 'overdue.'
          : 'due on ' + String.valueOf(loan.Due_Date__c) + '.');
      inputs.add(
        new LibraryMemberNotificationService.NotificationInput(
          loan.Member__c,
          type,
          subject,
          message,
          loan.Id,
          type + '-' + String.valueOf(loan.Id) + '-' + String.valueOf(today),
          loan.Member__r.Email__c
        )
      );
    }
    for (Fine__c fine : [
      SELECT Id, Member__c, Amount__c, Member__r.Email__c
      FROM Fine__c
      WHERE Status__c = 'Unpaid' AND Generated_Date__c = :today
      ORDER BY Id
      LIMIT 500
    ]) {
      inputs.add(
        new LibraryMemberNotificationService.NotificationInput(
          fine.Member__c,
          'Fine Created',
          'A library fine was created',
          'A fine of ' +
            String.valueOf(fine.Amount__c) +
            ' was created on your account.',
          fine.Id,
          'FINE-' + String.valueOf(fine.Id),
          fine.Member__r.Email__c
        )
      );
    }
    LibraryMemberNotificationService.createAll(inputs);
  }
}
