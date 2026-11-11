# `sharingRules/`

One `SharingRules` file for each of 12 objects. Two kinds of rule appear:

## 1. `Share_With_Librarians` (criteria rule → group)

Criteria "Name is not blank" (all records) shared to public group **`Library_Librarians`** with **Edit** access. This is how staff see Private records. Present on: `Author__c`, `Book_Category__c`, `Borrow_Record__c`, `Fine__c`, `Library_Registration__c`, `Member__c`, `Membership_Plan__c`, `Reservation__c`.

`Member_Notification__c`, `Membership_Payment__c` and `Reservation_Audit__c` also use criteria rules (their own criteria — open the XML to see the exact filter).

## 2. Guest rules (for the public website)

Shared to the Experience site's guest user `Library`, **Read** only:

- `Book__c` — rule `Active_Books_For_Library_Guests`: only records with `Status__c = Active`.
- `Membership_Plan__c` — guest read rule so signed-out visitors can see plans.

To grant a person librarian visibility: add them to the `Library_Librarians` group and assign `Library_Librarian`. Members get access through [sharing sets](../sharingSets/README.md), not these rules. Org-wide defaults: see [objects README](../objects/README.md).
