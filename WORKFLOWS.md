# Workflows

## New external member

`Create IdP account -> verification email -> verify -> sign in -> complete application -> Pending -> librarian review -> approve/reject -> Active or Rejected -> sign in -> UID resolution -> scoped dashboard`

Approval activates the already linked Member record and membership dates. It does not create a Salesforce community user. Rejected accounts remain linked for audit and cannot access the portal; reapplication/reactivation requires an explicit librarian policy.

## Member access

Every protected request validates the token, resolves exactly one active/verified member, and scopes data by that member. Members can browse, view their profile/loans/reservations/fines/membership/payments, edit permitted profile fields, borrow an available copy, reserve a book, renew their own eligible loan, and cancel their own eligible reservation.

## Librarian operations

The Lightning workspace supports dashboard, books/copies, members, registrations, circulation, reservations, and fines. Catalog, circulation, fine, and registration methods require distinct custom permissions. Librarians can suspend and reactivate verified external portal accounts through a real backend operation. Librarian member selection is valid because it is an internal operational workflow; it is never used as member identity.

## Checkout

Checks active membership and plan, expiry, borrow limit, outstanding fines, copy availability, and reservation priority. Creates one active loan and changes the copy to Borrowed. Inventory aggregates update automatically.

## Return and fines

Closes the loan. An overdue fine is generated once from the plan's daily rate. If no queue exists the copy becomes Available; otherwise the earliest pending reservation becomes Ready, receives the copy and expiry, and the copy becomes Reserved.

## Renewal

Requires an active/overdue loan owned by the member, eligible membership, remaining renewal allowance, and no blocking reservation from another member. Extends by the plan loan duration.

## Reservations

Enforces membership eligibility, plan reservation limit, and one active reservation per member/book. Queue order is by reservation time then ID. Cancelled/expired ready holds promote the next member and resequence the queue.

## Membership and payments

Current payment code records demonstration payments and membership changes. It is not a production payment gateway. Do not represent it as charging real money. Production requires gateway redirect/tokenization, signed webhook confirmation, idempotency, reconciliation, and refund handling.
