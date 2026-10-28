import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentMemberContext from "@salesforce/apex/LibraryMemberSessionController.getCurrentMemberContext";
import getMyDashboard from "@salesforce/apex/LibraryMemberSessionController.getMyDashboard";
import getMyAnalytics from "@salesforce/apex/LibraryMemberSessionController.getMyAnalytics";
import getSuggestedBooks from "@salesforce/apex/LibraryMemberSessionController.getSuggestedBooks";
import searchCatalog from "@salesforce/apex/LibraryMemberSessionController.searchCatalog";
import getCatalogCategories from "@salesforce/apex/LibraryMemberSessionController.getCatalogCategories";
import getBookDetails from "@salesforce/apex/LibraryMemberSessionController.getBookDetails";
import borrowBook from "@salesforce/apex/LibraryMemberSessionController.borrowBook";
import getMyBorrowings from "@salesforce/apex/LibraryMemberSessionController.getMyBorrowings";
import renewMyLoan from "@salesforce/apex/LibraryMemberSessionController.renewMyLoan";
import getMyReservations from "@salesforce/apex/LibraryMemberSessionController.getMyReservations";
import reserveBook from "@salesforce/apex/LibraryMemberSessionController.reserveBook";
import cancelMyReservation from "@salesforce/apex/LibraryMemberSessionController.cancelMyReservation";
import getMyFines from "@salesforce/apex/LibraryMemberSessionController.getMyFines";
import getMyMembership from "@salesforce/apex/LibraryMemberSessionController.getMyMembership";
import getMyPayments from "@salesforce/apex/LibraryMemberSessionController.getMyPayments";
import getMyProfile from "@salesforce/apex/LibraryMemberSessionController.getMyProfile";
import updateMyProfile from "@salesforce/apex/LibraryMemberSessionController.updateMyProfile";
import getUpgradePlans from "@salesforce/apex/LibraryMemberSessionController.getUpgradePlans";
import payForMembershipUpgrade from "@salesforce/apex/LibraryMemberSessionController.payForMembershipUpgrade";
import renewMyMembership from "@salesforce/apex/LibraryMemberSessionController.renewMyMembership";
import getMyNotifications from "@salesforce/apex/LibraryMemberSessionController.getMyNotifications";
import markNotificationRead from "@salesforce/apex/LibraryMemberSessionController.markNotificationRead";
import getMyNotificationPreferences from "@salesforce/apex/LibraryMemberSessionController.getMyNotificationPreferences";
import updateMyNotificationPreferences from "@salesforce/apex/LibraryMemberSessionController.updateMyNotificationPreferences";
import reportDefectiveLoan from "@salesforce/apex/LibraryMemberSessionController.reportDefectiveLoan";
import saveMyEngagement from "@salesforce/apex/LibraryMemberSessionController.saveMyEngagement";
import followAuthor from "@salesforce/apex/LibraryMemberSessionController.followAuthor";
import submitBookReview from "@salesforce/apex/LibraryMemberSessionController.submitBookReview";

const NAVIGATION = [
  ["Dashboard", "utility:home"],
  ["Explore Books", "utility:knowledge_base"],
  ["Events", "utility:event"],
  ["Rooms", "utility:company"],
  ["Challenges", "utility:favorite"],
  ["Branches", "utility:location"],
  ["Fine Appeals", "utility:warning"],
  ["Membership Holds", "utility:pause"],
  ["Privacy Center", "utility:lock"],
  ["Reading Lists", "utility:bookmark"],
  ["Followed Authors", "utility:favorite"],
  ["Scan & Borrow", "utility:scan"],
  ["My Books", "utility:bookmark"],
  ["Reservations", "utility:favorite"],
  ["Membership", "utility:groups"],
  ["Fines & Payments", "utility:money"],
  ["Member Assistant", "utility:chat"],
  ["Profile", "utility:user"]
];
const PAGE_COPY = {
  Dashboard: ["Member Dashboard", "Here’s your library overview"],
  "Explore Books": [
    "Explore Books",
    "Discover new books, authors and categories"
  ],
  Events: [
    "Library Events",
    "Discover talks, workshops and reading groups at your library"
  ],
  Rooms: [
    "Room Bookings",
    "Find and reserve a library room for your next gathering"
  ],
  Challenges: [
    "Reading Challenges",
    "Set goals and celebrate your reading progress"
  ],
  Branches: ["Library Branches", "Find nearby locations and branch inventory"],
  "Fine Appeals": ["Fine Appeals", "Request a review of a disputed charge"],
  "Membership Holds": [
    "Membership Holds",
    "Request a policy-approved pause without losing your membership history"
  ],
  "Privacy Center": [
    "Privacy Center",
    "Export, correct, or close your library account securely"
  ],
  "Reading Lists": [
    "My Reading Lists",
    "Save books privately and track your reading progress"
  ],
  "Followed Authors": [
    "Authors I Follow",
    "Keep up with new releases from your favorite authors"
  ],
  "Scan & Borrow": [
    "Scan & Borrow",
    "Use your camera or enter a copy barcode for self-checkout"
  ],
  "My Books": ["My Books", "View and manage your borrowed books"],
  Reservations: [
    "My Reservations",
    "Track your book reservations and waiting list"
  ],
  Membership: [
    "My Membership",
    "View your membership details and manage your plan"
  ],
  "Fines & Payments": [
    "Fines & Payments",
    "View your fines and payment history"
  ],
  "Member Assistant": ["Member Assistant", "Your personal library assistant"],
  Profile: ["My Profile", "Manage your personal details and account settings"]
};

export default class LibraryMemberShell extends LightningElement {
  section = "Dashboard";
  member;
  dashboard;
  analytics;
  suggestions = [];
  catalog = [];
  categories = [];
  bookDetail;
  reviewRating;
  reviewText = "";
  reviewStatus;
  borrowings = [];
  reservations = [];
  fines = [];
  membership;
  payments = [];
  notifications = [];
  notificationPreferences = [];
  notificationPreferenceSaving = false;
  upgradePlans = [];
  profile;
  loading = false;
  error;
  accessState;
  searchTerm = "";
  globalSearch = "";
  availability = "";
  categoryId = "";
  authorFilter = "";
  catalogPage = 1;
  catalogPageSize = 8;
  mobileNavOpen = false;
  accountMenuOpen = false;
  notificationsOpen = false;
  loanTab = "Active";
  reservationTab = "Active";
  fineTab = "Unpaid";
  profileTab = "Personal Details";
  activityFilter = "All Activities";
  assistantInput = "";
  assistantMessages = [
    {
      id: "welcome",
      className: "assistant-message assistant-message-bubble",
      text: "Hello, Rohit! 👋 I’m your Library Assistant. I can help you find books, check loans and due dates, view reservations, review fines, and understand your membership. How can I help you today?"
    }
  ];
  editProfile = false;
  realtimeRefreshTimer;
  firstName = "";
  lastName = "";
  phone = "";
  address = "";
  confirmAction;
  confirmRecord;
  defectNotes = "";
  debounceTimer;
  sessionToken = sessionStorage.getItem("libraryMemberSession");

  connectedCallback() {
    // Remove tokens written by older releases. Member bearer credentials must
    // not persist after the browser session ends.
    localStorage.removeItem("libraryMemberSession");
    const requestedSection = new URL(window.location.href).searchParams.get(
      "section"
    );
    if (NAVIGATION.some(([label]) => label === requestedSection))
      this.section = requestedSection;
    this.loadContext();
    // Intentional polling keeps member activity current between user actions.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.realtimeRefreshTimer = window.setInterval(() => {
      this.refreshVisibleSection();
    }, 5000);
  }

  disconnectedCallback() {
    clearTimeout(this.debounceTimer);
    if (this.realtimeRefreshTimer) {
      window.clearInterval(this.realtimeRefreshTimer);
      this.realtimeRefreshTimer = undefined;
    }
  }

  get navItems() {
    return NAVIGATION.map(([label, icon]) => ({
      label,
      icon,
      value: label,
      className: label === this.section ? "nav-item active" : "nav-item"
    }));
  }

  get mobileNavClass() {
    return this.mobileNavOpen ? "side-nav mobile-open" : "side-nav";
  }
  get accountMenuClass() {
    return this.accountMenuOpen ? "account-menu open" : "account-menu";
  }
  get notificationPanelClass() {
    return this.notificationsOpen
      ? "notification-panel open"
      : "notification-panel";
  }
  get pageTitle() {
    return PAGE_COPY[this.section]?.[0] || this.section;
  }
  get pageSubtitle() {
    return PAGE_COPY[this.section]?.[1] || "";
  }
  get isDashboard() {
    return this.section === "Dashboard";
  }
  get isExploreBooks() {
    return this.section === "Explore Books";
  }
  get isEvents() {
    return this.section === "Events";
  }
  get isRooms() {
    return this.section === "Rooms";
  }
  get isChallenges() {
    return this.section === "Challenges";
  }
  get isBranches() {
    return this.section === "Branches";
  }
  get isFineAppeals() {
    return this.section === "Fine Appeals";
  }
  get isMembershipHolds() {
    return this.section === "Membership Holds";
  }
  get isPrivacyCenter() {
    return this.section === "Privacy Center";
  }
  get isReadingLists() {
    return this.section === "Reading Lists";
  }
  get isFollowedAuthors() {
    return this.section === "Followed Authors";
  }
  get isScanner() {
    return this.section === "Scan & Borrow";
  }
  get isMyBooks() {
    return this.section === "My Books";
  }
  get isReservations() {
    return this.section === "Reservations";
  }
  get isMembership() {
    return this.section === "Membership";
  }
  get isFinesPayments() {
    return this.section === "Fines & Payments";
  }
  get isAssistant() {
    return this.section === "Member Assistant";
  }
  get isProfile() {
    return this.section === "Profile";
  }
  get assistantQuestions() {
    return [
      "Find available books about data science",
      "Is my current book available to renew, and when is it due?",
      "Which books am I currently borrowing?",
      "Show my reservation status",
      "What fines do I have?",
      "What are my membership benefits?",
      "Recommend a book based on my activity",
      "How do I borrow or reserve a book?"
    ];
  }
  get isReady() {
    return Boolean(this.member && this.dashboard && !this.accessState);
  }
  get showAccessState() {
    return Boolean(this.accessState);
  }
  get accessStateTitle() {
    return this.accessState === "rejected"
      ? "Registration Rejected"
      : this.accessState === "suspended"
        ? "Account Suspended"
        : "Registration Submitted!";
  }
  get accessStateMessage() {
    if (this.accessState === "rejected")
      return "Your registration request was not approved. Contact the library if you believe this is a mistake.";
    if (this.accessState === "suspended")
      return "Your account is not currently active. Please contact the library administrator for assistance.";
    return "Your registration has been received and is pending librarian approval. You will be notified via email once your account is approved.";
  }
  get accessStateIcon() {
    return this.accessState === "rejected"
      ? "×"
      : this.accessState === "suspended"
        ? "⚠"
        : "◷";
  }
  get accessStateVariant() {
    return this.accessState || "pending";
  }
  get displayName() {
    return (
      [this.member?.First_Name__c, this.member?.Last_Name__c]
        .filter(Boolean)
        .join(" ") || "Member"
    );
  }
  get firstNameLabel() {
    return this.member?.First_Name__c || "Member";
  }
  get initials() {
    return this.displayName
      .split(" ")
      .map((part) => part.charAt(0))
      .join("")
      .slice(0, 2)
      .toUpperCase();
  }
  get memberId() {
    return this.member?.Name || "";
  }
  get plan() {
    return (
      this.membership?.Membership_Plan__r || this.member?.Membership_Plan__r
    );
  }
  get planName() {
    return this.plan?.Name || "No Plan";
  }
  get membershipStatus() {
    return this.membership?.Status__c || this.member?.Status__c || "Active";
  }
  get memberStatusClass() {
    return this.badge(this.membershipStatus);
  }
  get activeLoans() {
    return this.borrowings.filter((loan) => !loan.Return_Date__c);
  }
  get returnedLoans() {
    return this.borrowings.filter((loan) => Boolean(loan.Return_Date__c));
  }
  get overdueLoans() {
    const now = new Date();
    return this.activeLoans.filter(
      (loan) => loan.Status__c === "Overdue" || new Date(loan.Due_Date__c) < now
    );
  }
  get dueSoonLoans() {
    const now = new Date();
    const soon = new Date(Date.now() + 3 * 86400000);
    return this.activeLoans.filter((loan) => {
      const due = new Date(loan.Due_Date__c);
      return due >= now && due <= soon;
    });
  }
  get currentLoansPreview() {
    return this.activeLoans.slice(0, 3);
  }
  get hasCurrentLoans() {
    return this.currentLoansPreview.length > 0;
  }
  get selectedLoans() {
    if (this.loanTab === "Overdue") return this.overdueLoans;
    if (this.loanTab === "Returned") return this.returnedLoans;
    return this.activeLoans.filter((loan) => loan.Status__c !== "Overdue");
  }
  get hasSelectedLoans() {
    return this.selectedLoans.length > 0;
  }
  get loanTabs() {
    return [
      ["Active", this.activeLoans.length],
      ["Overdue", this.overdueLoans.length],
      ["Returned", this.returnedLoans.length]
    ].map(([label, count]) => ({
      label: `${label} (${count})`,
      value: label,
      className: label === this.loanTab ? "tab active" : "tab"
    }));
  }
  get activeReservations() {
    return this.reservations.filter((row) =>
      ["Pending", "Ready"].includes(row.Status__c)
    );
  }
  get selectedReservations() {
    const states = {
      Active: ["Pending", "Ready"],
      Waiting: ["Pending"],
      Fulfilled: ["Fulfilled"],
      Cancelled: ["Cancelled", "Expired"]
    };
    return this.reservations.filter((row) =>
      states[this.reservationTab].includes(row.Status__c)
    );
  }
  get hasSelectedReservations() {
    return this.selectedReservations.length > 0;
  }
  get reservationTabs() {
    return ["Active", "Waiting", "Fulfilled", "Cancelled"].map((label) => ({
      label,
      value: label,
      className: label === this.reservationTab ? "tab active" : "tab"
    }));
  }
  get selectedFines() {
    return this.fines.filter((fine) => {
      return this.fineTab === "Unpaid"
        ? ["Unpaid", "Partially Paid"].includes(fine.Status__c)
        : ["Paid", "Waived"].includes(fine.Status__c);
    });
  }
  get hasSelectedFines() {
    return this.selectedFines.length > 0;
  }
  get hasPayments() {
    return this.payments.length > 0;
  }
  get fineTabs() {
    return ["Unpaid", "Paid"].map((label) => ({
      label: `${label} Fines`,
      value: label,
      className: label === this.fineTab ? "tab active" : "tab"
    }));
  }
  get profileTabs() {
    return [
      "Personal Details",
      "Address",
      "Membership",
      "Digital Card",
      "Activity",
      "Notifications",
      "Accessibility"
    ].map((label) => ({
      label,
      value: label,
      className: label === this.profileTab ? "tab active" : "tab"
    }));
  }
  get isPersonalProfile() {
    return this.profileTab === "Personal Details";
  }
  get isAddressProfile() {
    return this.profileTab === "Address";
  }
  get isMembershipProfile() {
    return this.profileTab === "Membership";
  }
  get isDigitalCardProfile() {
    return this.profileTab === "Digital Card";
  }
  get isActivityProfile() {
    return this.profileTab === "Activity";
  }
  get isNotificationProfile() {
    return this.profileTab === "Notifications";
  }
  get isAccessibilityProfile() {
    return this.profileTab === "Accessibility";
  }
  accessibilityClassName = "member-app";
  handleAccessibilityChange(event) {
    const detail = event.detail || {};
    const classes = ["member-app"];
    if (detail.highContrast) classes.push("high-contrast");
    if (detail.largeText) classes.push("large-text");
    if (detail.reducedMotion) classes.push("reduced-motion");
    this.accessibilityClassName = classes.join(" ");
  }
  get preferenceRows() {
    return (this.notificationPreferences || []).map((row) => ({
      ...row,
      enabledLabel: row.enabled ? "On" : "Off",
      statusClass: row.enabled ? "preference-on" : "preference-off"
    }));
  }
  get savePreferenceLabel() {
    return this.notificationPreferenceSaving ? "Saving…" : "Save preferences";
  }
  get digestFrequencyOptions() {
    return [
      { label: "Instant", value: "Instant" },
      { label: "Daily digest", value: "Daily" },
      { label: "Weekly digest", value: "Weekly" }
    ];
  }
  get outstandingFine() {
    return Number(this.dashboard?.outstandingFine || 0);
  }
  get outstandingFineLabel() {
    return this.currency(this.outstandingFine);
  }
  get memberAnalyticsAvailable() {
    return Boolean(this.analytics?.available);
  }
  get memberAnalyticsMessage() {
    return (
      this.analytics?.message ||
      "Activity analytics are temporarily unavailable."
    );
  }
  get memberAnalyticsCadence() {
    return (
      this.analytics?.refreshCadence ||
      "Live Salesforce data • updates automatically"
    );
  }
  get myActivityCards() {
    const a = this.analytics || {};
    return [
      ["Total Loans", a.totalLoans, "▤", "blue"],
      ["Active Loans", a.activeLoans, "●", "green"],
      ["Returned Loans", a.returnedLoans, "✓", "purple"],
      ["Overdue Loans", a.overdueLoans, "!", "red"],
      ["Reservations", a.totalReservations, "▦", "gold"],
      ["Active Reservations", a.activeReservationCount, "◉", "cyan"],
      ["Total Fines", a.totalFineCount, "₹", "orange"],
      ["Unpaid Fines", a.unpaidFineCount, "!", "red"]
    ].map(([label, value, icon, theme]) => ({
      label,
      value: value ?? 0,
      icon,
      cardClass: `activity-metric-card ${theme}`
    }));
  }
  get unpaidFineCount() {
    return this.fines.filter((fine) =>
      ["Unpaid", "Partially Paid"].includes(fine.Status__c)
    ).length;
  }
  get recommendedBooks() {
    if (this.suggestions.length) return this.suggestions;
    const rawInterests =
      this.member?.Interests__c || this.dashboard?.member?.Interests__c || "";
    const interests = rawInterests
      .toLowerCase()
      .split(/[,;|]+/)
      .map((value) => value.trim())
      .filter((value) => value.length >= 2);
    if (!interests.length) return this.catalog.slice(0, 4);
    const ranked = this.catalog
      .map((book, index) => {
        const text =
          `${book.Name || ""} ${book.authors || ""} ${book.categories || ""}`.toLowerCase();
        const score = interests.reduce(
          (total, interest) => total + (text.includes(interest) ? 1 : 0),
          0
        );
        return { book, score, index };
      })
      .sort((a, b) => b.score - a.score || a.index - b.index);
    const matches = ranked
      .filter((row) => row.score > 0)
      .map((row) => row.book);
    return (matches.length ? matches : ranked.map((row) => row.book)).slice(
      0,
      4
    );
  }
  get hasRecommendedBooks() {
    return this.recommendedBooks.length > 0;
  }
  get visibleCatalog() {
    if (!this.authorFilter) return this.catalog;
    return this.catalog.filter((book) => book.authors === this.authorFilter);
  }
  get hasCatalogResults() {
    return this.visibleCatalog.length > 0;
  }
  get categoryOptions() {
    return [
      { label: "All Categories", value: "" },
      ...this.categories.map((row) => ({ label: row.Name, value: row.Id }))
    ];
  }
  get authorOptions() {
    const names = [...new Set(this.catalog.map((book) => book.authors))].filter(
      (name) => name && name !== "Author unavailable"
    );
    return [
      { label: "All Authors", value: "" },
      ...names.map((name) => ({ label: name, value: name }))
    ];
  }
  get availabilityOptions() {
    return [
      { label: "All Books", value: "" },
      { label: "Available", value: "Available" },
      { label: "Unavailable", value: "Unavailable" }
    ];
  }
  get popularCategories() {
    return this.categories.slice(0, 8).map((row) => ({
      ...row,
      className:
        row.Id === this.categoryId ? "category-chip active" : "category-chip"
    }));
  }
  get isFirstCatalogPage() {
    return this.catalogPage === 1;
  }
  get bookDetailAvailable() {
    return Number(this.bookDetail?.Available_Copies__c || 0) > 0;
  }
  get bookDetailAuthors() {
    return this.bookDetail?.authors || "Author unavailable";
  }
  get bookDetailAuthorId() {
    return this.bookDetail?.Book_Authors__r?.[0]?.Author__c;
  }
  get bookDetailCategories() {
    return this.bookDetail?.categories || "Uncategorized";
  }
  get bookDetailCover() {
    return this.bookDetail?.coverUrl;
  }
  get bookDetailStatusClass() {
    return this.bookDetailAvailable
      ? "availability available"
      : "availability unavailable";
  }
  get borrowedCopyCount() {
    return Math.max(
      0,
      Number(this.bookDetail?.Total_Copies__c || 0) -
        Number(this.bookDetail?.Available_Copies__c || 0)
    );
  }
  get unreadNotifications() {
    return this.notifications.filter((row) => row.Status__c === "Unread");
  }
  get hasUnreadNotifications() {
    return this.unreadNotifications.length > 0;
  }
  get availableUpgradePlans() {
    return this.upgradePlans.map((plan) => ({
      ...plan,
      priceLabel: this.currency(plan.fee),
      current: plan.name === this.planName
    }));
  }
  get joinedDate() {
    return this.formatDate(
      this.profile?.Registration_Date__c ||
        this.member?.Membership_Start_Date__c
    );
  }
  get membershipEndDate() {
    return this.formatDate(this.membership?.Membership_End_Date__c);
  }
  get planBorrowLimit() {
    return this.plan?.Borrow_Limit__c ?? "—";
  }
  get planLoanPeriod() {
    return this.plan?.Loan_Duration_Days__c ?? "—";
  }
  get planReservationLimit() {
    return this.plan?.Reservation_Limit__c ?? "—";
  }
  get planRenewalLimit() {
    return this.plan?.Renewal_Limit__c ?? "—";
  }
  get activityFilters() {
    return [
      "All Activities",
      "Books",
      "Reservations",
      "Fines",
      "Payments",
      "Membership"
    ].map((label) => ({
      label,
      value: label,
      className:
        label === this.activityFilter
          ? "activity-filter active"
          : "activity-filter"
    }));
  }
  get activities() {
    const rows = [];
    this.borrowings.forEach((loan) => {
      rows.push({
        id: `loan-${loan.Id}`,
        type: "Books",
        icon: "utility:knowledge_base",
        title: loan.Return_Date__c ? "Book returned" : "Book issued",
        detail: loan.bookName,
        date: loan.Return_Date__c || loan.Borrow_Date__c,
        className: "activity-icon blue"
      });
    });
    this.reservations.forEach((reservation) => {
      rows.push({
        id: `reservation-${reservation.Id}`,
        type: "Reservations",
        icon: "utility:favorite",
        title: `Reservation ${String(reservation.Status__c || "updated").toLowerCase()}`,
        detail: reservation.bookName,
        date: reservation.Fulfilled_Date__c || reservation.Reservation_Date__c,
        className: "activity-icon purple"
      });
    });
    this.fines.forEach((fine) => {
      rows.push({
        id: `fine-${fine.Id}`,
        type: "Fines",
        icon: "utility:money",
        title: fine.Status__c === "Paid" ? "Fine paid" : "Fine created",
        detail: `${fine.Name} · ${this.currency(fine.Amount__c)}`,
        date: fine.Paid_Date__c || fine.Generated_Date__c,
        className: "activity-icon red"
      });
    });
    this.payments.forEach((payment) => {
      rows.push({
        id: `payment-${payment.Id}`,
        type: "Payments",
        icon: "utility:payment_gateway",
        title: "Membership payment",
        detail: `${payment.Name} · ${this.currency(payment.Amount__c)}`,
        date: payment.Payment_Date__c,
        className: "activity-icon green"
      });
    });
    return rows
      .filter(
        (row) =>
          this.activityFilter === "All Activities" ||
          row.type === this.activityFilter
      )
      .sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0))
      .slice(0, 50)
      .map((row) => ({ ...row, dateLabel: this.formatDate(row.date) }));
  }
  get hasActivities() {
    return this.activities.length > 0;
  }
  get showConfirmation() {
    return Boolean(this.confirmAction);
  }
  get isDefectConfirmation() {
    return this.confirmAction === "defect";
  }
  get confirmationTitle() {
    const titles = {
      borrow: "Borrow this book?",
      reserve: "Reserve this book?",
      renew: "Renew this loan?",
      cancel: "Cancel this reservation?",
      upgrade: "Change membership plan?",
      defect: "Report a problem with this book?"
    };
    return titles[this.confirmAction] || "Confirm action";
  }
  get confirmationMessage() {
    if (this.confirmAction === "borrow")
      return "An available copy will be issued to your account using your membership rules.";
    if (this.confirmAction === "reserve")
      return "You will be added to the reservation queue for this title.";
    if (this.confirmAction === "renew")
      return "The server will verify your renewal limit and any waiting reservations.";
    if (this.confirmAction === "cancel")
      return "Your place in the reservation queue will be released.";
    if (this.confirmAction === "defect")
      return "The copy will be marked damaged and a librarian will arrange a replacement. You will not be charged for reporting a defect.";
    return "The selected plan and membership fee will be applied to your account.";
  }
  get confirmationButtonLabel() {
    const labels = {
      borrow: "Borrow Book",
      reserve: "Reserve Book",
      renew: "Renew",
      cancel: "Cancel Reservation",
      upgrade: "Confirm Plan",
      defect: "Report Defect"
    };
    return labels[this.confirmAction] || "Confirm";
  }
  get confirmationButtonClass() {
    return this.confirmAction === "cancel" ? "button danger" : "button primary";
  }

  loadContext() {
    this.loading = true;
    this.error = undefined;
    return getCurrentMemberContext({ sessionToken: this.sessionToken })
      .then((member) => {
        this.member = member;
        return Promise.all([
          getMyDashboard({ sessionToken: this.sessionToken }),
          getMyAnalytics({ sessionToken: this.sessionToken }),
          getSuggestedBooks({ sessionToken: this.sessionToken }),
          getCatalogCategories({ sessionToken: this.sessionToken }),
          this.fetchCatalog(),
          getMyNotifications({ sessionToken: this.sessionToken })
        ]);
      })
      .then(
        ([dashboard, analytics, suggestions, categories, , notifications]) => {
          this.dashboard = dashboard;
          this.analytics = analytics;
          this.suggestions = (suggestions || []).map((row) =>
            this.decorateBook(row)
          );
          this.categories = categories || [];
          this.notifications = notifications || [];
          this.borrowings = (dashboard?.recentLoans || []).map((row) =>
            this.decorateLoan(row)
          );
          this.reservations = (dashboard?.recentReservations || []).map((row) =>
            this.decorateReservation(row)
          );
        }
      )
      .catch((error) => this.handleError(error, "initial member load"))
      .finally(() => {
        this.loading = false;
      });
  }

  selectSection(event) {
    this.section = event.currentTarget.dataset.section;
    this.mobileNavOpen = false;
    this.accountMenuOpen = false;
    const loaders = {
      Dashboard: () => this.loadDashboardData(),
      "Explore Books": () =>
        Promise.all([this.loadCategories(), this.loadCatalog()]),
      "My Books": () => this.loadBorrowings(),
      Reservations: () => this.loadReservations(),
      Membership: () => this.loadMembership(),
      "Fines & Payments": () => this.loadFinesAndPayments(),
      Profile: () => this.loadProfileWorkspace()
    };
    return loaders[this.section]?.();
  }

  handleAssistantInput(event) {
    this.assistantInput = event.target.value;
  }

  useAssistantPrompt(event) {
    this.assistantInput = event.currentTarget.dataset.question;
    this.sendAssistantMessage();
  }

  assistantReply(question) {
    const normalized = question.toLowerCase();
    if (normalized.includes("recommend") || normalized.includes("suggest")) {
      const recommendations = this.catalog
        .filter((book) => book.availableCopies > 0)
        .slice(0, 3);
      return recommendations.length
        ? `Based on your library activity and currently available catalog data, you may enjoy ${recommendations.map((book) => book.title).join(", ")}.`
        : "I do not have enough current catalog activity data to make a recommendation right now.";
    }
    if (
      normalized.includes("due") ||
      normalized.includes("loan") ||
      normalized.includes("borrow")
    ) {
      const activeLoans = this.activeLoans;
      if (!activeLoans.length) {
        return "You do not have any active loans right now.";
      }
      return activeLoans
        .map((loan) => `${loan.bookName} is due ${loan.dueDateLabel}.`)
        .join(" ");
    }
    if (normalized.includes("reservation")) {
      const activeReservations = this.reservations.filter(
        (reservation) => reservation.Status__c !== "Cancelled"
      );
      return activeReservations.length
        ? `You have ${activeReservations.length} active reservation${activeReservations.length === 1 ? "" : "s"}.`
        : "You do not have any active reservations.";
    }
    if (
      normalized.includes("membership") ||
      normalized.includes("benefit") ||
      normalized.includes("plan")
    ) {
      return `Your current membership plan is ${this.planName}. It includes access to the library catalog, borrowing, reservations, and member account services available for your plan.`;
    }
    if (normalized.includes("fine") || normalized.includes("payment")) {
      return `Your current outstanding balance is ${this.currency(
        this.analytics?.totalFineAmount || this.dashboard?.outstandingFine || 0
      )}.`;
    }
    if (normalized.includes("renew")) {
      return "Open My Books to review an active loan and use Renew when the option is available.";
    }
    if (
      normalized.includes("reserve") ||
      normalized.includes("how do i borrow")
    ) {
      return "Open Explore Books, select a title, then choose Borrow when a copy is available or Reserve when the title is unavailable. I can also check your current reservation status.";
    }
    if (normalized.includes("book") || normalized.includes("available")) {
      return "Open Explore Books to search the catalog by title, author, category, or availability.";
    }
    return "I can help with books, loans, reservations, fines, membership, and renewals. Try one of the example questions.";
  }

  sendAssistantMessage(event) {
    event?.preventDefault();
    const question = this.assistantInput.trim();
    if (!question) return;
    this.assistantMessages = [
      ...this.assistantMessages,
      {
        id: `question-${Date.now()}`,
        className: "assistant-message member-message-bubble",
        text: question
      }
    ];
    this.assistantInput = "";
    this.assistantMessages = [
      ...this.assistantMessages,
      {
        id: `answer-${Date.now()}`,
        className: "assistant-message assistant-message-bubble",
        text: this.assistantReply(question)
      }
    ];
  }

  clearAssistantChat() {
    this.assistantMessages = [];
  }

  openSection(event) {
    return this.selectSection({
      currentTarget: {
        dataset: { section: event.currentTarget.dataset.section }
      }
    });
  }

  refreshVisibleSection() {
    if (this.loading || this.showConfirmation) return;
    let refresh;
    if (this.bookDetail?.Id) {
      refresh = this.call(
        getBookDetails,
        { bookId: this.bookDetail.Id },
        (data) => {
          this.bookDetail = this.decorateBook(data);
        }
      );
    } else if (this.section === "Dashboard")
      refresh = this.loadDashboardData(false);
    else if (this.section === "My Books") refresh = this.loadBorrowings();
    else if (this.section === "Reservations") refresh = this.loadReservations();
    else if (this.section === "Fines & Payments")
      refresh = this.loadFinesAndPayments();
    else if (this.section === "Membership") refresh = this.loadMembership();
    if (refresh?.catch) refresh.catch(() => undefined);
  }

  loadDashboardData(includeCatalog = true) {
    return Promise.all([
      this.call(getMyDashboard, {}, (dashboard) => {
        this.dashboard = dashboard;
        this.borrowings = (dashboard?.recentLoans || []).map((row) =>
          this.decorateLoan(row)
        );
        this.reservations = (dashboard?.recentReservations || []).map((row) =>
          this.decorateReservation(row)
        );
      }),
      this.call(getMyAnalytics, {}, (analytics) => {
        this.analytics = analytics;
      }),
      this.call(getSuggestedBooks, {}, (suggestions) => {
        this.suggestions = (suggestions || []).map((row) =>
          this.decorateBook(row)
        );
      })
    ]).then(() => (includeCatalog ? this.fetchCatalog() : undefined));
  }

  loadCategories() {
    return this.call(getCatalogCategories, {}, (data) => {
      this.categories = data || [];
    });
  }

  fetchCatalog() {
    return searchCatalog({
      sessionToken: this.sessionToken,
      searchTerm: this.searchTerm,
      categoryId: this.categoryId || null,
      availability: this.availability,
      pageSize: this.catalogPageSize,
      pageNumber: this.catalogPage
    }).then((data) => {
      this.catalog = (data || []).map((row) => this.decorateBook(row));
    });
  }

  loadCatalog() {
    return this.call(
      searchCatalog,
      {
        searchTerm: this.searchTerm,
        categoryId: this.categoryId || null,
        availability: this.availability,
        pageSize: this.catalogPageSize,
        pageNumber: this.catalogPage
      },
      (data) => {
        this.catalog = (data || []).map((row) => this.decorateBook(row));
      }
    );
  }

  loadBorrowings() {
    return this.call(getMyBorrowings, {}, (data) => {
      this.borrowings = (data || []).map((row) => this.decorateLoan(row));
    });
  }

  loadReservations() {
    return this.call(getMyReservations, {}, (data) => {
      this.reservations = (data || []).map((row) =>
        this.decorateReservation(row)
      );
    });
  }

  loadFinesAndPayments() {
    return Promise.all([
      this.call(getMyFines, {}, (data) => {
        this.fines = (data || []).map((row) => ({
          ...row,
          bookName:
            row.Borrow_Record__r?.Book_Copy__r?.Book__r?.Name ||
            row.Borrow_Record__r?.Name ||
            "Related loan",
          amountLabel: this.currency(row.Amount__c),
          balanceLabel: this.currency(row.Balance__c),
          statusClass: this.badge(row.Status__c),
          dateLabel: this.formatDate(row.Generated_Date__c)
        }));
      }),
      this.call(getMyPayments, {}, (data) => {
        this.payments = (data || []).map((row) => this.decoratePayment(row));
      })
    ]);
  }

  loadMembership() {
    return Promise.all([
      this.call(getMyMembership, {}, (data) => {
        this.membership = data;
      }),
      this.call(getUpgradePlans, {}, (data) => {
        this.upgradePlans = data || [];
      }),
      this.call(getMyPayments, {}, (data) => {
        this.payments = (data || []).map((row) => this.decoratePayment(row));
      })
    ]);
  }

  loadProfileWorkspace() {
    return Promise.all([
      this.call(getMyProfile, {}, (data) => {
        this.profile = data;
        this.firstName = data?.First_Name__c || "";
        this.lastName = data?.Last_Name__c || "";
        this.phone = data?.Phone__c || "";
        this.address = data?.Address__c || "";
      }),
      this.loadBorrowings(),
      this.loadReservations(),
      this.loadFinesAndPayments(),
      this.loadMembership(),
      this.loadNotificationPreferences()
    ]);
  }

  loadNotifications() {
    return this.call(getMyNotifications, {}, (data) => {
      this.notifications = data || [];
    });
  }

  loadNotificationPreferences() {
    return this.call(getMyNotificationPreferences, {}, (data) => {
      this.notificationPreferences = data || [];
    });
  }

  changePreference(event) {
    const id = event.currentTarget.dataset.id;
    const enabled = event.currentTarget.checked;
    this.notificationPreferences = this.notificationPreferences.map((row) => {
      return row.id === id ? { ...row, enabled } : row;
    });
  }

  changePreferenceFrequency(event) {
    const id = event.currentTarget.dataset.id;
    const digestFrequency = event.detail?.value || event.currentTarget.value;
    this.notificationPreferences = this.notificationPreferences.map((row) => {
      return row.id === id ? { ...row, digestFrequency } : row;
    });
  }

  saveNotificationPreferences() {
    this.notificationPreferenceSaving = true;
    return this.call(
      updateMyNotificationPreferences,
      {
        inputs: this.notificationPreferences.map((row) => ({
          channel: row.channel,
          notificationType: row.notificationType,
          enabled: row.enabled,
          digestFrequency: row.digestFrequency,
          quietHoursStart: row.quietHoursStart,
          quietHoursEnd: row.quietHoursEnd,
          timezone: row.timezone
        }))
      },
      () => {
        this.toast(
          "Notification preferences saved",
          "Your delivery choices will be used for future messages.",
          "success"
        );
      }
    ).finally(() => {
      this.notificationPreferenceSaving = false;
    });
  }

  call(action, params, onSuccess) {
    this.loading = true;
    this.error = undefined;
    return action({ ...params, sessionToken: this.sessionToken })
      .then(onSuccess)
      .catch((error) => this.handleError(error))
      .finally(() => {
        this.loading = false;
      });
  }

  handleGlobalSearch(event) {
    this.globalSearch = event.target.value;
    clearTimeout(this.debounceTimer);
    // A short debounce keeps catalog Apex traffic controlled while typing.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.debounceTimer = setTimeout(() => {
      this.searchTerm = this.globalSearch;
      this.catalogPage = 1;
      this.section = "Explore Books";
      this.loadCatalog();
    }, 400);
  }

  handleInput(event) {
    this[event.target.name] = event.detail?.value ?? event.target.value;
  }

  searchNow() {
    this.catalogPage = 1;
    return this.loadCatalog();
  }

  handleCatalogKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.searchNow();
    }
  }

  selectCategory(event) {
    this.categoryId = event.currentTarget.dataset.id;
    this.catalogPage = 1;
    return this.loadCatalog();
  }

  resetCatalog() {
    this.searchTerm = "";
    this.globalSearch = "";
    this.categoryId = "";
    this.authorFilter = "";
    this.availability = "";
    this.catalogPage = 1;
    return this.loadCatalog();
  }

  previousCatalog() {
    if (this.catalogPage > 1) {
      this.catalogPage -= 1;
      return this.loadCatalog();
    }
    return Promise.resolve();
  }

  nextCatalog() {
    if (this.catalog.length === this.catalogPageSize) {
      this.catalogPage += 1;
      return this.loadCatalog();
    }
    return Promise.resolve();
  }

  openBook(event) {
    const bookId = event.detail?.id || event.currentTarget?.dataset?.id;
    return this.call(getBookDetails, { bookId }, (data) => {
      this.bookDetail = this.decorateBook(data);
      this.reviewRating = undefined;
      this.reviewText = "";
      this.reviewStatus = undefined;
    });
  }

  closeBookDetails() {
    this.bookDetail = undefined;
  }

  selectLoanTab(event) {
    this.loanTab = event.currentTarget.dataset.value;
  }

  selectReservationTab(event) {
    this.reservationTab = event.currentTarget.dataset.value;
  }

  selectFineTab(event) {
    this.fineTab = event.currentTarget.dataset.value;
  }

  selectProfileTab(event) {
    this.profileTab = event.currentTarget.dataset.value;
  }

  selectActivityFilter(event) {
    this.activityFilter = event.currentTarget.dataset.value;
  }

  requestBorrow() {
    this.confirmAction = "borrow";
    this.confirmRecord = this.bookDetail;
  }

  requestReserve() {
    this.confirmAction = "reserve";
    this.confirmRecord = this.bookDetail;
  }

  saveBookToReadingList() {
    return this.call(
      saveMyEngagement,
      {
        bookId: this.bookDetail.Id,
        state: "Want to Read",
        notes: null,
        rating: null,
        notifyWhenAvailable: false
      },
      () => {
        this.toast(
          "Added to reading list",
          "You can update its progress from Reading Lists.",
          "success"
        );
      }
    );
  }

  followBookAuthor() {
    if (!this.bookDetailAuthorId) {
      this.toast(
        "Author unavailable",
        "This book has no linked author record.",
        "warning"
      );
      return;
    }
    this.call(followAuthor, { authorId: this.bookDetailAuthorId }, () =>
      this.toast(
        "Author followed",
        "You will see this author in Followed Authors.",
        "success"
      )
    );
  }

  handleReviewRating(event) {
    this.reviewRating = event.target.value;
  }

  handleReviewText(event) {
    this.reviewText = event.target.value;
  }

  submitReview() {
    return this.call(
      submitBookReview,
      {
        bookId: this.bookDetail?.Id,
        rating: this.reviewRating ? Number(this.reviewRating) : null,
        reviewText: this.reviewText
      },
      (review) => {
        this.reviewStatus = review.status;
        this.toast(
          "Review submitted",
          "Your review is pending librarian moderation.",
          "success"
        );
      }
    );
  }

  requestRenew(event) {
    this.confirmAction = "renew";
    this.confirmRecord = this.borrowings.find(
      (row) => row.Id === event.currentTarget.dataset.id
    );
  }

  requestDefect(event) {
    this.confirmAction = "defect";
    this.confirmRecord = this.borrowings.find(
      (row) => row.Id === event.currentTarget.dataset.id
    );
    this.defectNotes = "";
  }

  updateDefectNotes(event) {
    this.defectNotes = event.target.value;
  }

  requestCancellation(event) {
    this.confirmAction = "cancel";
    this.confirmRecord = this.reservations.find(
      (row) => row.Id === event.currentTarget.dataset.id
    );
  }

  requestUpgrade(event) {
    this.confirmAction = "upgrade";
    this.confirmRecord = this.upgradePlans.find(
      (row) => row.id === event.currentTarget.dataset.id
    );
  }

  closeConfirmation() {
    this.confirmAction = undefined;
    this.confirmRecord = undefined;
  }

  confirmSelectedAction() {
    const action = this.confirmAction;
    const record = this.confirmRecord;
    if (action === "borrow") {
      return this.call(borrowBook, { bookId: record.Id }, () => {
        this.closeConfirmation();
        this.toast(
          "Borrow request submitted",
          "A librarian must approve this request before the book is issued.",
          "success"
        );
        this.bookDetail = undefined;
        this.section = "My Books";
        // A newly issued loan must be visible immediately, even if the member
        // was previously viewing Returned or Overdue loans.
        this.loanTab = "Active";
        return Promise.all([this.loadBorrowings(), this.loadDashboardData()]);
      });
    }
    if (action === "reserve") {
      return this.call(reserveBook, { bookId: record.Id }, () => {
        this.closeConfirmation();
        this.toast(
          "Reservation placed",
          "Your queue position has been recorded.",
          "success"
        );
        this.bookDetail = undefined;
        this.section = "Reservations";
        return Promise.all([this.loadReservations(), this.loadDashboardData()]);
      });
    }
    if (action === "renew") {
      return this.call(renewMyLoan, { borrowRecordId: record.Id }, () => {
        this.closeConfirmation();
        this.toast(
          "Loan renewed",
          "The due date was updated by library policy.",
          "success"
        );
        return this.loadBorrowings();
      });
    }
    if (action === "defect") {
      return this.call(
        reportDefectiveLoan,
        { borrowRecordId: record.Id, notes: this.defectNotes },
        () => {
          this.closeConfirmation();
          this.toast(
            "Defect reported",
            "The copy was removed from circulation. A replacement will be arranged when available.",
            "success"
          );
          return this.loadBorrowings();
        }
      );
    }
    if (action === "cancel") {
      return this.call(
        cancelMyReservation,
        { reservationId: record.Id },
        () => {
          this.closeConfirmation();
          this.toast(
            "Reservation cancelled",
            "Your queue position was released.",
            "success"
          );
          return this.loadReservations();
        }
      );
    }
    if (action === "upgrade") {
      return this.call(payForMembershipUpgrade, { planId: record.id }, () => {
        this.closeConfirmation();
        this.toast(
          "Membership updated",
          "Your selected plan is now active.",
          "success"
        );
        return Promise.all([this.loadContext(), this.loadMembership()]);
      });
    }
    return Promise.resolve();
  }

  renewMembership() {
    return this.call(renewMyMembership, {}, () => {
      this.toast(
        "Membership renewed",
        "Your membership period was extended.",
        "success"
      );
      return Promise.all([this.loadContext(), this.loadMembership()]);
    });
  }

  beginProfileEdit() {
    this.editProfile = true;
  }

  closeProfileEdit() {
    this.editProfile = false;
  }

  saveProfile() {
    const fields = [...this.template.querySelectorAll(".profile-field")];
    if (fields.some((field) => !field.reportValidity()))
      return Promise.resolve();
    return this.call(
      updateMyProfile,
      {
        firstName: this.firstName,
        lastName: this.lastName,
        phone: this.phone,
        address: this.address
      },
      () => {
        this.editProfile = false;
        this.toast(
          "Profile updated",
          "Your permitted details were saved.",
          "success"
        );
        return Promise.all([this.loadContext(), this.loadProfileWorkspace()]);
      }
    );
  }

  toggleMobileNav() {
    this.mobileNavOpen = !this.mobileNavOpen;
  }

  toggleAccountMenu() {
    this.accountMenuOpen = !this.accountMenuOpen;
    this.notificationsOpen = false;
  }

  toggleNotifications() {
    this.notificationsOpen = !this.notificationsOpen;
    this.accountMenuOpen = false;
  }

  readNotification(event) {
    return this.call(
      markNotificationRead,
      { notificationId: event.currentTarget.dataset.id },
      () => this.loadNotifications()
    );
  }

  logout() {
    sessionStorage.removeItem("libraryMemberSession");
    localStorage.removeItem("libraryMemberSession");
    window.location.replace("/library/logout");
  }

  retry() {
    this.error = undefined;
    this.accessState = undefined;
    return this.loadContext();
  }

  decorateBook(row) {
    const available = Number(row?.Available_Copies__c || 0);
    const total = Number(row?.Total_Copies__c || 0);
    const authors = (row?.Book_Authors__r || [])
      .map((link) => link.Author__r?.Name)
      .filter(Boolean)
      .join(", ");
    const categories = (row?.Book_Category_Links__r || [])
      .map((link) => link.Book_Category__r?.Name)
      .filter(Boolean)
      .join(", ");
    const availabilityState =
      available === 0
        ? "unavailable"
        : available < Math.max(2, total / 3)
          ? "limited"
          : "available";
    return {
      ...row,
      authors: authors || "Author unavailable",
      categories: categories || "Uncategorized",
      coverUrl: row?.Cover_Image_URL__c || "",
      availabilityMeta:
        available > 0 ? `${available} available` : "Currently unavailable",
      availabilityClass: `availability ${availabilityState}`
    };
  }

  decorateLoan(row) {
    const returnDate = row.returnDate || row.Return_Date__c;
    const status =
      row.status || row.Status__c || (returnDate ? "Returned" : "Active");
    return {
      ...row,
      Id: row.id || row.Id,
      Name: row.name || row.Name,
      Borrow_Date__c: row.borrowDate || row.Borrow_Date__c,
      Due_Date__c: row.dueDate || row.Due_Date__c,
      Return_Date__c: returnDate,
      Status__c: status,
      Renewal_Count__c: row.renewalCount ?? row.Renewal_Count__c,
      replacementRequired:
        row.replacementRequired ?? row.Replacement_Required__c ?? false,
      bookName:
        row.bookTitle || row.Book_Copy__r?.Book__r?.Name || "Book unavailable",
      coverUrl:
        row.coverUrl || row.Book_Copy__r?.Book__r?.Cover_Image_URL__c || "",
      barcode: row.barcode || row.Book_Copy__r?.Barcode__c || "—",
      issueDateLabel: this.formatDate(row.borrowDate || row.Borrow_Date__c),
      dueDateLabel: this.formatDate(row.dueDate || row.Due_Date__c),
      returnDateLabel: this.formatDate(returnDate),
      statusLabel: status,
      statusClass: this.badge(status)
    };
  }

  decorateReservation(row) {
    const status = row.status || row.Status__c;
    const statusLabel = status === "Pending" ? "Waiting" : status;
    return {
      ...row,
      Id: row.id || row.Id,
      Name: row.name || row.Name,
      Book__r: row.Book__r,
      Reservation_Date__c: row.reservationDate || row.Reservation_Date__c,
      Queue_Position__c: row.queuePosition ?? row.Queue_Position__c,
      Status__c: status,
      Ready_Date__c: row.readyDate || row.Ready_Date__c,
      Expiry_Date__c: row.expiryDate || row.Expiry_Date__c,
      Fulfilled_Date__c: row.fulfilledDate || row.Fulfilled_Date__c,
      Estimated_Available_Date__c:
        row.estimatedAvailableDate || row.Estimated_Available_Date__c,
      ETA_Confidence__c: row.etaConfidence || row.ETA_Confidence__c || "Low",
      ETA_Last_Calculated__c:
        row.etaLastCalculated || row.ETA_Last_Calculated__c,
      ETA_Reason__c: row.etaReason || row.ETA_Reason__c,
      bookName: row.bookName || row.Book__r?.Name || "Book unavailable",
      reservedDateLabel: this.formatDate(
        row.reservationDate || row.Reservation_Date__c
      ),
      estimatedDateLabel: this.formatDateTime(
        row.estimatedAvailableDate || row.Estimated_Available_Date__c
      ),
      etaLabel:
        (row.etaConfidence || row.ETA_Confidence__c || "Low") + " confidence",
      etaReason: row.etaReason || row.ETA_Reason__c || "Estimate unavailable",
      statusLabel,
      statusClass: this.badge(statusLabel),
      canCancel: ["Pending", "Ready"].includes(status)
    };
  }

  decoratePayment(row) {
    return {
      ...row,
      amountLabel: this.currency(row.Amount__c),
      dateLabel: this.formatDate(row.Payment_Date__c),
      statusClass: this.badge(row.Status__c),
      description: row.New_Plan__r?.Name || "Membership"
    };
  }

  badge(value) {
    return `badge badge-${String(value || "")
      .toLowerCase()
      .replaceAll(" ", "-")}`;
  }

  currency(value) {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0
    }).format(Number(value || 0));
  }

  formatDate(value) {
    if (!value) return "—";
    return new Intl.DateTimeFormat("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric"
    }).format(new Date(value));
  }

  formatDateTime(value) {
    if (!value) return "—";
    return new Intl.DateTimeFormat("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    }).format(new Date(value));
  }

  handleError(error, operation = "member operation") {
    const body = error?.body;
    const messages = [];
    const collectMessages = (value) => {
      if (!value) return;
      if (typeof value === "string") {
        messages.push(value);
        return;
      }
      if (Array.isArray(value)) {
        value.forEach((item) => collectMessages(item));
        return;
      }
      if (typeof value !== "object") return;
      if (value.message) messages.push(value.message);
      else if (value.errorMessage) messages.push(value.errorMessage);
      if (value.pageErrors) collectMessages(value.pageErrors);
      if (value.fieldErrors) collectMessages(Object.values(value.fieldErrors));
    };
    collectMessages(body);
    let rawBody;
    try {
      rawBody = body ? JSON.stringify(body) : undefined;
    } catch {
      rawBody = undefined;
    }
    const message =
      [...new Set(messages)].join(" ") ||
      error?.message ||
      (rawBody && `Salesforce error response: ${rawBody}`) ||
      (error?.status && `Salesforce request failed (${error.status}).`) ||
      "The operation could not be completed.";
    if (message.includes("MEMBER_SESSION_INVALID")) {
      sessionStorage.removeItem("libraryMemberSession");
      localStorage.removeItem("libraryMemberSession");
      window.location.replace("/library/login");
      return;
    }
    if (message.includes("MEMBER_REJECTED")) this.accessState = "rejected";
    else if (message.includes("MEMBER_PENDING_APPROVAL"))
      this.accessState = "pending";
    else if (
      message.includes("MEMBER_INACTIVE") ||
      message.includes("MEMBER_SUSPENDED")
    )
      this.accessState = "suspended";
    else if (message.includes("MEMBER_MAPPING_NOT_FOUND"))
      this.accessState = "pending";
    else this.error = message;
    const reference = `MEM-${Date.now().toString(36).toUpperCase()}`;
    console.error(
      `[LibraryMemberShell] ${operation} failed`,
      { reference, message },
      error
    );
    if (!this.accessState)
      this.toast("Member portal error", `${message} (${reference})`, "error");
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
