import { createElement } from "lwc";
import LibraryMemberBookCard from "c/libraryMemberBookCard";

describe("c-library-member-book-card", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
  });

  it("reports cover availability and emits the selected book", () => {
    const element = createElement("c-library-member-book-card", {
      is: LibraryMemberBookCard
    });
    element.book = {
      Id: "book-1",
      Name: "Clean Code",
      coverUrl: "https://example.test/cover.jpg"
    };
    const handler = jest.fn();
    element.addEventListener("bookaction", handler);
    document.body.appendChild(element);
    expect(element.shadowRoot.querySelector("img").getAttribute("src")).toBe(
      "https://example.test/cover.jpg"
    );
    element.shadowRoot.querySelector("button").click();
    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({ detail: { id: "book-1" } })
    );
  });
});
