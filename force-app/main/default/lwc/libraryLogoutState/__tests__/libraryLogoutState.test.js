import { createElement } from "lwc";
import LibraryLogoutState from "c/libraryLogoutState";
import logout from "@salesforce/apex/LibraryMemberAuthController.logout";

jest.mock(
  "@salesforce/apex/LibraryMemberAuthController.logout",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

describe("c-library-logout-state", () => {
  afterEach(() => {
    sessionStorage.clear();
    localStorage.clear();
    jest.clearAllMocks();
  });

  it("revokes the stored session and clears the browser token", async () => {
    sessionStorage.setItem("libraryMemberSession", "session-1");
    const element = createElement("c-library-logout-state", {
      is: LibraryLogoutState
    });
    document.body.appendChild(element);
    await Promise.resolve();
    expect(logout).toHaveBeenCalledWith({ sessionToken: "session-1" });
    expect(sessionStorage.getItem("libraryMemberSession")).toBeNull();
    expect(localStorage.getItem("libraryMemberSession")).toBeNull();
  });

  it("revokes and removes a legacy persistent token", async () => {
    localStorage.setItem("libraryMemberSession", "legacy-session");
    const element = createElement("c-library-logout-state", {
      is: LibraryLogoutState
    });
    document.body.appendChild(element);
    await Promise.resolve();
    expect(logout).toHaveBeenCalledWith({ sessionToken: "legacy-session" });
    expect(localStorage.getItem("libraryMemberSession")).toBeNull();
  });
});
