# Notifications

## Pipeline

```
Event (due soon, overdue, reservation ready, etc.)  or  LibraryNotificationScheduler (hourly :15)
  → LibraryMemberNotificationService.create/createAll        (Member_Notification__c, dedup by Dedup_Key__c)
      → LibraryNotificationPreferenceService.shouldDeliver   (channel × type × quiet hours)
      → Notification_Delivery__c rows, one per channel
          In-App → marked Delivered immediately
          Email  → Pending → LibraryNotificationEmailQueueable → Sent / Failed
          Disabled channel or missing address → Skipped (categorical reason)
Failed e-mail → LibraryNotificationDeliveryRetryService (bounded retries, backoff Next_Attempt_At__c)
              ← LibraryNotificationRetryScheduler (hourly job "Library Notification Retry Hourly")
                or librarian action "Retry failed deliveries"
```

## Key behaviours

- **Idempotent** per notification/channel (`Idempotency_Key__c`); duplicates collapse via `Dedup_Key__c`.
- **Retries** claim eligible rows under lock, so a scheduler and a librarian cannot double-send; attempts capped by `Max_Attempts__c`; exhausted rows stay Failed for review.
- **Preferences:** member Notifications tab saves matrix (`saveForMember`), digest cadence, quiet hours, timezone; e-mail is enforced **server-side**; in-app always available.
- **Scheduler content:** loans due within 3 days and overdue loans (`LibraryNotificationScheduler`); settings toggles in `Library_Settings__c` (`Send_Due_Reminders__c`, `Send_Overdue_Notices__c`, `Send_Reservation_Notifications__c`, `Due_Reminder_Days__c`).
- **Book alerts:** `notifyActiveMembersForBook` informs members who asked to be notified when a title becomes available.
- **Reports panel:** `LibraryNotificationDeliveryService.getSummary()` (pending/sent/delivered/failed/skipped counts) and `getRecent()` — no message bodies.

## Ops

- Scheduled jobs: `Library Member Notification Scheduler` (cron `0 15 * * * ?`) is paused/restored automatically by `deploy-library.ps1`. Retry job is created by `scripts/apex/schedule_notification_retry.apex`.
- E-mail sanity test: `scripts/apex/verify-email-delivery.apex`.

## UI

Member inbox: `libraryMemberNotifications` (and shell tab). Librarian: Reports panel inside `libraryLibrarianWorkspace`.

## Tests

`LibraryNotificationDeliveryServiceTest`, `LibraryNotificationPreferenceServiceTest`; Jest `libraryMemberNotifications`.
