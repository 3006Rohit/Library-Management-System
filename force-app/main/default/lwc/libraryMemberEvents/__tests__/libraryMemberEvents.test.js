import { createElement } from "lwc";
import LibraryMemberEvents from "c/libraryMemberEvents";
import getUpcomingEvents from "@salesforce/apex/LibraryMemberSessionController.getUpcomingEvents";
import registerForEvent from "@salesforce/apex/LibraryMemberSessionController.registerForEvent";
import issueEventCheckInToken from "@salesforce/apex/LibraryMemberSessionController.issueEventCheckInToken";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getUpcomingEvents",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.registerForEvent",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.issueEventCheckInToken",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-member-events", () => {
  beforeEach(() => sessionStorage.setItem("libraryMemberSession", "session-1"));
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    sessionStorage.clear();
    jest.clearAllMocks();
  });

  it("renders events and registers", async () => {
    getUpcomingEvents.mockResolvedValue([
      {
        id: "event-1",
        title: "Story Hour",
        description: "Read together",
        startAt: "tomorrow",
        endAt: "later",
        location: "Main Hall",
        registeredCount: 0,
        capacity: 10
      }
    ]);
    registerForEvent.mockResolvedValue({
      id: "event-1",
      title: "Story Hour",
      registrationStatus: "Registered",
      registeredCount: 1,
      capacity: 10
    });
    const element = createElement("c-library-member-events", {
      is: LibraryMemberEvents
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("Story Hour");
    element.shadowRoot.querySelector("button.primary").click();
    await flush();
    expect(registerForEvent).toHaveBeenCalledWith({
      sessionToken: "session-1",
      eventId: "event-1"
    });
    issueEventCheckInToken.mockResolvedValue("check-in-code");
    element.shadowRoot.querySelector("button.secondary").click();
    await flush();
    expect(issueEventCheckInToken).toHaveBeenCalledWith({
      sessionToken: "session-1",
      eventId: "event-1"
    });
  });

  it("shows a safe load error", async () => {
    getUpcomingEvents.mockRejectedValue({
      body: { message: "Access denied." }
    });
    const element = createElement("c-library-member-events", {
      is: LibraryMemberEvents
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Access denied."
    );
  });
});
