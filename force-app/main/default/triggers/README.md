# `triggers/` — Apex triggers

Seven thin triggers. Each one only delegates to a service class (no logic inline), so behaviour is unit-testable.

| Trigger                            | Object / events                                          | Delegates to                                         | Why it exists                                                                                                                                                                                             |
| ---------------------------------- | -------------------------------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BookCopyInventoryTrigger`         | `Book_Copy__c` after insert / update / delete / undelete | `LibraryBookInventoryService.recalculate(bookIds)`   | Recomputes `Book__c.Total_Copies__c` and `Available_Copies__c` (copies with status `Available`). Collects book Ids from both `Trigger.new` and `Trigger.old` so moving a copy between books updates both. |
| `BorrowRecordContactTrigger`       | `Borrow_Record__c` before insert/update                  | `LibraryTransactionContactService.syncBorrowRecords` | Fills the legacy `Contact__c` lookup from `Member__r.Contact__c`.                                                                                                                                         |
| `ReservationContactTrigger`        | `Reservation__c` before insert/update                    | `…syncReservations`                                  | Same Contact mirror.                                                                                                                                                                                      |
| `FineContactTrigger`               | `Fine__c` before insert/update                           | `…syncFines`                                         | Same Contact mirror.                                                                                                                                                                                      |
| `MembershipPaymentContactTrigger`  | `Membership_Payment__c` before insert/update             | `…syncMembershipPayments`                            | Same Contact mirror.                                                                                                                                                                                      |
| `MemberNotificationContactTrigger` | `Member_Notification__c` before insert/update            | `…syncMemberNotifications`                           | Same Contact mirror.                                                                                                                                                                                      |
| `MemberContactSyncTrigger`         | `Member__c` after update                                 | `…syncTransactionsForChangedMembers(new, oldMap)`    | When a member's linked Contact changes, re-points existing transactions.                                                                                                                                  |

## Why the Contact mirrors?

Experience Cloud **sharing sets** can only grant access through the portal user's Contact. The loan/reservation/fine/payment/notification records belong to `Member__c`, so triggers keep a `Contact__c` copy that the sharing sets (`sharingSets/`) match against. Runtime member access in the LWR portal does **not** depend on this (it uses the session token), so the mirrors are legacy-compatibility.

## Rules

- Keep triggers logic-free; add behaviour in the service.
- Bulk-safe: services take lists / sets.
- When adding a new object that members view through sharing sets, add a `…ContactTrigger` + a sharing set.
