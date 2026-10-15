import { createElement } from "lwc";
import LibraryMemberLogin from "c/libraryMemberLogin";
import login from "@salesforce/apex/LibraryMemberAuthController.login";

jest.mock(
  "@salesforce/apex/LibraryMemberAuthController.login",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

describe("c-library-member-login", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    sessionStorage.clear();
    localStorage.clear();
    jest.clearAllMocks();
  });

  it("stores the session token after successful login", async () => {
    login.mockResolvedValue({ sessionToken: "session-1" });
    const element = createElement("c-library-member-login", {
      is: LibraryMemberLogin
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector("lightning-button").click();
    await Promise.resolve()
      .then(() => Promise.resolve())
      .then(() => Promise.resolve());
    expect(sessionStorage.getItem("libraryMemberSession")).toBe("session-1");
    expect(localStorage.getItem("libraryMemberSession")).toBeNull();
  });

  it("exposes a safe authentication error", async () => {
    login.mockRejectedValue({
      body: { message: "Invalid email or password." }
    });
    const element = createElement("c-library-member-login", {
      is: LibraryMemberLogin
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector("lightning-button").click();
    await Promise.resolve()
      .then(() => Promise.resolve())
      .then(() => Promise.resolve());
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Invalid email or password."
    );
  });
});
