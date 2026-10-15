import { createElement } from "lwc";
import LibrarySignupLink from "c/librarySignupLink";

describe("c-library-signup-link", () => {
  it("can be mounted", () => {
    const element = createElement("c-library-signup-link", {
      is: LibrarySignupLink
    });
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });
});
