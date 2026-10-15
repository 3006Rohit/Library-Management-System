import { createElement } from "lwc";
import LibraryRegistrationRedirect from "c/libraryRegistrationRedirect";

jest.mock("@salesforce/user/isGuest", () => ({ default: false }), {
  virtual: true
});

describe("c-library-registration-redirect", () => {
  it("does not redirect an authenticated user", () => {
    const element = createElement("c-library-registration-redirect", {
      is: LibraryRegistrationRedirect
    });
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });
});
