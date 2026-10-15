Messaging.reserveSingleEmailCapacity(1);

User recipient = [
    SELECT Email
    FROM User
    WHERE Id = :UserInfo.getUserId()
    LIMIT 1
];

Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
message.setToAddresses(new List<String>{ recipient.Email });
message.setSubject('Library production email delivery verification');
message.setPlainTextBody(
    'Salesforce accepted this production email verification at ' +
    String.valueOf(System.now()) +
    '. No action is required.'
);
message.setSaveAsActivity(false);

Messaging.SendEmailResult result = Messaging.sendEmail(
    new List<Messaging.SingleEmailMessage>{ message },
    false
)[0];

System.assert(result.isSuccess(), 'Email send was rejected: ' + result.getErrors());
System.debug(LoggingLevel.INFO, 'EMAIL_DELIVERY_ACCEPTED recipient=' + recipient.Email);
