# `customPermissions/`

Feature gates checked in Apex with `FeatureManagement.checkPermission` through `LibraryPolicyService.require(...)`.

| Name                           | Gate                                                                         |
| ------------------------------ | ---------------------------------------------------------------------------- |
| `Manage_Library_Catalog`       | Catalog, import, ISBN metadata, events, rooms, challenges, review moderation |
| `Manage_Library_Circulation`   | Circulation, reservations, holds, appeals, member lookup                     |
| `Manage_Library_Fines`         | Recording payments, waivers                                                  |
| `Manage_Library_Registrations` | Registration decisions, privacy, audit, payment operations                   |
| `Library_Public_Agent`         | Marks the running user as the signed-out public assistant                    |

Grant via `permissionsets/Library_Librarian` (first four) and `Library_Public_Agent_Access` (last).
