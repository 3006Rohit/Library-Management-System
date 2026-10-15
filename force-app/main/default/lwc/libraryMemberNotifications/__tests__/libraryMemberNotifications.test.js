import { createElement } from "lwc";
import LibraryMemberNotifications from "c/libraryMemberNotifications";
import getMyNotifications from "@salesforce/apex/LibraryMemberController.getMyNotifications";
import markNotificationRead from "@salesforce/apex/LibraryMemberController.markNotificationRead";

jest.mock(
  "@salesforce/apex/LibraryMemberController.getMyNotifications",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberController.markNotificationRead",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-member-notifications", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("maps unread state and marks a notification read", async () => {
    getMyNotifications.mockResolvedValue([
      { Id: "n-1", Status__c: "Unread", Subject__c: "Ready" }
    ]);
    markNotificationRead.mockResolvedValue({});
    const element = createElement("c-library-member-notifications", {
      is: LibraryMemberNotifications
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("Ready");
    element.shadowRoot.querySelector("lightning-button").click();
    await flush();
    expect(markNotificationRead).toHaveBeenCalledWith({
      notificationId: "n-1"
    });
  });

  it("uses a safe error when loading fails", async () => {
    getMyNotifications.mockRejectedValue({
      body: { message: "Access denied." }
    });
    const element = createElement("c-library-member-notifications", {
      is: LibraryMemberNotifications
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Access denied."
    );
  });
});
