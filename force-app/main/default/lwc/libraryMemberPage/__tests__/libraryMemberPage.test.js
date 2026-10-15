import { createElement } from "lwc";
import LibraryMemberPage from "c/libraryMemberPage";

describe("c-library-member-page", () => {
  it("can be mounted as the portal page shell", () => {
    const element = createElement("c-library-member-page", {
      is: LibraryMemberPage
    });
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });
});
