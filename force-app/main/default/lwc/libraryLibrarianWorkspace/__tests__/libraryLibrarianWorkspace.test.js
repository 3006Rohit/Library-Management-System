import { createElement } from "lwc";
import LibraryLibrarianWorkspace from "c/libraryLibrarianWorkspace";
import getDashboard from "@salesforce/apex/LibraryLibrarianController.getDashboard";
import getDashboardAnalytics from "@salesforce/apex/LibraryLibrarianController.getDashboardAnalytics";
import searchBooks from "@salesforce/apex/LibraryLibrarianController.searchBooks";
import searchCopies from "@salesforce/apex/LibraryLibrarianController.searchCopies";
import searchMembers from "@salesforce/apex/LibraryLibrarianController.searchMembers";
import getMemberDetail from "@salesforce/apex/LibraryLibrarianController.getMemberDetail";
import getRegistrations from "@salesforce/apex/LibraryLibrarianController.getRegistrations";
import getReservations from "@salesforce/apex/LibraryLibrarianController.getReservations";
import getFines from "@salesforce/apex/LibraryLibrarianController.getFines";
import getMembershipPlans from "@salesforce/apex/LibraryLibrarianController.getMembershipPlans";
import getPayments from "@salesforce/apex/LibraryLibrarianController.getPayments";
import getLibrarySettings from "@salesforce/apex/LibrarySettingsController.getSettings";
import saveLibrarySettings from "@salesforce/apex/LibrarySettingsController.saveSettings";
import startAgentSession from "@salesforce/apex/LibraryAgentApiController.startSession";
import sendAgentMessage from "@salesforce/apex/LibraryAgentApiController.sendMessage";

jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getDashboard",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getDashboardAnalytics",
  () => ({
    default: jest.fn(() =>
      Promise.resolve({
        available: false,
        topBorrowedBooks: [],
        reservationDemand: []
      })
    )
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.searchBooks",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.searchCopies",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.searchMembers",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getMemberDetail",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getRegistrations",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getReservations",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getFines",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getMembershipPlans",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getPayments",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibrarySettingsController.getSettings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibrarySettingsController.saveSettings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAgentApiController.startSession",
  () => ({
    default: jest.fn(() => Promise.resolve({ sessionId: "test-session" }))
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAgentApiController.sendMessage",
  () => ({
    default: jest.fn(() =>
      Promise.resolve({ message: "There are 350 copies available." })
    )
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAgentApiController.endSession",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getAuthors",
  () => ({ default: jest.fn().mockResolvedValue([]) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getCategories",
  () => ({ default: jest.fn().mockResolvedValue([]) }),
  { virtual: true }
);

const flushPromises = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("libraryLibrarianWorkspace", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("renders all live dashboard metrics in the shared shell", async () => {
    getDashboard.mockResolvedValue({
      totalBooks: 12,
      totalCopies: 30,
      totalMembers: 8,
      activeLoans: 4,
      overdueLoans: 1,
      pendingReservations: 2,
      unpaidFines: 3,
      membershipRevenue: 2500,
      recentLoans: []
    });
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll(".nav-item")).toHaveLength(13);
    expect(element.shadowRoot.querySelectorAll(".metric-card")).toHaveLength(0);
    expect(
      element.shadowRoot.querySelector(".page-heading h1").textContent
    ).toBe("Dashboard");
  });

  it("opens the Librarian Assistant tab without loading transactional data", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();

    const assistantButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.includes("Librarian Assistant"));
    assistantButton.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".lib-assistant-page")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector(".lib-assistant-hero h1").textContent
    ).toBe("Librarian Assistant");
    expect(
      element.shadowRoot.querySelector(".lib-assistant-chat-card")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector("c-library-agent-assistant")
    ).toBeNull();
    expect(searchBooks).not.toHaveBeenCalled();
  });

  it("renders the inline Agentforce response in the custom chat", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const assistantButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.includes("Librarian Assistant"));
    assistantButton.click();
    await flushPromises();
    const input = element.shadowRoot.querySelector(
      ".lib-assistant-composer input"
    );
    input.value = "How many copies are available?";
    input.dispatchEvent(new CustomEvent("input"));
    element.shadowRoot
      .querySelector(".lib-assistant-composer")
      .dispatchEvent(new CustomEvent("submit"));
    await flushPromises();

    expect(startAgentSession).toHaveBeenCalled();
    expect(sendAgentMessage).toHaveBeenCalledWith({
      sessionId: "test-session",
      sequenceId: 1,
      text: "How many copies are available?"
    });
    expect(
      element.shadowRoot.querySelector(".lib-assistant-messages").textContent
    ).toContain("There are 350 copies available.");
  });

  it("loads books when Books is selected", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    searchBooks.mockResolvedValue([
      { Id: "book-1", Name: "Clean Code", Status__c: "Active" }
    ]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const booksButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.includes("Books"));
    booksButton.click();
    await flushPromises();

    expect(searchBooks).toHaveBeenCalled();
    expect(
      element.shadowRoot.querySelector(".page-heading h1").textContent
    ).toBe("Books");
    expect(element.shadowRoot.querySelector("tbody").textContent).toContain(
      "Clean Code"
    );
  });

  it("renders Data Cloud analytics without replacing transactional dashboard data", async () => {
    getDashboard.mockResolvedValue({ totalBooks: 2, recentLoans: [] });
    getDashboardAnalytics.mockResolvedValue({
      available: true,
      refreshCadence: "Live Salesforce data • refreshes after changes",
      copyMetrics: {
        totalCopies: 10,
        availableCopies: 8,
        borrowedCopies: 1,
        reservedCopies: 1,
        lostCopies: 0
      },
      loanMetrics: {
        totalLoans: 4,
        activeLoans: 1,
        returnedLoans: 3,
        overdueLoans: 0
      },
      reservationMetrics: {
        totalReservations: 2,
        fulfilledReservations: 1,
        cancelledReservations: 1,
        pendingReservations: 0,
        readyReservations: 0,
        expiredReservations: 0
      },
      fineMetrics: { totalFineCount: 1, paidFineCount: 1, unpaidFineCount: 0 },
      topBorrowedBooks: [
        { bookId: "book-1", bookName: "1984", borrowCount: 4 }
      ],
      reservationDemand: [
        { bookId: "book-1", bookName: "1984", totalReservations: 2 }
      ]
    });
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".data-cloud-panel").textContent
    ).toContain("Top Borrowed Books");
    expect(
      element.shadowRoot.querySelector(".data-cloud-panel").textContent
    ).toContain("1984");
  });

  it("opens Add Copy with an explicit book selector", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    searchBooks.mockResolvedValue([
      { Id: "book-1", Name: "Clean Code", Status__c: "Active" }
    ]);
    searchCopies.mockResolvedValue([]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const copiesButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.includes("Book Copies"));
    copiesButton.click();
    await flushPromises();
    element.shadowRoot.querySelector(".top-actions-row .primary").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".modal-card h2").textContent).toBe(
      "Add New Copy"
    );
    expect(element.shadowRoot.querySelector(".copy-book-field")).not.toBeNull();
  });

  it("opens Add Book as the compact reference-style workspace page", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    searchBooks.mockResolvedValue([]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const booksButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Books");
    booksButton.click();
    await flushPromises();
    element.shadowRoot.querySelector(".top-actions-row .primary").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".book-page-modal")).not.toBeNull();
    expect(
      element.shadowRoot.querySelector(".book-page-card h2").textContent
    ).toBe("Add New Book");
    expect(
      element.shadowRoot.querySelectorAll(".book-form lightning-combobox")
    ).toHaveLength(2);
    expect(
      element.shadowRoot.querySelector("lightning-dual-listbox")
    ).toBeNull();
    expect(element.shadowRoot.querySelector(".cover-preview")).not.toBeNull();
  });

  it("opens the reference-style member details workspace", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    searchMembers.mockResolvedValue([
      {
        Id: "member-1",
        Name: "M-0001",
        First_Name__c: "Rohit",
        Last_Name__c: "Mehta",
        Email__c: "rohit@example.com",
        Status__c: "Active",
        Membership_Plan__r: { Name: "Premium" }
      }
    ]);
    getMemberDetail.mockResolvedValue({
      member: {
        Id: "member-1",
        Name: "M-0001",
        First_Name__c: "Rohit",
        Last_Name__c: "Mehta",
        Email__c: "rohit@example.com",
        Phone__c: "9999999999",
        Account_Status__c: "Active",
        Membership_Plan__r: { Name: "Premium" }
      },
      loans: [],
      reservations: [],
      fines: [],
      payments: [],
      outstandingBalance: 0
    });
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const membersButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Members");
    membersButton.click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".members-toolbar")).not.toBeNull();
    expect(element.shadowRoot.querySelector("tbody").textContent).toContain(
      "Rohit Mehta"
    );
    element.shadowRoot.querySelector(".action-link").click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".page-heading h1").textContent
    ).toBe("Member Details");
    expect(
      element.shadowRoot.querySelector(".member-profile-card")
    ).not.toBeNull();
    expect(element.shadowRoot.querySelectorAll(".member-tab")).toHaveLength(6);
    expect(
      element.shadowRoot.querySelectorAll(".member-overview-grid article")
    ).toHaveLength(4);
  });

  it("renders registrations with reference-style tabs and actions", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    getRegistrations.mockResolvedValue([
      {
        Id: "registration-1",
        First_Name__c: "Neha",
        Last_Name__c: "Gupta",
        Email__c: "neha@example.com",
        Registration_Date__c: "2026-10-10",
        Status__c: "Pending"
      }
    ]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const registrationsButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Registrations");
    registrationsButton.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelectorAll(".registration-tab")
    ).toHaveLength(3);
    expect(
      element.shadowRoot.querySelectorAll(".registrations-table th")
    ).toHaveLength(5);
    expect(
      element.shadowRoot.querySelectorAll(
        ".registrations-table .row-actions button"
      )
    ).toHaveLength(3);
    expect(
      element.shadowRoot.querySelector(".registrations-table").textContent
    ).toContain("Neha Gupta");
  });

  it("renders the reference-style reservations list", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    searchBooks.mockResolvedValue([]);
    searchMembers.mockResolvedValue([]);
    getReservations.mockResolvedValue([
      {
        Id: "reservation-1",
        Name: "RS-0001",
        Member__r: { Name: "Priya Patel" },
        Book__r: { Name: "The Pragmatic Programmer" },
        Book_Copy__c: "copy-1",
        Reservation_Date__c: "2026-10-10",
        Status__c: "Ready",
        Queue_Position__c: 1
      },
      {
        Id: "reservation-2",
        Name: "RS-0002",
        Member__r: { Name: "Abhay Gupta" },
        Book__r: { Name: "1984" },
        Reservation_Date__c: "2026-10-10",
        Status__c: "Pending",
        Queue_Position__c: 1
      }
    ]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const reservationsButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Reservations");
    reservationsButton.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelectorAll(".reservation-tab")
    ).toHaveLength(4);
    expect(
      element.shadowRoot.querySelector(".reservation-search")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelectorAll(".reservations-table th")
    ).toHaveLength(7);
    expect(
      element.shadowRoot.querySelector(".reservations-table").textContent
    ).toContain("The Pragmatic Programmer");
    expect(
      element.shadowRoot.querySelector(".reservations-table .action-link")
        .textContent
    ).toBe("View");
    element.shadowRoot
      .querySelector(".reservations-table .action-link")
      .click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".issue-reservation-button")
    ).not.toBeNull();
    element.shadowRoot.querySelector(".modal-close").click();
    await flushPromises();
    element.shadowRoot
      .querySelectorAll(".reservations-table .action-link")[1]
      .click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".prepare-reservation-button")
    ).not.toBeNull();
  });

  it("renders the reference-style fines list and collection dialog", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    getFines.mockResolvedValue([
      {
        Id: "fine-1",
        Name: "F-0001",
        Member__r: { Name: "Karan Sharma" },
        Borrow_Record__r: { Name: "BR-0003" },
        Amount__c: 50,
        Balance__c: 50,
        Fine_Type__c: "Overdue",
        Status__c: "Unpaid"
      }
    ]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const finesButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Fines");
    finesButton.click();
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll(".fine-tab")).toHaveLength(2);
    expect(element.shadowRoot.querySelector(".fine-search")).not.toBeNull();
    expect(element.shadowRoot.querySelectorAll(".fines-table th")).toHaveLength(
      7
    );
    expect(
      element.shadowRoot.querySelector(".fines-table").textContent
    ).toContain("Overdue book");
    element.shadowRoot.querySelector(".fines-table .action-link").click();
    await flushPromises();
    expect(element.shadowRoot.querySelector(".fine-modal-card")).not.toBeNull();
  });

  it("renders membership plans with tabs, actions and the plan dialog", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    searchMembers.mockResolvedValue([]);
    getMembershipPlans.mockResolvedValue([
      {
        Id: "plan-1",
        Name: "Student Plan",
        Description__c: "For students",
        Duration_Days__c: 90,
        Borrow_Limit__c: 3,
        Fee__c: 0,
        Active__c: true
      }
    ]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const membershipsButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Memberships");
    membershipsButton.click();
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll(".tabs .tab")).toHaveLength(2);
    expect(
      element.shadowRoot.querySelectorAll(".memberships-table th")
    ).toHaveLength(7);
    expect(
      element.shadowRoot.querySelector(".memberships-table").textContent
    ).toContain("3 Months");
    expect(
      element.shadowRoot.querySelector(".memberships-table").textContent
    ).toContain("Free");
    element.shadowRoot.querySelector(".membership-toolbar button").click();
    await flushPromises();
    expect(element.shadowRoot.querySelector(".plan-modal-card")).not.toBeNull();
    expect(element.shadowRoot.querySelectorAll(".plan-field")).toHaveLength(4);
  });

  it("renders the reference-style payments table and working filters", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    getPayments.mockResolvedValue([
      {
        id: "payment-1",
        name: "P-0001",
        memberName: "Rohit Mehta",
        paymentType: "Membership",
        amount: 500,
        paymentDate: "2026-10-10T00:00:00.000Z",
        status: "Paid",
        reference: "MEM-REF-1"
      },
      {
        id: "fine-1",
        name: "F-0001",
        memberName: "Karan Sharma",
        paymentType: "Fine",
        amount: 50,
        paymentDate: "2026-10-08T00:00:00.000Z",
        status: "Paid",
        reference: "BR-0003"
      }
    ]);
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const paymentsButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Payments");
    paymentsButton.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelectorAll(".payment-tabs .tab")
    ).toHaveLength(3);
    expect(
      element.shadowRoot.querySelectorAll(".payments-table th")
    ).toHaveLength(7);
    expect(
      element.shadowRoot.querySelectorAll(".payments-table tbody tr")
    ).toHaveLength(2);
    element.shadowRoot.querySelectorAll(".payment-tabs .tab")[2].click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelectorAll(".payments-table tbody tr")
    ).toHaveLength(1);
    element.shadowRoot.querySelector(".payments-table .action-link").click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".payment-detail-modal")
    ).not.toBeNull();
  });

  it("loads and saves functional librarian settings", async () => {
    getDashboard.mockResolvedValue({ recentLoans: [] });
    getMembershipPlans.mockResolvedValue([]);
    getLibrarySettings.mockResolvedValue({
      Id: "settings-1",
      Library_Name__c: "Central Library",
      Contact_Email__c: "library@example.com",
      Reservation_Hold_Days__c: 5,
      Due_Reminder_Days__c: 2,
      Max_Search_Results__c: 150,
      Send_Due_Reminders__c: true,
      Send_Overdue_Notices__c: true,
      Send_Reservation_Notifications__c: true,
      Allow_Self_Registration__c: true,
      Require_Email_Verification__c: true,
      Auto_Process_Expired_Holds__c: true,
      Fine_Payment_Enabled__c: true
    });
    saveLibrarySettings.mockResolvedValue("settings-1");
    const element = createElement("c-library-librarian-workspace", {
      is: LibraryLibrarianWorkspace
    });
    document.body.appendChild(element);
    await flushPromises();
    const settingsButton = [
      ...element.shadowRoot.querySelectorAll(".nav-item")
    ].find((button) => button.textContent.trim() === "Settings");
    settingsButton.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelectorAll(".editable-settings-card")
    ).toHaveLength(4);
    expect(
      element.shadowRoot.querySelectorAll(".settings-actions button")
    ).toHaveLength(4);
    element.shadowRoot.querySelectorAll(".settings-field").forEach((field) => {
      field.reportValidity = jest.fn();
      field.checkValidity = jest.fn(() => true);
    });
    element.shadowRoot.querySelector(".settings-toolbar button").click();
    await flushPromises();
    expect(saveLibrarySettings).toHaveBeenCalledWith(
      expect.objectContaining({
        settingsId: "settings-1",
        libraryName: "Central Library",
        reservationHoldDays: 5
      })
    );
  });
});
