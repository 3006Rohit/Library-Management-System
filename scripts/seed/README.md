# `scripts/seed/` — demo data

Run in order with `sf apex run --file scripts/seed/<file> --target-org library-org`. Everything is tagged with **SEED markers** so `cleanup.apex` can remove it without touching real data.

| Order | Script                    | Creates                                                                                                                                                      |
| ----- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1     | `1_catalog_members.apex`  | 70 books (ISBN `97820*`), authors/category links, 170 copies (barcode `SEED-*`), 50 members (`*@seed.library.test`)                                          |
| 2     | `2_transactions.apex`     | 200 borrow records, 45 fines, 50 reservations for the seeded members/copies                                                                                  |
| 3     | `3_engagement_rooms.apex` | 55 reviews, 70 reading-list entries, 6 rooms, 23 room bookings — stored as `Library_Scan_Transaction__c` ledger rows in the same JSON shape the services use |
| –     | `cleanup.apex`            | Removes all of the above (matched by SEED markers); original data and the 3 original membership plans remain                                                 |

Tips: run stage 1 → 2 → 3 in separate executions (governor limits). If you change a service's ledger payload shape, update stage 3 as well.
