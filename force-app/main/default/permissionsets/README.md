# `permissionsets/` — Access control

Ten permission sets plus the supporting `profiles/Library Profile`, `roles/Library_Operations` and `groups/Library_Librarians` (public group that receives record shares — see [sharingRules](../sharingRules/README.md)).

| Permission set                        | Intended for                                          | Grants (observed)                                                                                                                                                                      |
| ------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Library_Librarian`                   | Internal library staff                                | CRUD/FLS on 21 objects, 8 Apex classes, and the four custom permissions `Manage_Library_Catalog`, `Manage_Library_Circulation`, `Manage_Library_Fines`, `Manage_Library_Registrations` |
| `Library_Member`                      | Portal/provisioned member users                       | 19 objects (read scope), 3 Apex classes                                                                                                                                                |
| `Library_Member_Agent_Actions`        | Agent user for member agents                          | 11 objects, 6 action classes                                                                                                                                                           |
| `Library_Member_Agent_Guest`          | Guest context of the member agent                     | 1 object                                                                                                                                                                               |
| `Library_Agent_Librarian_ReadOnly`    | Agent user for librarian agents                       | 6 objects, 9 action classes, `Manage_Library_Circulation`                                                                                                                              |
| `Library_Agent_Member_Transactions`   | Agent user performing confirmed member transactions   | 1 Apex class (confirmation/commit path)                                                                                                                                                |
| `Library_Public_Agent_Access`         | Agent user for the public assistant                   | 5 public-action classes, custom permission `Library_Public_Agent`                                                                                                                      |
| `Library_Public_Chat_Ledger_Admin`    | Access to `Library_Public_Chat_Session__c`            | 1 object                                                                                                                                                                               |
| `Library_Author_Link_Key_Admin`       | One-off admin to maintain unique `Book_Author_Key__c` | field-level only                                                                                                                                                                       |
| `Library_Member_Classification_Admin` | One-off admin to set `Member__c.Member_Type__c`       | field-level only                                                                                                                                                                       |

## Assigning

```powershell
sf org assign permset --name Library_Librarian --on-behalf-of <username> --target-org library-org
sf org assign permset --name Library_Member    --on-behalf-of <username> --target-org library-org
```

Agent users (e.g. `library_public_assistant@…ext`) need their matching agent permission set.

## Custom permissions → code

| Custom permission              | Enforced by                                                                                           |
| ------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `Manage_Library_Catalog`       | `LibraryPolicyService.require` in catalog, import, ISBN, events, rooms, challenges, review moderation |
| `Manage_Library_Circulation`   | checkout/return/renew, holds, appeals, ledger review, member summary                                  |
| `Manage_Library_Fines`         | fine payment/waive                                                                                    |
| `Manage_Library_Registrations` | registrations, privacy review, audit viewer, payment ops                                              |
| `Library_Public_Agent`         | `LibraryAgentCatalogAction` switches to single-row summary mode                                       |

(Indicative mapping. Check the specific method for the exact permission it requires: `grep -rn "LibraryPolicyService.require" classes/`.)

## Security principles

- Members never get object access to others' data — runtime reads are scoped by token in Apex.
- No permission set carries credentials. Secrets live in protected custom metadata / Named & External Credentials.
