global without sharing class LibraryNotificationRetryScheduler implements Schedulable {
  global void execute(SchedulableContext context) {
    LibraryNotificationDeliveryRetryService.processDueRetries(10);
  }
}
