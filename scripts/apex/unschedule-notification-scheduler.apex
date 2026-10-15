List<CronTrigger> jobs = [
    SELECT Id, CronExpression, State
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Library Member Notification Scheduler'
        AND State IN ('WAITING', 'ACQUIRED', 'PAUSED', 'BLOCKED', 'PAUSED_BLOCKED')
];
System.assert(jobs.size() <= 1, 'Refusing to unschedule duplicate notification jobs.');
if (!jobs.isEmpty()) {
    System.assertEquals('0 15 * * * ?', jobs[0].CronExpression, 'The notification schedule changed unexpectedly.');
    System.abortJob(jobs[0].Id);
}
