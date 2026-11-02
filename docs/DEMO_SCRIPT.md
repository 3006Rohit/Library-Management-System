# Library Management System: Demo Script (about 15 minutes)

## Before you start (5 min prep)

- Log in to `library-org` and open both views in separate tabs: the **Experience Cloud member portal** (site `Library`) and the **Library Management app** (Lightning, Librarian Workspace tab).
- Have two test accounts ready: one **active member** and one **librarian**.
- Check that at least one book has an Available copy and one has a reservation queue.
- Open the Agentforce agent in a third tab (member assistant).
- Keep a backup of screenshots in case the org is slow.
- Check that the org has the latest code deployed. The local source has uncommitted changes (reservation queue priority, circulation detail action) that I could not confirm are deployed.

---

## 1. Opening: the problem and the idea (1 min)

> "This is a library management system built entirely on the Salesforce platform. Members get a self-service portal, librarians get an operations workspace, and both have an AI assistant built with Agentforce. The goal was to replace spreadsheets and manual desk work with one system that handles the full lifecycle: join, borrow, reserve, return, fines, and reporting."

**Key numbers to quote:** 28 custom objects, 120+ Apex classes, 40 LWCs, 5 Agentforce agent bundles, 8 permission sets, API v68.

## 2. Architecture in one slide (2 min)

Draw or show this:

```
Members (Experience Cloud LWR site, custom auth)
        |                          Librarians (Lightning app + Workspace LWC)
        v                                   v
   LWC components  ->  Apex services (Circulation, Reservation, Fines, Payments, Notifications)
        |                                   |
        +-------------> Custom objects <----+
        (Member__c, Book__c, Book_Copy__c, Borrow_Record__c, Reservation__c, Fine__c ...)
        ^
   Agentforce agents (Member + Librarian) calling Apex actions
```

Points to say:

- **Custom member authentication** (`Member__c` + `Member_Session__c`) instead of Salesforce licences per member. Every request validates the token, resolves exactly one active member, and scopes all data to that member.
- **Business logic lives in Apex services**, not the UI, so the portal, the librarian workspace, and the AI agents all use the same rules.
- **Source-driven** (SFDX, Git, CI validation, deploy scripts).

## 3. Member journey (4 min)

1. **Public catalog** (no login): search a book, show availability.
2. **Registration:** new member applies, goes to Pending. Mention librarian approval gates access.
3. **Log in** as an active member: dashboard, loans, reservations, fines, membership.
4. **Borrow / Scan & Borrow:** enter a copy barcode, preview, confirm. Mention the unique scan key, so retries cannot create duplicate loans.
5. **Reserve** a book that is out: show queue position and the **ETA estimate** with a confidence level (High/Medium/Low).
6. **Extras (pick 2):** Reading List and Followed Authors (newest feature), Events with waitlist, Room booking, Digital Member Card (10-minute one-time token), Accessibility settings, Privacy Center.

> Line to say: "Checkout checks membership, plan, borrow limit, outstanding fines, copy availability and reservation priority before it creates a loan."

## 4. Librarian journey (3 min)

Switch to the Librarian Workspace.

1. **Approve a pending registration.**
2. **Circulation:** return a book. Show the fine auto-generated once from the plan's daily rate, and the next person in the reservation queue promoted to Ready.
3. **Fine appeal / membership hold review.**
4. **Reports panel:** executive summary, acquisition recommendations (explainable purchase/replace scores), risk alerts, notification delivery status.
5. **Audit trail:** every privileged action is logged with who, what and why. Passwords and tokens are excluded by design.

## 5. Agentforce AI assistant (2 min)

In the member assistant, ask:

- "What books do I have on loan?"
- "When is my loan due?"
- "Renew _<book name>_."

Point out the **confirmation gate**: the agent shows an exact preview and only acts after the member confirms, using a short-lived single-use token. The server rechecks ownership and policy before it acts.

For the librarian agent, ask an analytics question, for example "Which books are most reserved?"

> "The agent never has its own logic. It calls the same Apex services, so it cannot bypass any rule."

## 6. Security, quality and engineering (1 min)

- Permission sets separate catalog, circulation, fine and registration powers.
- CRUD/FLS reviews, audit logs, idempotent operations (safe to retry).
- Apex tests for each service, a Jest setup for LWC, and a CI validation script (`validate-deployment-package.ps1`).

## 7. Honest limits and next steps (1 min)

Say these before your senior asks:

- **Payments:** the gateway flow (hosted checkout, signed webhooks, refunds) is built, but the provider config ships **disabled**. Today it is a demonstration, not live charging. The changelog mentions Stripe, so be ready to explain that it needs a real provider setup first.
- **Data Cloud:** readiness checks and a handoff contract exist, but streams and calculated insights are admin setup work and are not done by this project.
- **Scan ledger:** it uses a temporary object, with a planned migration to dedicated objects.
- **Next:** go-live gateway, Data Cloud setup, and more UAT.

---

## Likely questions and short answers

| Question                                               | Answer                                                                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Why not Salesforce community licences for members?     | Cost and control. Custom auth plus `Member__c` keeps licence cost down and scopes data per member.           |
| How do you prevent double borrowing or double booking? | Row locking plus idempotency keys on checkout, rooms, events and holds.                                      |
| How does the AI avoid doing something harmful?         | Confirmation tokens, server-side revalidation, and permission sets limited to read-only or specific actions. |
| How is it deployed?                                    | `scripts/deploy-library.ps1` with a validate-only mode, and a core package plus an Agentforce package.       |
| What is tested?                                        | Apex test classes per service. See `CORE_TESTING_REPORT.md` and `UAT_TESTING_GUIDE.md`.                      |

## If something breaks during the demo

- Switch to screenshots, or to `Library_Management_System_Overview.pptx` in the repo root.
- Say "this is a sandbox org with test data" and move on to the next section.
