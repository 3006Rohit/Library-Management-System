# `sharingSets/`

Experience Cloud **sharing sets** give portal users Read access to records whose lookup matches their own Contact.

| Sharing set                          | Object                   | Match                             |
| ------------------------------------ | ------------------------ | --------------------------------- |
| `Library_Member_Member_Access`       | `Member__c`              | member's Contact = user's Contact |
| `Library_Member_Borrow_Access`       | `Borrow_Record__c`       | `Contact__c` mirror               |
| `Library_Member_Reservation_Access`  | `Reservation__c`         | `Contact__c` mirror               |
| `Library_Member_Fine_Access`         | `Fine__c`                | `Contact__c` mirror               |
| `Library_Member_Payment_Access`      | `Membership_Payment__c`  | `Contact__c` mirror               |
| `Library_Member_Notification_Access` | `Member_Notification__c` | `Contact__c` mirror               |

The `Contact__c` fields are maintained by [triggers](../triggers/README.md). All sets grant **Read** only; writes always go through Apex.
