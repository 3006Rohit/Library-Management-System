# Membership plans, holds & payments

## Plans

`Membership_Plan__c`: `Fee__c`, `Duration_Days__c`, `Borrow_Limit__c`, `Loan_Duration_Days__c`, `Reservation_Limit__c`, `Renewal_Limit__c`, `Fine_Per_Day__c`, `Queue_Priority__c`, `Active__c`. Librarians edit via `saveMembershipPlan`; every policy decision reads these fields. Guests may read plans (guest sharing rule).

## Upgrade / renew

`LibraryMembershipPaymentService`: `getUpgradePlans`, `getPlanCatalog`, `payAndUpgrade(memberId, newPlanId)`, `renewMembership(memberId)`; UI in `libraryMemberShell`. Each creates a `Membership_Payment__c` recording previous/new plan.

> The in-app upgrade path is a **demonstration** payment; real money requires the gateway workflow below.

## Hosted-checkout gateway (hardened)

`LibraryPaymentGatewayService`:

1. `initiate(...)` creates an `Initiated` payment with a unique `Idempotency_Key__c`; returns provider checkout details.
2. Provider calls `POST /services/apexrest/library/payments/webhook` → `LibraryPaymentWebhookRest.receive()` → `processWebhook(payload, signature)`.
3. Webhook is **HMAC-verified** with `Payment_Gateway_Config__mdt.Webhook_Secret__c`, validates amount/currency and event uniqueness, and is the **only** path that sets `Paid`, `Failed`, `Cancelled`, `Disputed`, `Partially Refunded` or `Refunded`.
4. `requestRefund(...)` needs permission, a reason, an idempotency key and remaining refundable balance; the provider's signed refund event finalises state.
   `getConfigurationStatus()` returns booleans only (never secrets); ready only if enabled + provider + checkout Named Credential + secret exist. Baseline record is disabled, currency INR.

## Finance operations (`libraryPaymentOperations`)

`LibraryPaymentOperationsService`: `createReceipt(paymentId)` (idempotent, protected, only for paid), `getExceptions()` (Pending/Exception reconciliation), `reconcile(paymentId, status, reason)` — reason mandatory, audited, never touches gateway state.

## Registration payments

`LibraryRegistrationGuestController.getPaymentQuote(planId)` and `submitRegistrationWithPayment` capture payment info on `Library_Registration__c` (`Payment_Amount__c`, `Payment_Status__c`, `Payment_Reference__c`, `Payment_Method_Used__c`).

## Membership holds (pause)

`LibraryMembershipHoldService`: members `submit` a 1–90 day future hold with explanation (idempotent per member+range; overlaps rejected), `cancel` own pending, `getStatus` (includes a read-only 7-day **grace** indicator after expiry). Librarians `getAll` / `decide(holdId, status, reason)` under `Manage_Library_Circulation`; approval locks the member row and extends `Membership_End_Date__c` by the inclusive duration **exactly once**, storing original/adjusted dates and policy version. UI: `libraryLibrarianMembershipHolds`.

## Tests

`LibraryMembershipPaymentServiceTest`, `LibraryPaymentGatewayServiceTest`, `LibraryPaymentWebhookRestTest`, `LibraryPaymentOperationsServiceTest`, `LibraryMembershipHoldServiceTest`, `LibraryMembershipPlanCatalogTest`; Jest `libraryPaymentOperations`.
