import { createElement } from "lwc";
import LibraryDigitalMemberCard from "c/libraryDigitalMemberCard";
import issueCard from "@salesforce/apex/LibraryMemberSessionController.issueMyDigitalMemberCard";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.issueMyDigitalMemberCard",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-digital-member-card", () => {
  beforeEach(() => sessionStorage.setItem("libraryMemberSession", "session-1"));
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    sessionStorage.clear();
    jest.clearAllMocks();
  });

  it("renders a secure card token and refreshes it", async () => {
    issueCard.mockResolvedValue({
      valid: true,
      token: "opaque-token",
      memberName: "Digital Card",
      memberNumber: "MEM-1",
      membershipPlan: "Standard",
      membershipStatus: "Active",
      expiresAt: "2026-10-17T12:00:00.000Z"
    });
    const element = createElement("c-library-digital-member-card", {
      is: LibraryDigitalMemberCard
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("opaque-token");
    expect(issueCard).toHaveBeenCalledWith({ sessionToken: "session-1" });
    element.shadowRoot.querySelector("button.secondary").click();
    await flush();
    expect(issueCard).toHaveBeenCalledTimes(2);
  });

  it("shows a safe error when token issuance fails", async () => {
    issueCard.mockRejectedValue({ body: { message: "Session expired." } });
    const element = createElement("c-library-digital-member-card", {
      is: LibraryDigitalMemberCard
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Session expired."
    );
  });
});
