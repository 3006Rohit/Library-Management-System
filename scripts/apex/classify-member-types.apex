// One-time, idempotent classification of the verified existing Member__c population.
// This script updates Member_Type__c only; it does not modify operational or identity data.

Map<String, String> memberTypeById = new Map<String, String>{
    'a09gK00000QpqaHQAR' => 'Production',
    'a09gK00000QpiUnQAJ' => 'Production',
    'a09gK00000QzdzxQAB' => 'Production',
    'a09gK00000Qzg09QAB' => 'Production',
    'a09gK00000R0JuLQAV' => 'Production',
    'a09gK00000R1K0LQAV' => 'Production',
    'a09gK00000R1VgXQAV' => 'Production',
    'a09gK00000R5m65QAB' => 'Demo',
    'a09gK00000R5m66QAB' => 'Demo',
    'a09gK00000R5m67QAB' => 'Demo',
    'a09gK00000R5m68QAB' => 'Demo',
    'a09gK00000R5m69QAB' => 'Demo',
    'a09gK00000R5m6AQAR' => 'Demo',
    'a09gK00000R5m6BQAR' => 'Demo',
    'a09gK00000R5m6CQAR' => 'Demo',
    'a09gK00000R5m6DQAR' => 'Demo',
    'a09gK00000R5m6EQAR' => 'Demo',
    'a09gK00000R5T1qQAF' => 'Test',
    'a09gK00000REPJxQAP' => 'Test',
    'a09gK00000RExdNQAT' => 'Test',
    'a09gK00000RIB3tQAH' => 'Test',
    'a09gK00000RHtBpQAL' => 'UAT',
    'a09gK00000RHtBqQAL' => 'UAT',
    'a09gK00000RHtBrQAL' => 'UAT',
    'a09gK00000RHtBsQAL' => 'UAT',
    'a09gK00000RHtBtQAL' => 'UAT',
    'a09gK00000RHtBuQAL' => 'UAT',
    'a09gK00000RHtBvQAL' => 'UAT',
    'a09gK00000RHtBwQAL' => 'UAT',
    'a09gK00000RHtBxQAL' => 'UAT',
    'a09gK00000RHtByQAL' => 'UAT',
    'a09gK00000RHtBzQAL' => 'UAT',
    'a09gK00000RHtC0QAL' => 'UAT',
    'a09gK00000RHtC1QAL' => 'UAT',
    'a09gK00000RHtC2QAL' => 'UAT',
    'a09gK00000RHtC3QAL' => 'UAT',
    'a09gK00000RHtC4QAL' => 'UAT',
    'a09gK00000RHtC5QAL' => 'UAT',
    'a09gK00000RHtC6QAL' => 'UAT',
    'a09gK00000RHtC7QAL' => 'UAT',
    'a09gK00000RHtC8QAL' => 'UAT'
};

Set<Id> ids = new Set<Id>();
for (String value : memberTypeById.keySet()) ids.add((Id)value);
Map<Id, Member__c> existing = new Map<Id, Member__c>([
    SELECT Id, Name, Email__c, Member_Type__c FROM Member__c WHERE Id IN :ids
]);
System.assertEquals(memberTypeById.size(), existing.size(), 'The verified classification population changed; aborting.');

List<Member__c> updates = new List<Member__c>();
for (Id memberId : ids) updates.add(new Member__c(Id=memberId, Member_Type__c=memberTypeById.get(String.valueOf(memberId))));
update updates;
System.debug(LoggingLevel.INFO, 'Classified ' + updates.size() + ' verified members; no other fields were changed.');
