List<CronTrigger> jobs = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Library Member Notification Scheduler'
        AND State IN ('WAITING', 'ACQUIRED', 'PAUSED', 'BLOCKED', 'PAUSED_BLOCKED')
];
System.assert(jobs.isEmpty(), 'The notification scheduler was already restored.');
System.schedule(
    'Library Member Notification Scheduler',
    '0 15 * * * ?',
    new LibraryNotificationScheduler()
);
