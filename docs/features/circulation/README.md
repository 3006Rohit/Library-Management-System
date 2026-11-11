# Circulation: borrow, return, renew, reserve, fines

Core engine: `LibraryCirculationService` (without sharing; callers enforce permission/ownership).

## Flows

| Flow               | Entry points                                                                                                                          | Behaviour                                                                                                                                                                                                                                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Checkout**       | Librarian `checkout(memberId, copyId)`; member `LibraryMemberBorrowService.checkout`; scan self-checkout                              | Validates via `LibraryPolicyService.canBorrow`: active membership & plan, not expired, borrow limit, no blocking fines, copy `Available` (or held for this member). Creates one active `Borrow_Record__c`, sets copy `Borrowed`. Due date = plan `Loan_Duration_Days__c`, moved past closures by `LibraryCalendarService`. |
| **Borrow request** | member `request`; librarian `approveBorrowRequest` / `rejectBorrowRequest(reason)`                                                    | Request/approve workflow for members who cannot self-checkout.                                                                                                                                                                                                                                                             |
| **Return**         | `returnLoan`, `returnLoanForMember` (own loans only), scan return                                                                     | Closes loan; generates an overdue `Fine__c` **once** from `Fine_Per_Day__c`; copy → `Available`, or if a queue exists the earliest pending reservation becomes **Ready** and the copy `Reserved`.                                                                                                                          |
| **Renew**          | `renewLoan` / `renewMyLoan`                                                                                                           | Needs active/overdue loan owned by member, eligible membership, remaining `Renewal_Limit__c`, no blocking reservation by another member; extends by plan loan days.                                                                                                                                                        |
| **Reserve**        | `createReservation` / `reserveBook`                                                                                                   | Membership eligible, within `Reservation_Limit__c`, one active reservation per member/book. Queue ordered by priority (`Membership_Plan__c.Queue_Priority__c`), time, then Id (see `LibraryReservationQueuePriorityTest`).                                                                                                 |
| **Ready / expiry** | `LibraryReservationWorkflowService.prepareReservation`, `promoteAvailableReservations`; `LibraryReservationExpiryBatch` + `Scheduler` | Ready holds expire after `Hold_Duration_Days` (default 3); next member promoted; queue resequenced. Manual run: _Process expired reservations_ in the workspace.                                                                                                                                                           |
| **Fines**          | `recordFinePayment(fineId, amount)`, `waiveFine(fineId, reason)`                                                                      | Updates `Paid_Amount__c`, `Balance__c`, status (Unpaid → Partially Paid → Paid / Waived). Appeals: see [privacy-accessibility](../privacy-accessibility/README.md).                                                                                                                                                        |

## ETA for waiting members

`LibraryReservationEtaService.recalculateForBook(s)` computes `Estimated_Available_Date__c`, `ETA_Confidence__c` (High/Medium/Low) and `ETA_Reason__c` from available copies, due dates of active loans, queue position, and a conservative default loan duration. Recalculated after create/cancel, checkout, return, promotion, expiry. It is an estimate, not a guarantee.

## Audit

`LibraryReservationAuditService.record` writes `Reservation_Audit__c` rows for each lifecycle transition (actor, from/to status, queue position).

## Data integrity

Validation rules on `Reservation__c`, non-negative amounts, chronological dates; Contact mirrors via triggers ([triggers README](../../../force-app/main/default/triggers/README.md)). Repair for queue numbering: `scripts/apex/resequence-all-reservation-queues.apex`.

## Tests

`LibraryLibrarianOperationsTest`, `LibraryReservationQueuePriorityTest`, `LibraryReservationEtaServiceTest`, `LibraryMemberControllerTest`, `LibraryScanServiceTest`.
