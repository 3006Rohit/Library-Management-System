global without sharing class LibraryExecutiveSummaryScheduler implements Schedulable {
  global void execute(SchedulableContext context) {
    LibraryExecutiveSummaryService.generate();
  }
}
