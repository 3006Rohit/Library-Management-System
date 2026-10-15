import { LightningElement, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import USER_ID from "@salesforce/user/Id";
import USER_NAME from "@salesforce/schema/User.Name";
import USER_EMAIL from "@salesforce/schema/User.Email";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getDashboard from "@salesforce/apex/LibraryLibrarianController.getDashboard";
import getDashboardAnalytics from "@salesforce/apex/LibraryLibrarianController.getDashboardAnalytics";
import searchBooks from "@salesforce/apex/LibraryLibrarianController.searchBooks";
import getBookDetail from "@salesforce/apex/LibraryLibrarianController.getBookDetail";
import getAuthors from "@salesforce/apex/LibraryLibrarianController.getAuthors";
import getCategories from "@salesforce/apex/LibraryLibrarianController.getCategories";
import searchMembers from "@salesforce/apex/LibraryLibrarianController.searchMembers";
import searchCopies from "@salesforce/apex/LibraryLibrarianController.searchCopies";
import getMemberDetail from "@salesforce/apex/LibraryLibrarianController.getMemberDetail";
import setMemberAccountStatus from "@salesforce/apex/LibraryLibrarianController.setMemberAccountStatus";
import addMember from "@salesforce/apex/LibraryLibrarianController.addMember";
import updateMember from "@salesforce/apex/LibraryLibrarianController.updateMember";
import renewMemberMembership from "@salesforce/apex/LibraryLibrarianController.renewMemberMembership";
import resetMemberPassword from "@salesforce/apex/LibraryLibrarianController.resetMemberPassword";
import getRegistrations from "@salesforce/apex/LibraryLibrarianController.getRegistrations";
import approveRegistration from "@salesforce/apex/LibraryExternalRegistrationController.approveRegistration";
import rejectRegistration from "@salesforce/apex/LibraryExternalRegistrationController.rejectRegistration";
import retryProvisioning from "@salesforce/apex/LibraryExternalRegistrationController.retryProvisioning";
import getReservations from "@salesforce/apex/LibraryLibrarianController.getReservations";
import createReservation from "@salesforce/apex/LibraryLibrarianController.createReservation";
import cancelReservation from "@salesforce/apex/LibraryLibrarianController.cancelReservation";
import processExpiredReservations from "@salesforce/apex/LibraryLibrarianController.processExpiredReservations";
import getFines from "@salesforce/apex/LibraryLibrarianController.getFines";
import getMembershipPlans from "@salesforce/apex/LibraryLibrarianController.getMembershipPlans";
import saveMembershipPlan from "@salesforce/apex/LibraryLibrarianController.saveMembershipPlan";
import getPayments from "@salesforce/apex/LibraryLibrarianController.getPayments";
import getLibrarySettings from "@salesforce/apex/LibrarySettingsController.getSettings";
import saveLibrarySettings from "@salesforce/apex/LibrarySettingsController.saveSettings";
import getLoans from "@salesforce/apex/LibraryLibrarianController.getLoans";
import startAgentSession from "@salesforce/apex/LibraryAgentApiController.startSession";
import sendAgentMessage from "@salesforce/apex/LibraryAgentApiController.sendMessage";
import endAgentSession from "@salesforce/apex/LibraryAgentApiController.endSession";
import addBook from "@salesforce/apex/LibraryLibrarianController.addBook";
import updateBook from "@salesforce/apex/LibraryLibrarianController.updateBook";
import addCopy from "@salesforce/apex/LibraryLibrarianController.addCopy";
import updateCopy from "@salesforce/apex/LibraryLibrarianController.updateCopy";
import checkout from "@salesforce/apex/LibraryLibrarianController.checkout";
import issueReservedBook from "@salesforce/apex/LibraryLibrarianController.issueReservedBook";
import prepareReservation from "@salesforce/apex/LibraryLibrarianController.prepareReservation";
import returnLoan from "@salesforce/apex/LibraryLibrarianController.returnLoan";
import renewLoan from "@salesforce/apex/LibraryLibrarianController.renewLoan";
import recordFinePayment from "@salesforce/apex/LibraryLibrarianController.recordFinePayment";
import waiveFine from "@salesforce/apex/LibraryLibrarianController.waiveFine";

const NAV = [
  ["Dashboard", "utility:home"],
  ["Librarian Assistant", "utility:einstein"],
  ["Books", "utility:knowledge_base"],
  ["Book Copies", "utility:copy"],
  ["Members", "utility:groups"],
  ["Registrations", "utility:form"],
  ["Borrowing", "utility:retail_execution"],
  ["Reservations", "utility:bookmark"],
  ["Fines", "utility:money"],
  ["Memberships", "utility:contract"],
  ["Payments", "utility:payment_gateway"],
  ["Reports", "utility:chart"],
  ["Settings", "utility:settings"]
];
const PAGE_COPY = {
  Dashboard: ["Dashboard", "A clear view of today’s library operations"],
  "Librarian Assistant": [
    "Librarian Assistant",
    "Read-only assistance for library operations"
  ],
  Books: ["Books", "Manage library books, authors and categories"],
  "Book Copies": [
    "Book Copies",
    "Manage physical copies of books in the library"
  ],
  Members: ["Members", "Manage library members and their details"],
  Registrations: [
    "Member Registrations",
    "Review and manage new member registration requests"
  ],
  Borrowing: [
    "Borrowing Transactions",
    "Manage book issue, return and renew operations"
  ],
  Reservations: ["Reservations", "Manage book reservations and waiting list"],
  Fines: ["Fines", "Manage member fines and payments"],
  Memberships: [
    "Membership Plans",
    "Manage membership plans and subscriptions"
  ],
  Payments: ["Payments", "View and manage membership and fine payments"],
  Reports: ["Reports", "Review operational performance and trends"],
  Settings: ["Settings", "Review configured library policies and rules"]
};

export default class LibraryLibrarianWorkspace extends LightningElement {
  section = "Dashboard";
  dashboard = { recentLoans: [] };
  analytics = { available: false, topBorrowedBooks: [], reservationDemand: [] };
  books = [];
  members = [];
  allMembers = [];
  copies = [];
  registrations = [];
  allRegistrations = [];
  loans = [];
  reservations = [];
  allReservations = [];
  fines = [];
  allFines = [];
  plans = [];
  payments = [];
  allPayments = [];
  memberDetail;
  bookDetail;
  loading = false;
  error;
  sidebarOpen = false;
  notificationsOpen = false;
  userName = "Librarian";
  userEmail = "";
  bookSearch = "";
  bookStatus = "";
  bookCategory = "";
  bookPage = 1;
  pageSize = 10;
  memberSearch = "";
  memberStatus = "";
  memberPage = 1;
  memberPageSize = 5;
  memberTab = "Overview";
  showMemberModal = false;
  showRegistrationModal = false;
  showReservationModal = false;
  showFineModal = false;
  showPlanModal = false;
  showPaymentModal = false;
  editingMember = false;
  editingPlan = false;
  membershipTab = "Plans";
  copySearch = "";
  copyStatus = "";
  copyLocation = "";
  copyPage = 1;
  copyHasNext = false;
  allCopies = [];
  registrationStatus = "Pending";
  loanStatus = "Active";
  reservationStatus = "Pending";
  reservationView = "Active";
  reservationSearch = "";
  fineStatus = "Unpaid";
  fineSearch = "";
  paymentStatus = "";
  paymentType = "";
  paymentSearch = "";
  selectedMemberId;
  selectedCopyId;
  selectedBookId;
  selectedFineId;
  paymentAmount;
  waiverReason;
  rejectReason;
  reservationMemberId;
  reservationBookId;
  globalSearch = "";
  showBookModal = false;
  showBookDetail = false;
  showCopyModal = false;
  editingBook = false;
  authorOptions = [];
  categoryOptions = [];
  selectedAuthorIds = [];
  selectedCategoryIds = [];
  bookForm = this.emptyBook();
  copyForm = this.emptyCopy();
  memberForm = this.emptyMember();
  planForm = this.emptyPlan();
  selectedRegistration;
  selectedReservation;
  selectedFine;
  selectedPayment;
  settings = this.defaultSettings();
  assistantInput = "";
  assistantSessionId;
  assistantSequence = 0;
  assistantBusy = false;
  realtimeRefreshTimer;
  assistantMessages = [
    {
      id: "welcome",
      className: "lib-assistant-message lib-assistant-message-bubble",
      text: "Hello! 👋 I’m your Librarian Assistant. I can help with books, members, circulation, reservations, fines, reports, and library operations. How can I help you today?"
    }
  ];

  @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME, USER_EMAIL] })
  wiredUser({ data }) {
    if (data) {
      this.userName = data.fields.Name.value;
      this.userEmail = data.fields.Email.value;
    }
  }

  connectedCallback() {
    this.loadDashboard();
    // Intentional polling keeps operational analytics current between user actions.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.realtimeRefreshTimer = window.setInterval(() => {
      if (this.section === "Dashboard" && !this.loading) this.loadDashboard();
    }, 5000);
  }

  disconnectedCallback() {
    if (this.realtimeRefreshTimer) {
      window.clearInterval(this.realtimeRefreshTimer);
      this.realtimeRefreshTimer = undefined;
    }
    if (this.assistantSessionId) {
      endAgentSession({ sessionId: this.assistantSessionId }).catch(
        () => undefined
      );
      this.assistantSessionId = undefined;
    }
  }

  get navItems() {
    return NAV.map(([label, icon]) => ({
      label,
      icon,
      value: label,
      active: label === this.section,
      className: label === this.section ? "nav-item active" : "nav-item"
    }));
  }
  get pageTitle() {
    if (this.showMemberDetails) return "Member Details";
    return PAGE_COPY[this.section][0];
  }
  get pageSubtitle() {
    if (this.showMemberDetails) return "View and manage member information";
    return PAGE_COPY[this.section][1];
  }
  get assistantSendLabel() {
    return this.assistantBusy ? "…" : "➤";
  }
  get userInitials() {
    return this.userName
      .split(" ")
      .map((part) => part[0])
      .slice(0, 2)
      .join("")
      .toUpperCase();
  }
  get shellClass() {
    return this.sidebarOpen ? "app-shell sidebar-open" : "app-shell";
  }
  get librarianNotifications() {
    const d = this.dashboard || {};
    const notices = [];
    const add = (key, title, message, section, icon, tone) => {
      notices.push({
        key,
        title,
        message,
        section,
        icon,
        iconClass: `notification-icon ${tone}`
      });
    };
    if ((d.pendingRegistrations || 0) > 0)
      add(
        "registrations",
        "Registrations awaiting review",
        `${d.pendingRegistrations} new member request${d.pendingRegistrations === 1 ? "" : "s"} need attention.`,
        "Registrations",
        "utility:form",
        "amber"
      );
    if ((d.overdueLoans || 0) > 0)
      add(
        "overdue",
        "Overdue loans",
        `${d.overdueLoans} loan${d.overdueLoans === 1 ? " is" : "s are"} past the due date.`,
        "Borrowing",
        "utility:warning",
        "red"
      );
    if ((d.pendingReservations || 0) > 0)
      add(
        "reservations",
        "Reservation queue waiting",
        `${d.pendingReservations} active reservation${d.pendingReservations === 1 ? " is" : "s are"} in the queue.`,
        "Reservations",
        "utility:bookmark",
        "blue"
      );
    if ((d.unpaidFines || 0) > 0)
      add(
        "fines",
        "Unpaid fines",
        `${d.unpaidFines} fine${d.unpaidFines === 1 ? " is" : "s are"} still unpaid.`,
        "Fines",
        "utility:money",
        "rose"
      );
    return notices;
  }
  get hasNotifications() {
    return this.librarianNotifications.length > 0;
  }
  get metrics() {
    const d = this.dashboard || {};
    const a = this.analytics || {};
    const copy = a.copyMetrics || {};
    const loans = a.loanMetrics || {};
    const reservations = a.reservationMetrics || {};
    const fines = a.fineMetrics || {};
    return [
      ["Total Books", d.totalBooks, "utility:knowledge_base", "blue", "Books"],
      [
        "Book Copies",
        a.available ? copy.totalCopies : d.totalCopies,
        "utility:copy",
        "green",
        "Book Copies"
      ],
      ["Members", d.totalMembers, "utility:groups", "purple", "Members"],
      [
        "Active Loans",
        a.available ? loans.activeLoans : d.activeLoans,
        "utility:retail_execution",
        "orange",
        "Borrowing"
      ],
      [
        "Overdue Loans",
        a.available ? loans.overdueLoans : d.overdueLoans,
        "utility:warning",
        "red",
        "Borrowing"
      ],
      [
        "Pending Reservations",
        a.available ? reservations.pendingReservations : d.pendingReservations,
        "utility:bookmark",
        "amber",
        "Reservations"
      ],
      [
        "Unpaid Fines",
        a.available ? fines.unpaidFineCount : d.unpaidFines,
        "utility:money",
        "rose",
        "Fines"
      ],
      [
        "Membership Revenue",
        this.currency(d.membershipRevenue),
        "utility:currency",
        "teal",
        "Payments"
      ]
    ].map(([label, value, icon, tone, section]) => ({
      label,
      value: value ?? 0,
      icon,
      tone,
      section,
      className: `metric-card ${tone}`
    }));
  }
  get analyticsAvailable() {
    return Boolean(this.analytics?.available);
  }
  get analyticsMessage() {
    return (
      this.analytics?.message ||
      "Data Cloud analytics are temporarily unavailable."
    );
  }
  get analyticsCadence() {
    const cadence =
      this.analytics?.refreshCadence ||
      "Live Salesforce data • updates automatically";
    return this.analytics?.lastUpdated
      ? `Last updated: ${new Date(this.analytics.lastUpdated).toLocaleString()} • ${cadence}`
      : cadence;
  }
  get copyAnalytics() {
    const m = this.analytics?.copyMetrics || {};
    return [
      ["Total Copies", m.totalCopies, "▤", "blue"],
      ["Available", m.availableCopies, "✓", "green"],
      ["Borrowed", m.borrowedCopies, "●", "orange"],
      ["Reserved", m.reservedCopies, "▦", "gold"],
      ["Lost", m.lostCopies, "!", "red"]
    ].map(([label, value, icon, tone]) => ({
      label,
      value: value ?? 0,
      icon,
      cardClass: `analytics-stat ${tone}`
    }));
  }
  get loanAnalytics() {
    const m = this.analytics?.loanMetrics || {};
    return [
      ["Total Loans", m.totalLoans, "▤", "blue"],
      ["Active", m.activeLoans, "●", "green"],
      ["Returned", m.returnedLoans, "✓", "purple"],
      ["Overdue", m.overdueLoans, "!", "red"]
    ].map(([label, value, icon, tone]) => ({
      label,
      value: value ?? 0,
      icon,
      cardClass: `analytics-stat ${tone}`
    }));
  }
  get reservationAnalytics() {
    const m = this.analytics?.reservationMetrics || {};
    return [
      ["Total Reservations", m.totalReservations, "▦", "blue"],
      ["Fulfilled", m.fulfilledReservations, "✓", "green"],
      ["Cancelled", m.cancelledReservations, "×", "purple"],
      ["Pending", m.pendingReservations, "◉", "gold"],
      ["Ready", m.readyReservations, "●", "cyan"],
      ["Expired", m.expiredReservations, "!", "red"]
    ].map(([label, value, icon, tone]) => ({
      label,
      value: value ?? 0,
      icon,
      cardClass: `analytics-stat ${tone}`
    }));
  }
  get fineAnalytics() {
    const m = this.analytics?.fineMetrics || {};
    return [
      ["Total Fine Count", m.totalFineCount, "₹", "orange"],
      ["Paid", m.paidFineCount, "✓", "green"],
      ["Unpaid", m.unpaidFineCount, "!", "red"]
    ].map(([label, value, icon, tone]) => ({
      label,
      value: value ?? 0,
      icon,
      cardClass: `analytics-stat ${tone}`
    }));
  }
  get activities() {
    return (this.dashboard.recentLoans || []).slice(0, 5).map((row) => ({
      id: row.Id,
      title: row.Status__c === "Returned" ? "Book returned" : "Book issued",
      detail: `${row.Book_Copy__r?.Book__r?.Name || row.Book_Copy__r?.Name || "Book"} — ${row.Member__r?.Name || "Member"}`,
      time: this.relativeDate(row.Return_Date__c || row.Borrow_Date__c),
      icon:
        row.Status__c === "Returned"
          ? "utility:check"
          : "utility:knowledge_base",
      tone:
        row.Status__c === "Returned"
          ? "activity-icon green"
          : "activity-icon blue"
    }));
  }
  get chartBars() {
    const today = new Date();
    const rows = this.dashboard.recentLoans || [];
    return Array.from({ length: 6 }, (_, index) => {
      const date = new Date(
        today.getFullYear(),
        today.getMonth() - 5 + index,
        1
      );
      const issued = rows.filter((r) =>
        this.sameMonth(r.Borrow_Date__c, date)
      ).length;
      const returned = rows.filter((r) =>
        this.sameMonth(r.Return_Date__c, date)
      ).length;
      const max = Math.max(...rows.map(() => 1), issued, returned, 1);
      return {
        label: date.toLocaleString("en", { month: "short" }),
        issuedStyle: `height:${24 + (issued / max) * 62}px`,
        returnedStyle: `height:${18 + (returned / max) * 62}px`
      };
    });
  }
  get isDashboard() {
    return this.section === "Dashboard";
  }
  get isLibrarianAssistant() {
    return this.section === "Librarian Assistant";
  }
  get assistantQuestions() {
    return [
      "Show overdue loans",
      "Show members with unpaid fines",
      "Find available copies of 1984",
      "Give me this member's borrowing history",
      "Show pending reservations",
      "Summarize today's library activity",
      "Which books have high demand?",
      "Which members have overdue books?"
    ];
  }
  get isBooks() {
    return this.section === "Books";
  }
  get isBookCopies() {
    return this.section === "Book Copies";
  }
  get isMembers() {
    return this.section === "Members";
  }
  get showMemberList() {
    return this.isMembers && !this.memberDetail;
  }
  get showMemberDetails() {
    return this.isMembers && Boolean(this.memberDetail);
  }
  get isRegistrations() {
    return this.section === "Registrations";
  }
  get isBorrowing() {
    return this.section === "Borrowing";
  }
  get isReservations() {
    return this.section === "Reservations";
  }
  get isFines() {
    return this.section === "Fines";
  }
  get isMemberships() {
    return this.section === "Memberships";
  }
  get isPlansTab() {
    return this.membershipTab === "Plans";
  }
  get isSubscriptionsTab() {
    return this.membershipTab === "Subscriptions";
  }
  get membershipTabs() {
    return ["Plans", "Subscriptions"].map((label) => ({
      label,
      value: label,
      className: `tab${this.membershipTab === label ? " active" : ""}`
    }));
  }
  get isPayments() {
    return this.section === "Payments";
  }
  get isReports() {
    return this.section === "Reports";
  }
  get isSettings() {
    return this.section === "Settings";
  }
  get isFirstBookPage() {
    return this.bookPage === 1;
  }
  get isFirstCopyPage() {
    return this.copyPage === 1;
  }
  get hasBooks() {
    return this.books.length > 0;
  }
  get hasCopies() {
    return this.copies.length > 0;
  }
  get hasMembers() {
    return this.members.length > 0;
  }
  get memberCount() {
    return this.allMembers.length;
  }
  get memberStart() {
    return this.memberCount
      ? (this.memberPage - 1) * this.memberPageSize + 1
      : 0;
  }
  get memberEnd() {
    return Math.min(this.memberPage * this.memberPageSize, this.memberCount);
  }
  get memberPageCount() {
    return Math.max(1, Math.ceil(this.memberCount / this.memberPageSize));
  }
  get isFirstMemberPage() {
    return this.memberPage === 1;
  }
  get isLastMemberPage() {
    return this.memberPage >= this.memberPageCount;
  }
  get hasRegistrations() {
    return this.registrations.length > 0;
  }
  get hasLoans() {
    return this.loans.length > 0;
  }
  get hasReservations() {
    return this.reservations.length > 0;
  }
  get hasFines() {
    return this.fines.length > 0;
  }
  get hasPlans() {
    return this.plans.length > 0;
  }
  get hasPayments() {
    return this.payments.length > 0;
  }
  get modalTitle() {
    return this.editingBook ? "Edit Book" : "Add New Book";
  }
  get bookSaveLabel() {
    return this.editingBook ? "Save Changes" : "Save Book";
  }
  get primaryAuthorId() {
    return this.selectedAuthorIds[0] || "";
  }
  get primaryCategoryId() {
    return this.selectedCategoryIds[0] || "";
  }
  get hasBookCover() {
    return Boolean(this.bookForm.coverUrl);
  }
  get copyModalTitle() {
    return this.selectedCopyId ? "Edit Book Copy" : "Add New Copy";
  }
  get memberModalTitle() {
    return this.editingMember ? "Edit Member" : "Add New Member";
  }
  get memberSaveLabel() {
    return this.editingMember ? "Save Changes" : "Add Member";
  }
  get planModalTitle() {
    return this.editingPlan ? "Edit Membership Plan" : "Add Membership Plan";
  }
  get planSaveLabel() {
    return this.editingPlan ? "Save Changes" : "Add Plan";
  }
  get canSuspendSelectedMember() {
    return this.memberDetail?.member?.Account_Status__c === "Active";
  }
  get canActivateSelectedMember() {
    return ["Suspended", "Inactive"].includes(
      this.memberDetail?.member?.Account_Status__c
    );
  }
  get memberOptions() {
    return this.allMembers.map((r) => ({
      label: `${r.fullName} (${r.Name})`,
      value: r.Id
    }));
  }
  get membershipPlanOptions() {
    return this.plans
      .filter((row) => row.Active__c)
      .map((row) => ({ label: row.Name, value: row.Id }));
  }
  get memberInitials() {
    const member = this.memberDetail?.member;
    return (
      [member?.First_Name__c, member?.Last_Name__c]
        .filter(Boolean)
        .map((part) => part[0])
        .join("")
        .toUpperCase() || "M"
    );
  }
  get selectedMemberName() {
    const member = this.memberDetail?.member;
    return [member?.First_Name__c, member?.Last_Name__c]
      .filter(Boolean)
      .join(" ");
  }
  get selectedMemberStatusClass() {
    return this.badge(this.memberDetail?.member?.Account_Status__c);
  }
  get activeMemberLoans() {
    return (this.memberDetail?.loans || []).filter((row) =>
      ["Active", "Overdue"].includes(row.Status__c)
    ).length;
  }
  get selectedMemberReservations() {
    return (this.memberDetail?.reservations || []).filter((row) =>
      ["Pending", "Ready"].includes(row.Status__c)
    ).length;
  }
  get selectedMemberOutstanding() {
    return this.currency(this.memberDetail?.outstandingBalance);
  }
  get selectedMemberBorrowed() {
    return (this.memberDetail?.loans || []).length;
  }
  get memberTabs() {
    return [
      "Overview",
      "Borrowing History",
      "Reservations",
      "Fines",
      "Payments",
      "Activity"
    ].map((label) => ({
      label,
      value: label,
      className: label === this.memberTab ? "member-tab active" : "member-tab"
    }));
  }
  get isMemberOverview() {
    return this.memberTab === "Overview";
  }
  get isMemberLoans() {
    return this.memberTab === "Borrowing History";
  }
  get isMemberReservations() {
    return this.memberTab === "Reservations";
  }
  get isMemberFines() {
    return this.memberTab === "Fines";
  }
  get isMemberPayments() {
    return this.memberTab === "Payments";
  }
  get isMemberActivity() {
    return this.memberTab === "Activity";
  }
  get bookOptions() {
    return this.books.map((r) => ({ label: r.Name, value: r.Id }));
  }
  get copyOptions() {
    return this.copies
      .filter((r) => r.Status__c === "Available")
      .map((r) => ({
        label: `${r.Name} · ${r.Barcode__c || r.Shelf_Location__c || "Available"}`,
        value: r.Id
      }));
  }
  get categoryFilterOptions() {
    return [{ label: "All", value: "" }, ...this.categoryOptions];
  }
  get allStatusOptions() {
    return [
      { label: "All", value: "" },
      { label: "Active", value: "Active" },
      { label: "Inactive", value: "Inactive" }
    ];
  }
  get memberStatusOptions() {
    return [
      { label: "All", value: "" },
      ...["Active", "Suspended", "Expired", "Closed"].map((value) => ({
        label: value,
        value
      }))
    ];
  }
  get copyStatusOptions() {
    return [
      { label: "All", value: "" },
      ...[
        "Available",
        "Borrowed",
        "Reserved",
        "Lost",
        "Damaged",
        "Maintenance",
        "Retired"
      ].map((value) => ({ label: value, value }))
    ];
  }
  get copyLocationOptions() {
    const locations = [
      ...new Set(
        this.allCopies.map((row) => row.Shelf_Location__c).filter(Boolean)
      )
    ].sort();
    return [
      { label: "All Locations", value: "" },
      ...locations.map((value) => ({ label: value, value }))
    ];
  }
  get registrationStatusOptions() {
    return ["Pending", "Approved", "Rejected"].map((value) => ({
      label: value,
      value
    }));
  }
  get registrationTabs() {
    return this.registrationStatusOptions.map((item) => ({
      ...item,
      label:
        item.value === "Pending"
          ? `Pending (${this.registrationCount("Pending")})`
          : item.label,
      className:
        item.value === this.registrationStatus
          ? "registration-tab active"
          : "registration-tab"
    }));
  }
  get loanStatusOptions() {
    return [
      { label: "All", value: "" },
      ...["Active", "Overdue", "Returned"].map((value) => ({
        label: value,
        value
      }))
    ];
  }
  get loanTabs() {
    return this.loanStatusOptions.slice(1).map((item) => ({
      ...item,
      className: item.value === this.loanStatus ? "tab active" : "tab"
    }));
  }
  get reservationStatusOptions() {
    return [
      { label: "All", value: "" },
      ...["Pending", "Ready", "Fulfilled", "Cancelled", "Expired"].map(
        (value) => ({ label: value, value })
      )
    ];
  }
  get reservationTabs() {
    return [
      ["Active Reservations", "Active"],
      ["Waiting List", "Waiting"],
      ["Fulfilled", "Fulfilled"],
      ["Cancelled", "Cancelled"]
    ].map(([label, value]) => ({
      label,
      value,
      className:
        value === this.reservationView
          ? "reservation-tab active"
          : "reservation-tab"
    }));
  }
  get fineStatusOptions() {
    return [
      { label: "All", value: "" },
      ...["Unpaid", "Partially Paid", "Paid", "Waived"].map((value) => ({
        label: value,
        value
      }))
    ];
  }
  get fineTabs() {
    return [
      { label: "Unpaid Fines", value: "Unpaid" },
      { label: "Paid Fines", value: "Paid" }
    ].map((item) => ({
      ...item,
      className: item.value === this.fineStatus ? "fine-tab active" : "fine-tab"
    }));
  }
  get paymentStatusOptions() {
    return [
      { label: "All", value: "" },
      { label: "Paid", value: "Paid" },
      { label: "Partially Paid", value: "Partially Paid" },
      { label: "Failed", value: "Failed" }
    ];
  }
  get paymentTypeOptions() {
    return [
      { label: "All", value: "" },
      { label: "Membership", value: "Membership" },
      { label: "Fine", value: "Fine" }
    ];
  }
  get paymentTabs() {
    return [
      { label: "All Payments", value: "" },
      { label: "Membership Payments", value: "Membership" },
      { label: "Fine Payments", value: "Fine" }
    ].map((item) => ({
      ...item,
      className: item.value === this.paymentType ? "tab active" : "tab"
    }));
  }

  selectSection(event) {
    this.section = event.currentTarget.dataset.section;
    if (this.section === "Members") this.memberDetail = undefined;
    this.sidebarOpen = false;
    const loaders = {
      Dashboard: () => this.loadDashboard(),
      "Librarian Assistant": () => undefined,
      Books: () => {
        this.loadBooks();
        this.loadReferenceData();
      },
      "Book Copies": () => {
        this.loadCopies();
        this.loadBooks();
      },
      Members: () => this.loadMembers(),
      Registrations: () => this.loadRegistrations(),
      Borrowing: () => {
        this.loadLoans();
        this.loadMembers();
        this.loadBooks();
        this.loadCopies();
      },
      Reservations: () => {
        this.loadReservations();
        this.loadMembers();
        this.loadBooks();
      },
      Fines: () => this.loadFines(),
      Memberships: () => Promise.all([this.loadPlans(), this.loadMembers()]),
      Payments: () => this.loadPayments(),
      Reports: () => this.loadDashboard(),
      Settings: () => Promise.all([this.loadPlans(), this.loadSettings()])
    };
    loaders[this.section]();
  }

  handleAssistantInput(event) {
    this.assistantInput = event.target.value;
  }

  useAssistantPrompt(event) {
    this.assistantInput = event.currentTarget.dataset.question;
    this.sendAssistantMessage();
  }

  async sendAssistantMessage(event) {
    event?.preventDefault();
    const question = this.assistantInput.trim();
    if (!question || this.assistantBusy) return;
    const stamp = Date.now();
    this.assistantMessages = [
      ...this.assistantMessages,
      {
        id: `question-${stamp}`,
        className: "lib-assistant-message lib-librarian-message-bubble",
        text: question
      }
    ];
    this.assistantInput = "";
    this.assistantBusy = true;
    try {
      if (!this.assistantSessionId) {
        const session = await startAgentSession();
        this.assistantSessionId = session.sessionId;
        this.assistantSequence = 0;
      }
      this.assistantSequence += 1;
      const response = await sendAgentMessage({
        sessionId: this.assistantSessionId,
        sequenceId: this.assistantSequence,
        text: question
      });
      this.assistantMessages = [
        ...this.assistantMessages,
        {
          id: `answer-${Date.now()}`,
          className: "lib-assistant-message lib-assistant-message-bubble",
          text: response.message
        }
      ];
    } catch {
      this.assistantMessages = [
        ...this.assistantMessages,
        {
          id: `error-${Date.now()}`,
          className: "lib-assistant-message lib-assistant-message-bubble",
          text: "The live assistant could not be opened. Please try again or contact an administrator."
        }
      ];
      this.assistantSessionId = undefined;
      this.assistantSequence = 0;
    } finally {
      this.assistantBusy = false;
    }
  }

  async clearAssistantChat() {
    if (this.assistantSessionId) {
      await endAgentSession({ sessionId: this.assistantSessionId }).catch(
        () => undefined
      );
    }
    this.assistantSessionId = undefined;
    this.assistantSequence = 0;
    this.assistantMessages = [];
  }

  openMetric(event) {
    this.selectSection({
      currentTarget: {
        dataset: { section: event.currentTarget.dataset.section }
      }
    });
  }
  toggleSidebar() {
    this.sidebarOpen = !this.sidebarOpen;
  }
  handleInput(event) {
    const name = event.target.name;
    const value = event.detail?.value ?? event.target.value;
    if (name.startsWith("book."))
      this.bookForm = { ...this.bookForm, [name.substring(5)]: value };
    else if (name.startsWith("copy."))
      this.copyForm = { ...this.copyForm, [name.substring(5)]: value };
    else if (name.startsWith("member."))
      this.memberForm = { ...this.memberForm, [name.substring(7)]: value };
    else if (name.startsWith("plan."))
      this.planForm = {
        ...this.planForm,
        [name.substring(5)]:
          event.target.type === "checkbox" ? event.target.checked : value
      };
    else if (name.startsWith("settings."))
      this.settings = {
        ...this.settings,
        [name.substring(9)]:
          event.target.type === "checkbox" ? event.target.checked : value
      };
    else this[name] = value;
  }
  handleGlobalSearch(event) {
    this.globalSearch = event.target.value;
  }
  toggleNotifications() {
    this.notificationsOpen = !this.notificationsOpen;
  }
  openNotification(event) {
    this.notificationsOpen = false;
    this.selectSection({
      currentTarget: {
        dataset: { section: event.currentTarget.dataset.section }
      }
    });
  }
  run(action, params, onSuccess) {
    this.loading = true;
    this.error = undefined;
    return action(params)
      .then(onSuccess)
      .catch((error) => this.handleError(error))
      .finally(() => {
        this.loading = false;
      });
  }
  loadDashboard() {
    return this.run(
      () => Promise.all([getDashboard(), getDashboardAnalytics()]),
      null,
      ([dashboard, analytics]) => {
        this.dashboard = dashboard || { recentLoans: [] };
        this.analytics = analytics || {
          available: false,
          topBorrowedBooks: [],
          reservationDemand: []
        };
      }
    );
  }
  loadReferenceData() {
    return Promise.all([getAuthors(), getCategories()])
      .then(([authors, categories]) => {
        this.authorOptions = (authors || []).map((r) => ({
          label: r.Name,
          value: r.Id
        }));
        this.categoryOptions = (categories || []).map((r) => ({
          label: r.Name,
          value: r.Id
        }));
      })
      .catch((e) => this.handleError(e));
  }
  loadBooks() {
    return this.run(
      searchBooks,
      {
        searchTerm: this.bookSearch,
        categoryId: this.bookCategory || null,
        status: this.bookStatus || null,
        pageSize: this.pageSize,
        pageNumber: this.bookPage
      },
      (data) => {
        this.books = (data || []).map((r) => ({
          ...r,
          authorNames:
            (r.Book_Authors__r || [])
              .map((x) => x.Author__r?.Name)
              .join(", ") || "—",
          categoryNames:
            (r.Book_Category_Links__r || [])
              .map((x) => x.Book_Category__r?.Name)
              .join(", ") || "—",
          statusClass: this.badge(r.Status__c)
        }));
      }
    );
  }
  loadCopies() {
    return this.run(
      searchCopies,
      {
        searchTerm: this.copySearch,
        status: this.copyStatus || null,
        bookId: this.selectedBookId || null,
        pageSize: 11,
        pageNumber: this.copyPage
      },
      (data) => {
        const rows = data || [];
        this.copyHasNext = rows.length > 10;
        this.allCopies = rows.slice(0, 10).map((r) => ({
          ...r,
          bookName: r.Book__r?.Name || "—",
          statusClass: this.badge(r.Status__c)
        }));
        this.applyCopyLocationFilter();
      }
    );
  }
  applyCopyLocationFilter() {
    this.copies = this.copyLocation
      ? this.allCopies.filter(
          (row) => row.Shelf_Location__c === this.copyLocation
        )
      : [...this.allCopies];
  }
  loadMembers() {
    return this.run(
      searchMembers,
      { searchTerm: this.memberSearch, status: this.memberStatus || null },
      (data) => {
        this.allMembers = (data || []).map((r) => ({
          ...r,
          fullName: [r.First_Name__c, r.Last_Name__c].filter(Boolean).join(" "),
          planName: r.Membership_Plan__r?.Name || "—",
          statusClass: this.badge(r.Status__c)
        }));
        this.memberPage = 1;
        this.paginateMembers();
      }
    );
  }
  paginateMembers() {
    const start = (this.memberPage - 1) * this.memberPageSize;
    this.members = this.allMembers.slice(start, start + this.memberPageSize);
  }
  loadRegistrations() {
    return this.run(getRegistrations, { status: null }, (data) => {
      this.allRegistrations = (data || []).map((r) => ({
        ...r,
        applicant: [r.First_Name__c, r.Last_Name__c].filter(Boolean).join(" "),
        planName: r.Requested_Plan__r?.Name || "—",
        statusClass: this.badge(r.Status__c),
        canDecide: r.Status__c === "Pending"
      }));
      this.applyRegistrationFilter();
    });
  }
  registrationCount(status) {
    return this.allRegistrations.filter((row) => row.Status__c === status)
      .length;
  }
  applyRegistrationFilter() {
    this.registrations = this.allRegistrations.filter(
      (row) => row.Status__c === this.registrationStatus
    );
  }
  loadLoans() {
    return this.run(getLoans, { status: this.loanStatus || null }, (data) => {
      this.loans = (data || []).map((r) => ({
        ...r,
        memberName: r.Member__r?.Name || "—",
        bookName: r.Book_Copy__r?.Book__r?.Name || "—",
        copyName: r.Book_Copy__r?.Name || "—",
        statusClass: this.badge(r.Status__c),
        canAct: !["Returned"].includes(r.Status__c)
      }));
    });
  }
  loadReservations() {
    return this.run(getReservations, { status: null }, (data) => {
      this.allReservations = (data || []).map((r) => ({
        ...r,
        memberName: r.Member__r?.Name || "—",
        bookName: r.Book__r?.Name || "—",
        displayStatus: r.Status__c === "Pending" ? "Waiting" : r.Status__c,
        statusClass: this.badge(
          r.Status__c === "Pending" ? "Waiting" : r.Status__c
        ),
        queuePosition: r.Queue_Position__c || "–",
        canIssue: r.Status__c === "Ready" && Boolean(r.Book_Copy__c),
        canPrepare: r.Status__c === "Pending",
        canCancel: !["Cancelled", "Fulfilled", "Expired"].includes(r.Status__c)
      }));
      this.applyReservationFilters();
    });
  }
  applyReservationFilters() {
    const search = this.reservationSearch.trim().toLowerCase();
    this.reservations = this.allReservations.filter((row) => {
      const statusMatches =
        this.reservationView === "Active"
          ? ["Pending", "Ready"].includes(row.Status__c)
          : this.reservationView === "Waiting"
            ? row.Status__c === "Pending"
            : row.Status__c === this.reservationView;
      const searchMatches =
        !search ||
        row.memberName.toLowerCase().includes(search) ||
        row.bookName.toLowerCase().includes(search) ||
        String(row.Name || "")
          .toLowerCase()
          .includes(search);
      return statusMatches && searchMatches;
    });
  }
  loadFines() {
    return this.run(getFines, { status: null }, (data) => {
      this.allFines = (data || []).map((r) => ({
        ...r,
        memberName: r.Member__r?.Name || "—",
        loanName: r.Borrow_Record__r?.Name || "—",
        statusClass: this.badge(r.Status__c),
        amountLabel: this.currency(r.Balance__c ?? r.Amount__c),
        reasonLabel:
          r.Fine_Type__c === "Overdue"
            ? "Overdue book"
            : r.Fine_Type__c === "Lost"
              ? "Lost book"
              : r.Fine_Type__c,
        canCollect: ["Unpaid", "Partially Paid"].includes(r.Status__c)
      }));
      this.applyFineFilters();
    });
  }
  applyFineFilters() {
    const search = this.fineSearch.trim().toLowerCase();
    this.fines = this.allFines.filter((row) => {
      const statusMatches =
        this.fineStatus === "Unpaid"
          ? ["Unpaid", "Partially Paid"].includes(row.Status__c)
          : row.Status__c === "Paid";
      const searchMatches =
        !search ||
        row.memberName.toLowerCase().includes(search) ||
        row.loanName.toLowerCase().includes(search) ||
        String(row.Name || "")
          .toLowerCase()
          .includes(search);
      return statusMatches && searchMatches;
    });
  }
  loadPlans() {
    return this.run(getMembershipPlans, {}, (data) => {
      this.plans = (data || []).map((r) => ({
        ...r,
        durationLabel: this.durationLabel(r.Duration_Days__c),
        borrowLimitLabel: `${r.Borrow_Limit__c || 0} books`,
        priceLabel:
          Number(r.Fee__c || 0) === 0 ? "Free" : this.currency(r.Fee__c),
        statusLabel: r.Active__c ? "Active" : "Inactive",
        statusClass: this.badge(r.Active__c ? "Active" : "Inactive")
      }));
    });
  }
  loadPayments() {
    return this.run(getPayments, { status: null }, (data) => {
      this.allPayments = (data || [])
        .map((r) => ({
          ...r,
          displayDate: r.paymentDate
            ? new Intl.DateTimeFormat("en-GB", {
                day: "numeric",
                month: "short",
                year: "numeric"
              }).format(new Date(r.paymentDate))
            : "—",
          amountLabel: this.currency(r.amount),
          statusClass: this.badge(r.status)
        }))
        .sort(
          (a, b) => new Date(b.paymentDate || 0) - new Date(a.paymentDate || 0)
        );
      this.applyPaymentFilters();
    });
  }
  loadSettings() {
    return this.run(getLibrarySettings, {}, (data) => {
      this.settings = {
        id: data?.Id || null,
        libraryName: data?.Library_Name__c || "Library Management",
        contactEmail: data?.Contact_Email__c || "",
        defaultShelfPrefix: data?.Default_Shelf_Prefix__c || "Shelf",
        reservationHoldDays: data?.Reservation_Hold_Days__c ?? 3,
        dueReminderDays: data?.Due_Reminder_Days__c ?? 3,
        maxSearchResults: data?.Max_Search_Results__c ?? 200,
        sendDueReminders: data?.Send_Due_Reminders__c ?? true,
        sendOverdueNotices: data?.Send_Overdue_Notices__c ?? true,
        sendReservationNotifications:
          data?.Send_Reservation_Notifications__c ?? true,
        allowSelfRegistration: data?.Allow_Self_Registration__c ?? true,
        requireEmailVerification: data?.Require_Email_Verification__c ?? true,
        autoProcessExpiredHolds: data?.Auto_Process_Expired_Holds__c ?? true,
        finePaymentEnabled: data?.Fine_Payment_Enabled__c ?? true
      };
    });
  }
  applyPaymentFilters() {
    const search = this.paymentSearch.trim().toLowerCase();
    this.payments = this.allPayments.filter((row) => {
      const typeMatches =
        !this.paymentType || row.paymentType === this.paymentType;
      const statusMatches =
        !this.paymentStatus || row.status === this.paymentStatus;
      const searchMatches =
        !search ||
        String(row.name || "")
          .toLowerCase()
          .includes(search) ||
        String(row.memberName || "")
          .toLowerCase()
          .includes(search);
      return typeMatches && statusMatches && searchMatches;
    });
  }
  searchBooksNow() {
    this.bookPage = 1;
    this.loadBooks();
  }
  searchCopiesNow() {
    this.copyPage = 1;
    this.loadCopies();
  }
  filterCopyLocation(event) {
    this.copyLocation = event.detail.value;
    this.applyCopyLocationFilter();
  }
  searchMembersNow() {
    this.memberPage = 1;
    return this.loadMembers();
  }
  filterRegistrations(event) {
    if (event?.currentTarget?.dataset?.value !== undefined)
      this.registrationStatus = event.currentTarget.dataset.value;
    this.applyRegistrationFilter();
  }
  filterLoans(event) {
    if (event?.currentTarget?.dataset?.value !== undefined)
      this.loanStatus = event.currentTarget.dataset.value;
    this.loadLoans();
  }
  filterReservations(event) {
    if (event?.currentTarget?.dataset?.value)
      this.reservationView = event.currentTarget.dataset.value;
    this.applyReservationFilters();
  }
  handleReservationSearch(event) {
    this.reservationSearch = event.target.value;
    this.applyReservationFilters();
  }
  filterFines(event) {
    if (event?.currentTarget?.dataset?.value)
      this.fineStatus = event.currentTarget.dataset.value;
    this.applyFineFilters();
  }
  handleFineSearch(event) {
    this.fineSearch = event.target.value;
    this.applyFineFilters();
  }
  filterPayments(event) {
    if (event?.currentTarget?.dataset?.value !== undefined)
      this.paymentType = event.currentTarget.dataset.value;
    this.applyPaymentFilters();
  }
  handlePaymentFilter(event) {
    this[event.target.name] = event.detail?.value ?? event.target.value;
    this.applyPaymentFilters();
  }
  handlePaymentSearch(event) {
    this.paymentSearch = event.target.value;
    this.applyPaymentFilters();
  }
  viewPayment(event) {
    this.selectedPayment = this.allPayments.find(
      (row) => row.id === event.currentTarget.dataset.id
    );
    this.showPaymentModal = Boolean(this.selectedPayment);
  }
  previousBooks() {
    if (this.bookPage > 1) {
      this.bookPage -= 1;
      this.loadBooks();
    }
  }
  nextBooks() {
    if (this.books.length === this.pageSize) {
      this.bookPage += 1;
      this.loadBooks();
    }
  }
  previousCopies() {
    if (this.copyPage > 1) {
      this.copyPage -= 1;
      this.loadCopies();
    }
  }
  nextCopies() {
    if (this.copyHasNext) {
      this.copyPage += 1;
      this.loadCopies();
    }
  }
  selectBorrowBook(event) {
    this.selectedBookId = event.detail.value;
    this.copyPage = 1;
    this.loadCopies();
  }
  selectCopy(event) {
    this.selectedCopyId = event.currentTarget.dataset.id;
  }

  openAddBook() {
    this.editingBook = false;
    this.bookForm = this.emptyBook();
    this.selectedAuthorIds = [];
    this.selectedCategoryIds = [];
    this.loadReferenceData();
    this.showBookModal = true;
  }
  openEditBook(event) {
    const id = event?.currentTarget?.dataset?.id || this.bookDetail?.Id;
    if (!id) return;
    this.run(getBookDetail, { bookId: id }, (book) => {
      this.editingBook = true;
      this.selectedBookId = id;
      this.bookDetail = book;
      this.bookForm = {
        title: book.Name,
        isbn: book.ISBN__c,
        publisher: book.Publisher__c,
        publicationYear: book.Publication_Year__c,
        edition: book.Edition__c,
        language: book.Language__c,
        description: book.Description__c,
        coverUrl: book.Cover_Image_URL__c
      };
      this.selectedAuthorIds = (book.Book_Authors__r || []).map(
        (r) => r.Author__c
      );
      this.selectedCategoryIds = (book.Book_Category_Links__r || []).map(
        (r) => r.Book_Category__c
      );
      this.loadReferenceData();
      this.showBookDetail = false;
      this.showBookModal = true;
    });
  }
  viewBook(event) {
    return this.run(
      getBookDetail,
      { bookId: event.currentTarget.dataset.id },
      (book) => {
        this.bookDetail = book;
        this.showBookDetail = true;
      }
    );
  }
  handleAuthorSelect(event) {
    this.selectedAuthorIds = event.detail.value;
  }
  handleCategorySelect(event) {
    this.selectedCategoryIds = event.detail.value;
  }
  handlePrimaryAuthor(event) {
    this.selectedAuthorIds = event.detail.value ? [event.detail.value] : [];
  }
  handlePrimaryCategory(event) {
    this.selectedCategoryIds = event.detail.value ? [event.detail.value] : [];
  }
  focusCoverUrl() {
    this.template.querySelector(".cover-url")?.focus();
  }
  validate(selector) {
    return [...this.template.querySelectorAll(selector)].reduce(
      (valid, field) => {
        field.reportValidity();
        return valid && field.checkValidity();
      },
      true
    );
  }
  saveBook() {
    if (!this.validate(".book-field")) return Promise.resolve();
    const params = {
      ...this.bookForm,
      bookId: this.editingBook ? this.selectedBookId : null,
      authorIds: this.selectedAuthorIds,
      categoryIds: this.selectedCategoryIds
    };
    return this.run(this.editingBook ? updateBook : addBook, params, () => {
      this.closeModals();
      this.toast(
        "Book saved",
        "The catalog record was saved successfully.",
        "success"
      );
      return Promise.all([this.loadBooks(), this.loadDashboard()]);
    });
  }
  openAddCopy(event) {
    this.selectedBookId =
      event?.currentTarget?.dataset?.id || this.bookDetail?.Id || undefined;
    if (!this.books.length) this.loadBooks();
    this.selectedCopyId = undefined;
    this.copyForm = this.emptyCopy();
    this.showBookDetail = false;
    this.showCopyModal = true;
  }
  openEditCopy(event) {
    const row =
      this.copies.find((r) => r.Id === event.currentTarget.dataset.id) ||
      (this.bookDetail?.Book_Copies__r || []).find(
        (r) => r.Id === event.currentTarget.dataset.id
      );
    if (!row) return;
    this.selectedCopyId = row.Id;
    this.selectedBookId = row.Book__c || this.bookDetail?.Id;
    this.copyForm = {
      barcode: row.Barcode__c,
      shelf: row.Shelf_Location__c,
      acquisitionDate: row.Acquisition_Date__c,
      condition: row.Condition__c,
      price: row.Price__c,
      status: row.Status__c
    };
    this.showBookDetail = false;
    this.showCopyModal = true;
  }
  saveCopy() {
    if (!this.validate(".copy-field")) return Promise.resolve();
    const promise = this.selectedCopyId
      ? updateCopy({
          copyId: this.selectedCopyId,
          shelf: this.copyForm.shelf,
          acquisitionDate: this.copyForm.acquisitionDate,
          condition: this.copyForm.condition,
          price: this.copyForm.price,
          status: this.copyForm.status
        })
      : addCopy({
          bookId: this.selectedBookId,
          barcode: this.copyForm.barcode,
          shelf: this.copyForm.shelf,
          acquisitionDate: this.copyForm.acquisitionDate,
          condition: this.copyForm.condition,
          price: this.copyForm.price
        });
    this.loading = true;
    return promise
      .then(() => {
        this.closeModals();
        this.toast(
          "Copy saved",
          "Inventory was updated successfully.",
          "success"
        );
        return Promise.all([
          this.loadCopies(),
          this.loadBooks(),
          this.loadDashboard()
        ]);
      })
      .catch((e) => this.handleError(e))
      .finally(() => {
        this.loading = false;
      });
  }
  closeModals() {
    this.showBookModal = false;
    this.showBookDetail = false;
    this.showCopyModal = false;
    this.showMemberModal = false;
    this.showRegistrationModal = false;
    this.showReservationModal = false;
    this.showFineModal = false;
    this.showPlanModal = false;
    this.showPaymentModal = false;
  }

  selectMembershipTab(event) {
    this.membershipTab = event.currentTarget.dataset.value;
  }
  openAddPlan() {
    this.editingPlan = false;
    this.planForm = this.emptyPlan();
    this.showPlanModal = true;
  }
  openEditPlan(event) {
    const plan = this.plans.find(
      (row) => row.Id === event.currentTarget.dataset.id
    );
    if (!plan) return;
    this.editingPlan = true;
    this.planForm = {
      id: plan.Id,
      name: plan.Name || "",
      description: plan.Description__c || "",
      durationDays: plan.Duration_Days__c,
      borrowLimit: plan.Borrow_Limit__c,
      loanDurationDays: plan.Loan_Duration_Days__c,
      reservationLimit: plan.Reservation_Limit__c,
      renewalLimit: plan.Renewal_Limit__c,
      finePerDay: plan.Fine_Per_Day__c,
      fee: plan.Fee__c,
      active: plan.Active__c
    };
    this.showPlanModal = true;
  }
  savePlan() {
    if (!this.validate(".plan-field")) return Promise.resolve();
    const numberOrNull = (value) => {
      return value === "" || value === null || value === undefined
        ? null
        : Number(value);
    };
    return this.run(
      saveMembershipPlan,
      {
        planId: this.planForm.id,
        name: this.planForm.name,
        description: this.planForm.description,
        durationDays: numberOrNull(this.planForm.durationDays),
        borrowLimit: numberOrNull(this.planForm.borrowLimit),
        loanDurationDays: numberOrNull(this.planForm.loanDurationDays),
        reservationLimit: numberOrNull(this.planForm.reservationLimit),
        renewalLimit: numberOrNull(this.planForm.renewalLimit),
        finePerDay: numberOrNull(this.planForm.finePerDay),
        fee: numberOrNull(this.planForm.fee),
        active: this.planForm.active
      },
      () => {
        this.showPlanModal = false;
        this.toast(
          "Membership plan saved",
          "The plan is now available in the membership catalog.",
          "success"
        );
        return this.loadPlans();
      }
    );
  }
  previousMembers() {
    if (this.memberPage > 1) {
      this.memberPage -= 1;
      this.paginateMembers();
    }
  }
  nextMembers() {
    if (this.memberPage < this.memberPageCount) {
      this.memberPage += 1;
      this.paginateMembers();
    }
  }
  openAddMember() {
    this.editingMember = false;
    this.memberForm = this.emptyMember();
    this.showMemberModal = true;
    if (!this.plans.length) this.loadPlans();
  }
  openEditMember() {
    const member = this.memberDetail?.member;
    if (!member) return;
    this.editingMember = true;
    this.memberForm = {
      id: member.Id,
      firstName: member.First_Name__c || "",
      lastName: member.Last_Name__c || "",
      email: member.Email__c || "",
      phone: member.Phone__c || "",
      planId: member.Membership_Plan__c || ""
    };
    this.showMemberModal = true;
    if (!this.plans.length) this.loadPlans();
  }
  saveMember() {
    const fields = this.template.querySelectorAll(".member-field");
    if ([...fields].some((field) => !field.reportValidity()))
      return Promise.resolve();
    const params = {
      firstName: this.memberForm.firstName,
      lastName: this.memberForm.lastName,
      email: this.memberForm.email,
      phone: this.memberForm.phone,
      planId: this.memberForm.planId
    };
    const request = this.editingMember
      ? updateMember({ memberId: this.memberForm.id, ...params })
      : addMember(params);
    this.loading = true;
    return request
      .then((memberId) => {
        const selectedId = memberId || this.memberForm.id;
        this.showMemberModal = false;
        this.toast(
          "Member saved",
          "Member information was updated.",
          "success"
        );
        return Promise.all([this.loadMembers(), this.loadDashboard()]).then(
          () => {
            if (this.editingMember && selectedId) {
              return this.run(
                getMemberDetail,
                { memberId: selectedId },
                (data) => {
                  this.memberDetail = data;
                }
              );
            }
            return undefined;
          }
        );
      })
      .catch((error) => this.handleError(error))
      .finally(() => {
        this.loading = false;
      });
  }
  viewMember(event) {
    return this.run(
      getMemberDetail,
      { memberId: event.currentTarget.dataset.id },
      (data) => {
        this.memberDetail = data;
        this.memberTab = "Overview";
      }
    );
  }
  closeMemberDetail() {
    this.memberDetail = undefined;
  }
  updateMemberAccountStatus(event) {
    const memberId = this.memberDetail?.member?.Id;
    const accountStatus = event.currentTarget.dataset.status;
    return this.run(setMemberAccountStatus, { memberId, accountStatus }, () => {
      this.toast(
        "Member updated",
        `Portal access is now ${accountStatus}.`,
        "success"
      );
      return this.run(getMemberDetail, { memberId }, (data) => {
        this.memberDetail = data;
      });
    });
  }
  selectMemberTab(event) {
    this.memberTab = event.currentTarget.dataset.value;
  }
  renewSelectedMember() {
    const memberId = this.memberDetail?.member?.Id;
    return this.run(renewMemberMembership, { memberId }, () => {
      this.toast(
        "Membership renewed",
        "The membership dates were extended.",
        "success"
      );
      return this.run(getMemberDetail, { memberId }, (data) => {
        this.memberDetail = data;
      });
    });
  }
  resetSelectedMemberPassword() {
    const memberId = this.memberDetail?.member?.Id;
    return this.run(resetMemberPassword, { memberId }, () => {
      this.toast(
        "Password reset sent",
        "A reset email was sent to the member.",
        "success"
      );
    });
  }
  doCheckout() {
    if (!this.selectedMemberId || !this.selectedCopyId) {
      this.toast(
        "Missing selection",
        "Select a member and an available copy.",
        "error"
      );
      return Promise.resolve();
    }
    return this.run(
      checkout,
      { memberId: this.selectedMemberId, copyId: this.selectedCopyId },
      () => {
        this.toast(
          "Book issued",
          "The borrowing transaction is active.",
          "success"
        );
        return Promise.all([
          this.loadLoans(),
          this.loadCopies(),
          this.loadDashboard()
        ]);
      }
    );
  }
  doReturn(event) {
    return this.run(
      returnLoan,
      { loanId: event.currentTarget.dataset.id },
      () => {
        this.toast(
          "Book returned",
          "Return and fine rules were applied.",
          "success"
        );
        return Promise.all([
          this.loadLoans(),
          this.loadDashboard(),
          this.loadFines()
        ]);
      }
    );
  }
  doRenew(event) {
    return this.run(
      renewLoan,
      { loanId: event.currentTarget.dataset.id },
      () => {
        this.toast("Loan renewed", "The due date was updated.", "success");
        return Promise.all([this.loadLoans(), this.loadDashboard()]);
      }
    );
  }
  registrationAction(event) {
    const registrationId = event.currentTarget.dataset.id;
    const type = event.currentTarget.dataset.action;
    const action =
      type === "approve"
        ? approveRegistration
        : type === "reject"
          ? rejectRegistration
          : retryProvisioning;
    const params =
      type === "reject"
        ? {
            registrationId,
            reason: this.rejectReason || "Rejected by librarian."
          }
        : { registrationId };
    return this.run(action, params, () => {
      this.toast(
        "Registration updated",
        "The onboarding workflow completed the action.",
        "success"
      );
      return Promise.all([this.loadRegistrations(), this.loadDashboard()]);
    });
  }
  viewRegistration(event) {
    this.selectedRegistration = this.allRegistrations.find(
      (row) => row.Id === event.currentTarget.dataset.id
    );
    this.showRegistrationModal = Boolean(this.selectedRegistration);
  }
  createReservationNow() {
    if (!this.reservationMemberId || !this.reservationBookId) {
      this.toast("Missing selection", "Select a member and a book.", "error");
      return Promise.resolve();
    }
    return this.run(
      createReservation,
      { memberId: this.reservationMemberId, bookId: this.reservationBookId },
      () => {
        this.toast(
          "Reservation created",
          "The queue position was calculated.",
          "success"
        );
        return Promise.all([this.loadReservations(), this.loadDashboard()]);
      }
    );
  }
  cancelReservationNow(event) {
    return this.run(
      cancelReservation,
      { reservationId: event.currentTarget.dataset.id },
      () => {
        this.showReservationModal = false;
        this.toast(
          "Reservation cancelled",
          "The hold was cancelled.",
          "success"
        );
        return Promise.all([this.loadReservations(), this.loadDashboard()]);
      }
    );
  }
  viewReservation(event) {
    this.selectedReservation = this.allReservations.find(
      (row) => row.Id === event.currentTarget.dataset.id
    );
    this.showReservationModal = Boolean(this.selectedReservation);
  }
  issueReadyReservation() {
    const reservationId = this.selectedReservation?.Id;
    return this.run(issueReservedBook, { reservationId }, () => {
      this.showReservationModal = false;
      this.toast(
        "Book issued",
        "The reservation is fulfilled and the borrowing transaction is active.",
        "success"
      );
      return Promise.all([
        this.loadReservations(),
        this.loadLoans(),
        this.loadDashboard()
      ]);
    });
  }
  prepareSelectedReservation() {
    const reservationId = this.selectedReservation?.Id;
    return this.run(prepareReservation, { reservationId }, (isReady) => {
      this.showReservationModal = false;
      this.toast(
        isReady ? "Reservation ready" : "Queue updated",
        isReady
          ? "An available copy was assigned. The reservation can now be issued."
          : "Available copies were assigned in queue order; this reservation is still waiting.",
        isReady ? "success" : "info"
      );
      return this.loadReservations();
    });
  }
  processExpired() {
    return this.run(processExpiredReservations, {}, (count) => {
      this.toast(
        "Expired holds processed",
        `${count} reservation(s) updated.`,
        "success"
      );
      return Promise.all([this.loadReservations(), this.loadDashboard()]);
    });
  }
  saveSettings() {
    if (!this.validate(".settings-field")) return Promise.resolve();
    const numeric = (value) => Number(value);
    return this.run(
      saveLibrarySettings,
      {
        settingsId: this.settings.id,
        libraryName: this.settings.libraryName,
        contactEmail: this.settings.contactEmail,
        defaultShelfPrefix: this.settings.defaultShelfPrefix,
        reservationHoldDays: numeric(this.settings.reservationHoldDays),
        dueReminderDays: numeric(this.settings.dueReminderDays),
        maxSearchResults: numeric(this.settings.maxSearchResults),
        sendDueReminders: this.settings.sendDueReminders,
        sendOverdueNotices: this.settings.sendOverdueNotices,
        sendReservationNotifications:
          this.settings.sendReservationNotifications,
        allowSelfRegistration: this.settings.allowSelfRegistration,
        requireEmailVerification: this.settings.requireEmailVerification,
        autoProcessExpiredHolds: this.settings.autoProcessExpiredHolds,
        finePaymentEnabled: this.settings.finePaymentEnabled
      },
      (settingsId) => {
        this.settings = { ...this.settings, id: settingsId };
        this.toast(
          "Settings saved",
          "The librarian configuration was saved successfully.",
          "success"
        );
      }
    );
  }
  openSettingsSection(event) {
    this.selectSection({
      currentTarget: {
        dataset: { section: event.currentTarget.dataset.section }
      }
    });
  }
  selectFine(event) {
    this.selectedFineId = event.currentTarget.dataset.id;
    this.selectedFine = this.allFines.find(
      (row) => row.Id === this.selectedFineId
    );
    this.paymentAmount = this.selectedFine?.Balance__c;
    this.waiverReason = "";
    this.showFineModal = Boolean(this.selectedFine);
  }
  payFine() {
    if (!this.selectedFineId || !this.paymentAmount) {
      this.toast(
        "Missing payment",
        "Select a fine and enter an amount.",
        "error"
      );
      return Promise.resolve();
    }
    return this.run(
      recordFinePayment,
      { fineId: this.selectedFineId, amount: Number(this.paymentAmount) },
      () => {
        this.showFineModal = false;
        this.toast(
          "Payment recorded",
          "The fine balance was updated.",
          "success"
        );
        return Promise.all([this.loadFines(), this.loadDashboard()]);
      }
    );
  }
  waiveSelectedFine() {
    if (!this.selectedFineId) {
      this.toast("Select a fine", "Choose a fine before waiving it.", "error");
      return Promise.resolve();
    }
    return this.run(
      waiveFine,
      {
        fineId: this.selectedFineId,
        reason: this.waiverReason || "Waived by librarian."
      },
      () => {
        this.showFineModal = false;
        this.toast("Fine waived", "The waiver was recorded.", "success");
        return Promise.all([this.loadFines(), this.loadDashboard()]);
      }
    );
  }
  exportBooks() {
    const header = [
      "Title",
      "Author",
      "Category",
      "ISBN",
      "Total Copies",
      "Available",
      "Status"
    ];
    const rows = this.books.map((r) => [
      r.Name,
      r.authorNames,
      r.categoryNames,
      r.ISBN__c,
      r.Total_Copies__c,
      r.Available_Copies__c,
      r.Status__c
    ]);
    this.downloadCsv("library-books.csv", [header, ...rows]);
  }
  handleImport(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const lines = String(reader.result)
          .split(/\r?\n/)
          .slice(1)
          .filter(Boolean);
        const imports = lines.map((line) => {
          const [title, isbn, publisher, publicationYear] = line
            .split(",")
            .map((v) => v.trim());
          if (!title) return Promise.resolve();
          return addBook({
            title,
            isbn,
            publisher,
            publicationYear: publicationYear ? Number(publicationYear) : null,
            edition: "",
            language: "",
            description: "",
            coverUrl: "",
            authorIds: [],
            categoryIds: []
          });
        });
        await Promise.all(imports);
        this.toast(
          "Import complete",
          `${lines.length} book row(s) processed.`,
          "success"
        );
        await this.loadBooks();
      } catch (e) {
        this.handleError(e);
      }
    };
    reader.readAsText(file);
  }
  downloadCsv(name, rows) {
    const csv = rows
      .map((row) =>
        row.map((v) => `"${String(v ?? "").replaceAll('"', '""')}"`).join(",")
      )
      .join("\n");
    const anchor = document.createElement("a");
    anchor.href = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
    anchor.download = name;
    anchor.click();
  }
  emptyBook() {
    return {
      title: "",
      isbn: "",
      publisher: "",
      publicationYear: null,
      edition: "",
      language: "",
      description: "",
      coverUrl: ""
    };
  }
  emptyCopy() {
    return {
      barcode: "",
      shelf: "",
      acquisitionDate: null,
      condition: "Good",
      price: null,
      status: "Available"
    };
  }
  emptyMember() {
    return {
      id: null,
      firstName: "",
      lastName: "",
      email: "",
      phone: "",
      planId: ""
    };
  }
  emptyPlan() {
    return {
      id: null,
      name: "",
      description: "",
      durationDays: 365,
      borrowLimit: 5,
      loanDurationDays: 14,
      reservationLimit: 3,
      renewalLimit: 1,
      finePerDay: 10,
      fee: 0,
      active: true
    };
  }
  defaultSettings() {
    return {
      id: null,
      libraryName: "Library Management",
      contactEmail: "",
      defaultShelfPrefix: "Shelf",
      reservationHoldDays: 3,
      dueReminderDays: 3,
      maxSearchResults: 200,
      sendDueReminders: true,
      sendOverdueNotices: true,
      sendReservationNotifications: true,
      allowSelfRegistration: true,
      requireEmailVerification: true,
      autoProcessExpiredHolds: true,
      finePaymentEnabled: true
    };
  }
  badge(value) {
    const normalized = String(value || "")
      .toLowerCase()
      .replaceAll(" ", "-");
    return `badge badge-${normalized}`;
  }
  currency(value) {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0
    }).format(value || 0);
  }
  durationLabel(value) {
    const days = Number(value || 0);
    if (days > 0 && days % 365 === 0) {
      const years = days / 365;
      return `${years} ${years === 1 ? "Year" : "Years"}`;
    }
    if (days > 0 && days % 30 === 0) {
      const months = days / 30;
      return `${months} ${months === 1 ? "Month" : "Months"}`;
    }
    return `${days} ${days === 1 ? "Day" : "Days"}`;
  }
  sameMonth(value, date) {
    if (!value) return false;
    const item = new Date(value);
    return (
      item.getMonth() === date.getMonth() &&
      item.getFullYear() === date.getFullYear()
    );
  }
  relativeDate(value) {
    if (!value) return "Recently";
    const hours = Math.max(
      1,
      Math.round((Date.now() - new Date(value).getTime()) / 3600000)
    );
    return hours < 24
      ? `${hours} hours ago`
      : `${Math.round(hours / 24)} days ago`;
  }
  handleError(error) {
    this.error =
      error?.body?.message ||
      error?.message ||
      "The operation could not be completed.";
    this.toast("Library operation failed", this.error, "error");
  }
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
