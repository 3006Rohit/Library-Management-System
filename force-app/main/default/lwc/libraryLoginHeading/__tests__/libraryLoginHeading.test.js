import { createElement } from "lwc";
import LibraryLoginHeading from "c/libraryLoginHeading";

describe("c-library-login-heading", () => {
  it("can be created", () => {
    const element = createElement("c-library-login-heading", {
      is: LibraryLoginHeading
    });
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });
});
