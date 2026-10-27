import { createElement } from "lwc";
import LibraryMemberAuthorFollows from "c/libraryMemberAuthorFollows";
import getMyAuthorFollows from "@salesforce/apex/LibraryMemberSessionController.getMyAuthorFollows";
import unfollowAuthor from "@salesforce/apex/LibraryMemberSessionController.unfollowAuthor";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyAuthorFollows",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.unfollowAuthor",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-member-author-follows", () => {
  beforeEach(() => sessionStorage.setItem("libraryMemberSession", "session-1"));
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    sessionStorage.clear();
    jest.clearAllMocks();
  });

  it("renders followed authors and supports unfollow", async () => {
    getMyAuthorFollows.mockResolvedValue([
      {
        id: "follow-1",
        authorId: "author-1",
        authorName: "Octavia Butler",
        followedAt: "2026-10-15"
      }
    ]);
    unfollowAuthor.mockResolvedValue({});
    const element = createElement("c-library-member-author-follows", {
      is: LibraryMemberAuthorFollows
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("Octavia Butler");
    element.shadowRoot.querySelector("button.remove").click();
    await flush();
    expect(unfollowAuthor).toHaveBeenCalledWith({
      sessionToken: "session-1",
      followId: "follow-1"
    });
  });

  it("shows a safe load error", async () => {
    getMyAuthorFollows.mockRejectedValue({
      body: { message: "Access denied." }
    });
    const element = createElement("c-library-member-author-follows", {
      is: LibraryMemberAuthorFollows
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Access denied."
    );
  });
});
