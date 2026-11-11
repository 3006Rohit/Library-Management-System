# Registration, authentication & sessions

## What it does

Visitors apply for membership (optionally paying), a librarian approves, the member activates and logs in with e-mail + password, and then uses the portal with a server-validated session token.

## Actors

Visitor → Applicant → Member; Librarian (approver).

## Data

`Library_Registration__c` (application), `Member__c` (identity + password hash/salt + lockout fields), `Member_Session__c` (hashed token), `Membership_Plan__c`.

## Code path

```
libraryRegistration (LWC)
  → LibraryRegistrationGuestController.getPaymentQuote / submitRegistrationWithPayment
      → LibraryRegistrationService.submitGuest   (normalises e-mail, dedups via Registration_Email_Key__c)
Librarian: libraryRegistrationReview / workspace
  → LibraryExternalRegistrationController.approveRegistration | rejectRegistration | retryProvisioning
      → LibraryRegistrationService.approve → enqueue
          LibraryRegistrationProvisioningQueueable
            → LibraryRegistrationUserQueueable        (Contact/User provisioning)
              → LibraryRegistrationFinalizeQueueable  (activate Member__c, dates, notification)
          on error → LibraryRegistrationFailureQueueable.record (Provisioning_State/Message on the registration)
Member:
  libraryMemberAuthFlow → LibraryMemberAuthController.activateAccount (token hash + expiry on Member__c)
  libraryMemberLogin    → LibraryMemberAuthController.login → LibraryMemberPasswordService.matches
                          → LibraryMemberSessionService.create → raw token returned ONCE; hash stored
  every portal call     → LibraryMemberSessionService.getCurrentMember(rawToken)
  logout / reset / change password → revoke (single or all sessions)
```

## Rules & edge cases

- **Two status fields:** `Member__c.Status__c` (membership) vs `Account_Status__c` (Pending, Active, Suspended, Rejected, Inactive). Portal access requires Active + `Email_Verified__c`.
- Failed logins increment `Failed_Login_Count__c`; `Locked_Until__c` throttles.
- Reset/activation tokens: stored only as hash with expiry; responses to forgot-password do not reveal whether the e-mail exists (generic message).
- Rejected applicants stay linked for audit; re-application needs an explicit librarian policy.
- Provisioning failures never lose the registration — retry via `retryProvisioning` after fixing the cause (licence, config).
- Config comes from `Library_Experience_Config__mdt` (profile, permission set, network, hold days).
- Idempotency: unique `Registration_Email_Key__c`, `Normalized_Email__c`, `External_Auth_Id__c`.

## Tests

`LibraryRegistrationServiceTest`, `LibraryRegistrationLifecycleTest`, `LibraryRegistrationPaymentTest`, `LibraryMemberProvisioningQueueableTest`, `LibraryMemberAuthControllerTest`; Jest: `libraryRegistration`, `libraryMemberLogin`, `libraryMemberAuthFlow`.
