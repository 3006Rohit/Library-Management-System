import { createElement } from "lwc";
import LibraryMemberShell from "c/libraryMemberShell";
import getCurrentMemberContext from "@salesforce/apex/LibraryMemberSessionController.getCurrentMemberContext";
import getMyDashboard from "@salesforce/apex/LibraryMemberSessionController.getMyDashboard";
import getMyAnalytics from "@salesforce/apex/LibraryMemberSessionController.getMyAnalytics";
import getSuggestedBooks from "@salesforce/apex/LibraryMemberSessionController.getSuggestedBooks";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getCurrentMemberContext",
  () => ({ default: jest.fn(() => Promise.resolve({})) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyDashboard",
  () => ({
    default: jest.fn(() =>
      Promise.resolve({
        activeLoans: 0,
        dueSoon: 0,
        overdueLoans: 0,
        activeReservations: 0,
        outstandingFine: 0,
        loans: [],
        reservations: []
      })
    )
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyAnalytics",
  () => ({
    default: jest.fn(() =>
      Promise.resolve({
        available: true,
        refreshCadence: "Real-time Salesforce transaction data",
        totalLoans: 0,
        activeLoans: 0,
        returnedLoans: 0,
        overdueLoans: 0,
        totalReservations: 0,
        activeReservationCount: 0,
        totalFineCount: 0,
        unpaidFineCount: 0
      })
    )
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getSuggestedBooks",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.searchCatalog",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getCatalogCategories",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getBookDetails",
  () => ({ default: jest.fn(() => Promise.resolve({})) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.borrowBook",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyBorrowings",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.renewMyLoan",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyReservations",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.reserveBook",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.cancelMyReservation",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyFines",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyMembership",
  () => ({ default: jest.fn(() => Promise.resolve({})) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyPayments",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getUpgradePlans",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.payForMembershipUpgrade",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.renewMyMembership",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyProfile",
  () => ({ default: jest.fn(() => Promise.resolve({})) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.updateMyProfile",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyNotifications",
  () => ({ default: jest.fn(() => Promise.resolve([])) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.markNotificationRead",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: class ShowToastEvent extends CustomEvent {
      constructor(detail) {
        super("lightning__showtoast", { detail });
      }
    }
  }),
  { virtual: true }
);
const flushPromises = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("libraryMemberShell state safety", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
  });

  it("does not dereference member or plan data before Apex resolves", async () => {
    let resolveContext;
    getCurrentMemberContext.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolveContext = resolve;
        })
    );
    const element = createElement("c-library-member-shell", {
      is: LibraryMemberShell
    });
    document.body.appendChild(element);
    expect(
      element.shadowRoot.querySelector("lightning-spinner")
    ).not.toBeNull();
    expect(element.shadowRoot.querySelector(".metric-grid")).toBeNull();
    expect(element.shadowRoot.querySelector(".error-banner")).toBeNull();
    resolveContext({});
    await flushPromises();
  });

  it("renders a safe missing-plan state without throwing", async () => {
    getCurrentMemberContext.mockResolvedValueOnce({
      First_Name__c: "Khushi",
      Membership_End_Date__c: "2027-10-07"
    });
    getMyDashboard.mockResolvedValueOnce({
      activeLoans: 0,
      dueSoon: 0,
      overdueLoans: 0,
      activeReservations: 0,
      outstandingFine: 0,
      recentLoans: [],
      recentReservations: []
    });
    const element = createElement("c-library-member-shell", {
      is: LibraryMemberShell
    });
    document.body.appendChild(element);
    await flushPromises();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".member-analytics-panel")
    ).not.toBeNull();
    expect(element.shadowRoot.querySelector(".metric-grid")).toBeNull();
  });

  it("renders authenticated member Data Cloud activity metrics", async () => {
    getCurrentMemberContext.mockResolvedValueOnce({
      First_Name__c: "Member",
      Last_Name__c: "One"
    });
    getMyAnalytics.mockResolvedValueOnce({
      available: true,
      totalLoans: 5,
      activeLoans: 2,
      returnedLoans: 3,
      overdueLoans: 0,
      totalReservations: 1,
      activeReservationCount: 1,
      totalFineCount: 1,
      unpaidFineCount: 1,
      refreshCadence: "Real-time Salesforce transaction data"
    });
    const element = createElement("c-library-member-shell", {
      is: LibraryMemberShell
    });
    document.body.appendChild(element);
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".member-analytics-panel").textContent
    ).toContain("My Library Activity");
    expect(
      element.shadowRoot.querySelector(".member-analytics-panel").textContent
    ).toContain("5");
  });

  it("renders personalized book suggestions on the dashboard", async () => {
    getCurrentMemberContext.mockResolvedValueOnce({
      First_Name__c: "Member",
      Interests__c: "Science Fiction"
    });
    getSuggestedBooks.mockResolvedValueOnce([
      {
        Id: "book-1",
        Name: "A Suggested Book",
        Available_Copies__c: 2,
        Book_Authors__r: [{ Author__r: { Name: "An Author" } }],
        Book_Category_Links__r: [
          { Book_Category__r: { Name: "Science Fiction" } }
        ]
      }
    ]);
    const element = createElement("c-library-member-shell", {
      is: LibraryMemberShell
    });
    document.body.appendChild(element);
    await flushPromises();
    const panel = element.shadowRoot.querySelector(".recommended-panel");
    expect(panel).not.toBeNull();
    expect(panel.textContent).toContain("Recommended Books");
    expect(panel.querySelectorAll("c-library-member-book-card")).toHaveLength(
      1
    );
  });

  it("surfaces the exact Apex diagnostic when the member context fails", async () => {
    getCurrentMemberContext.mockRejectedValueOnce({
      body: {
        message:
          "MEMBER_PORTAL_ERROR [MEMBER_MAPPING_NOT_FOUND]: No active Member record is linked."
      }
    });
    const element = createElement("c-library-member-shell", {
      is: LibraryMemberShell
    });
    document.body.appendChild(element);
    await flushPromises();
    const state = element.shadowRoot.querySelector("c-library-auth-state");
    expect(state).not.toBeNull();
    expect(state.title).toBe("Registration Submitted!");
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });
});
