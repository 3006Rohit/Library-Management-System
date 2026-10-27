String jobName = 'Library Notification Retry Hourly';
List<CronTrigger> existing = [
  SELECT Id
  FROM CronTrigger
  WHERE CronJobDetail.Name = :jobName
  LIMIT 1
];
if (existing.isEmpty()) {
  System.schedule(
    jobName,
    '0 0 * * * ?',
    new LibraryNotificationRetryScheduler()
  );
}
