import { createElement } from "lwc";
import LibraryAuthHero from "c/libraryAuthHero";

describe("c-library-auth-hero", () => {
  it("exposes the configured hero background", () => {
    const element = createElement("c-library-auth-hero", {
      is: LibraryAuthHero
    });
    document.body.appendChild(element);
    expect(
      element.shadowRoot.querySelector(".auth-hero").style.backgroundImage
    ).toContain("url(");
  });
});
