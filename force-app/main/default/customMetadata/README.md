# `customMetadata/` — configuration records

| Record                              | Type                             | Values                                                                                                                                                                     |
| ----------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Library_Experience_Config.Default` | `Library_Experience_Config__mdt` | Community account `Library Community Members`, external profile `Customer Community User`, permission set `Library_Member`, network `Library`, `Hold_Duration_Days__c = 3` |
| `Payment_Gateway_Config.Default`    | `Payment_Gateway_Config__mdt`    | `Default_Currency__c = INR`, **`Enabled__c = false`** (safe baseline)                                                                                                      |

Consumers: `LibraryRegistrationService` (provisioning names), `LibraryPolicyService.holdDurationDays()` (hold length), `LibraryPaymentGatewayService` (gateway readiness: enabled + provider name + checkout Named Credential + webhook secret all required).

## Enabling a payment provider

1. Set `Provider_Name__c`, `Checkout_Named_Credential__c`, `Webhook_Secret__c` in the org (not in git).
2. Set `Enabled__c = true`.
3. Open Librarian → Payments: the readiness panel must report _ready_.
