import { createElement } from "lwc";
import LibraryMemberBookCard from "c/libraryMemberBookCard";

describe("c-library-member-book-card", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
  });

  it("passes the cover details on and emits the selected book", () => {
    const element = createElement("c-library-member-book-card", {
      is: LibraryMemberBookCard
    });
    element.book = {
      Id: "book-1",
      Name: "Clean Code",
      authors: "Robert Martin",
      coverUrl: "https://example.test/cover.jpg"
    };
    const handler = jest.fn();
    element.addEventListener("bookaction", handler);
    document.body.appendChild(element);
    const cover = element.shadowRoot.querySelector("c-library-book-cover");
    expect(cover.coverUrl).toBe("https://example.test/cover.jpg");
    expect(cover.title).toBe("Clean Code");
    expect(cover.author).toBe("Robert Martin");
    element.shadowRoot.querySelector("button").click();
    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({ detail: { id: "book-1" } })
    );
  });
});
