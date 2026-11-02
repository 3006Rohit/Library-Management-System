# Testing Checklist v1.0

## Pre-Testing Setup

- [x] Org is clean (test data removed)
- [x] All code deployed successfully
- [x] Data Cloud insights created & running
- [x] Agentforce agents activated
- [ ] Payment gateway configured
- [ ] Email relay enabled

---

## Functional Testing

### Member Registration & Authentication

- [x] **Register new member** → Receives verification email ✅
- [x] **Verify email** → Account activated ✅
- [x] **Login with credentials** → Session token created ✅
- [ ] **Reset password** → Reset email received
- [ ] **Invalid password** → Login fails, account locked after 5 attempts
- [ ] **Email already exists** → Registration rejected

### Book Management

- [x] **Search books** → Results filtered by title/author/category ✅
- [x] **View book details** → Availability, description, author info shown ✅
- [ ] **Add to wishlist** → Book saved for member
- [ ] **Remove from wishlist** → Book removed
- [ ] **Sort results** → By relevance, popularity, availability

### Borrowing & Loans

- [x] **Borrow available book** → Loan created, due date set ✅
- [x] **View my loans** → All active loans displayed ✅
- [ ] **Renew loan** → Due date extended (if allowed)
- [ ] **Return book** → Loan marked returned, inventory updated
- [ ] **Overdue notification** → Email sent when past due
- [ ] **Renewal limit exceeded** → Cannot renew further

### Reservations

- [x] **Reserve unavailable book** → Queue position shown ✅
- [x] **View my reservations** → Pending/ready/fulfilled shown ✅
- [ ] **Book becomes available** → Notification sent
- [ ] **Cancel reservation** → Removed from queue
- [ ] **Hold expires** → Auto-canceled after hold period

### Fine Management

- [x] **Fine generated** → When book overdue ✅
- [x] **View fines** → All outstanding fines listed ✅
- [ ] **Pay fine** → Payment processed, balance updated
- [ ] **Appeal fine** → Submitted for librarian review
- [ ] **Fine waived** → Status changed, member notified

### Librarian Workspace

- [ ] **View analytics** → Copy metrics, loan stats displayed
- [ ] **Search members** → By name/email/ID
- [ ] **View member profile** → Loans, reservations, fines shown
- [ ] **Process registration** → Approve/deny membership
- [ ] **Place membership hold** → Prevent borrowing
- [ ] **Scan book** → Update inventory status
- [ ] **Report damage** → Track book condition

### Agentforce Agents

- [x] **Member Agent - Check loans** → Returns active loans accurately ✅
- [x] **Member Agent - Check reservations** → Shows pending/ready reservations ✅
- [x] **Member Agent - Search catalog** → Finds books correctly ✅
- [ ] **Librarian Agent - Show analytics** → Displays accurate metrics
- [ ] **Librarian Agent - Member lookup** → Finds member information
- [ ] **Agent error handling** → Graceful fallback on failures

### Data Cloud

- [ ] **Copy Availability insight** → Reflects current inventory
- [ ] **Member Loan Activity insight** → Shows active/overdue counts
- [ ] **Book Popularity insight** → Ranks books correctly
- [ ] **Reservation Demand insight** → Shows queue lengths
- [ ] **Insights refresh on schedule** → Data updates every 6 hours

---

## Performance Testing

- [ ] **Portal load time** — Member portal loads in <3 seconds
- [ ] **Catalog search** — Searches 1000+ books in <2 seconds
- [ ] **Dashboard load** — Librarian analytics loads in <5 seconds
- [ ] **Batch jobs** — Overdue notifications process without timeout
- [ ] **Data Cloud refresh** — Completes within scheduled window

---

## Security Testing

- [ ] **Authentication bypass** — Cannot login without credentials
- [ ] **Session hijacking** — Session token cannot be reused after logout
- [ ] **SQL injection** — Catalog search safe from injection
- [ ] **XSS prevention** — Member input sanitized in display
- [ ] **CSRF protection** — Form submissions validated
- [ ] **Field-level security** — Members cannot see admin fields
- [ ] **Sharing rules enforced** — Members see only their data

---

## Integration Testing

- [ ] **Email notifications** — Overdue/ready/appeal emails sent
- [ ] **Payment gateway** — Fine payments processed correctly
- [ ] **Data Cloud sync** — Transaction data flows to insights
- [ ] **Member portal auth** — Integrates with session controller
- [ ] **Agent actions** — Invocable methods return correct data

---

## Browser Compatibility

- [ ] **Chrome** — Latest version
- [ ] **Safari** — Latest version
- [ ] **Firefox** — Latest version
- [ ] **Mobile Chrome** — iOS/Android
- [ ] **Mobile Safari** — iOS

---

## Accessibility Testing

- [ ] **High contrast mode** — Portal readable in high contrast
- [ ] **Large text** — Text scales to 200% without breaking layout
- [ ] **Screen reader** — ARIA labels present on all interactive elements
- [ ] **Keyboard navigation** — Tab through all forms without mouse
- [ ] **Form validation** — Error messages announced to screen reader

---

## UAT Sign-Off

### Librarian Testing

- [ ] Workspace functions as expected
- [ ] Can manage members and circulation
- [ ] Analytics provide useful insights
- [ ] Agent assistance helpful for operations

**Librarian Approval**: _________________ Date: _______

### Member Testing

- [ ] Portal is intuitive and easy to use
- [ ] Can find and borrow books
- [ ] Notifications are timely and clear
- [ ] Agent responds helpfully to questions

**Member Approval**: _________________ Date: _______

---

## Issues Found

| Issue | Severity | Status | Resolution |
| ----- | -------- | ------ | ---------- |
|       |          |        |            |

---

## Sign-Off

- [ ] All critical tests passed
- [ ] All blockers resolved
- [ ] Stakeholders approve
- [ ] Ready for production

**Tester**: _________________ Date: _______

**Project Lead**: _________________ Date: _______
