public with sharing class LibrarySettingsController {
  @AuraEnabled(cacheable=true)
  public static Library_Settings__c getSettings() {
    LibraryPolicyService.require('Manage_Library_Circulation');
    List<Library_Settings__c> settings = [
      SELECT
        Id,
        Name,
        Settings_Key__c,
        Library_Name__c,
        Contact_Email__c,
        Default_Shelf_Prefix__c,
        Reservation_Hold_Days__c,
        Due_Reminder_Days__c,
        Max_Search_Results__c,
        Send_Due_Reminders__c,
        Send_Overdue_Notices__c,
        Send_Reservation_Notifications__c,
        Allow_Self_Registration__c,
        Require_Email_Verification__c,
        Auto_Process_Expired_Holds__c,
        Fine_Payment_Enabled__c
      FROM Library_Settings__c
      WHERE Settings_Key__c = 'Default'
      LIMIT 1
    ];
    if (!settings.isEmpty())
      return settings[0];
    return new Library_Settings__c(
      Name = 'Default',
      Settings_Key__c = 'Default',
      Library_Name__c = 'Library Management',
      Default_Shelf_Prefix__c = 'Shelf',
      Reservation_Hold_Days__c = 3,
      Due_Reminder_Days__c = 3,
      Max_Search_Results__c = 200,
      Send_Due_Reminders__c = true,
      Send_Overdue_Notices__c = true,
      Send_Reservation_Notifications__c = true,
      Allow_Self_Registration__c = true,
      Require_Email_Verification__c = true,
      Auto_Process_Expired_Holds__c = true,
      Fine_Payment_Enabled__c = true
    );
  }

  @AuraEnabled
  public static Id saveSettings(
    Id settingsId,
    String libraryName,
    String contactEmail,
    String defaultShelfPrefix,
    Decimal reservationHoldDays,
    Decimal dueReminderDays,
    Decimal maxSearchResults,
    Boolean sendDueReminders,
    Boolean sendOverdueNotices,
    Boolean sendReservationNotifications,
    Boolean allowSelfRegistration,
    Boolean requireEmailVerification,
    Boolean autoProcessExpiredHolds,
    Boolean finePaymentEnabled
  ) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    if (
      String.isBlank(libraryName) ||
      reservationHoldDays == null ||
      reservationHoldDays < 1 ||
      dueReminderDays == null ||
      dueReminderDays < 0 ||
      maxSearchResults == null ||
      maxSearchResults < 10
    )
      throw new AuraHandledException(
        'Library name and valid operational limits are required.'
      );
    Library_Settings__c settings = new Library_Settings__c(
      Id = settingsId,
      Name = 'Default',
      Settings_Key__c = 'Default',
      Library_Name__c = libraryName.trim(),
      Contact_Email__c = contactEmail,
      Default_Shelf_Prefix__c = defaultShelfPrefix,
      Reservation_Hold_Days__c = reservationHoldDays,
      Due_Reminder_Days__c = dueReminderDays,
      Max_Search_Results__c = maxSearchResults,
      Send_Due_Reminders__c = sendDueReminders,
      Send_Overdue_Notices__c = sendOverdueNotices,
      Send_Reservation_Notifications__c = sendReservationNotifications,
      Allow_Self_Registration__c = allowSelfRegistration,
      Require_Email_Verification__c = requireEmailVerification,
      Auto_Process_Expired_Holds__c = autoProcessExpiredHolds,
      Fine_Payment_Enabled__c = finePaymentEnabled
    );
    Database.upsert(
      settings,
      Library_Settings__c.Settings_Key__c,
      AccessLevel.SYSTEM_MODE
    );
    return settings.Id;
  }
}
