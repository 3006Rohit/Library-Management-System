import { createElement } from "lwc";
import LibraryMemberEngagement from "c/libraryMemberEngagement";
import getMyEngagements from "@salesforce/apex/LibraryMemberSessionController.getMyEngagements";
import removeMyEngagement from "@salesforce/apex/LibraryMemberSessionController.removeMyEngagement";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyEngagements",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.removeMyEngagement",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-member-engagement", () => {
  beforeEach(() => sessionStorage.setItem("libraryMemberSession", "session-1"));
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    sessionStorage.clear();
    jest.clearAllMocks();
  });

  it("renders private reading progress and removes an entry", async () => {
    getMyEngagements.mockResolvedValue([
      {
        id: "eng-1",
        bookId: "book-1",
        bookTitle: "A Quiet Library",
        state: "Want to Read",
        privateNotes: "Try this next",
        rating: null,
        notifyWhenAvailable: false,
        lastUpdated: "2026-10-15T10:00:00.000Z"
      }
    ]);
    removeMyEngagement.mockResolvedValue({});
    const element = createElement("c-library-member-engagement", {
      is: LibraryMemberEngagement
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("A Quiet Library");
    expect(element.shadowRoot.querySelector("lightning-input").value).toBe(
      "Try this next"
    );
    element.shadowRoot.querySelector("button.remove").click();
    await flush();
    expect(removeMyEngagement).toHaveBeenCalledWith({
      sessionToken: "session-1",
      engagementId: "eng-1"
    });
  });

  it("surfaces a safe loading error", async () => {
    getMyEngagements.mockRejectedValue({ body: { message: "Access denied." } });
    const element = createElement("c-library-member-engagement", {
      is: LibraryMemberEngagement
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Access denied."
    );
  });
});
