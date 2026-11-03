import { createElement } from "lwc";
import LibraryBookCover from "c/libraryBookCover";

function mount(props) {
  const element = createElement("c-library-book-cover", {
    is: LibraryBookCover
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

describe("c-library-book-cover", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
  });

  it("shows the cover image when a URL exists", () => {
    const element = mount({
      title: "Clean Code",
      coverUrl: "https://example.test/cover.jpg"
    });
    const img = element.shadowRoot.querySelector("img");
    expect(img.getAttribute("src")).toBe("https://example.test/cover.jpg");
    expect(element.shadowRoot.querySelector(".placeholder")).toBeNull();
  });

  it("draws a titled cover when there is no image", () => {
    const element = mount({
      title: "Years of Discovery",
      author: "Mason Reed"
    });
    const cover = element.shadowRoot.querySelector(".placeholder");
    expect(cover.textContent).toContain("Years of Discovery");
    expect(cover.textContent).toContain("Mason Reed");
    expect(cover.getAttribute("style")).toContain("background-color");
  });

  it("renders a small thumbnail with the title's first letter", () => {
    const element = mount({ title: "years of discovery", size: "thumb" });
    expect(element.shadowRoot.querySelector(".cover.thumb")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".initial").textContent).toBe("Y");
  });

  it("uses a stable colour per title and hides unknown authors", () => {
    const first = mount({ title: "Same Title", author: "Author unavailable" });
    const second = mount({ title: "Same Title" });
    expect(first.shadowRoot.querySelector(".book-author")).toBeNull();
    expect(
      first.shadowRoot.querySelector(".placeholder").getAttribute("style")
    ).toBe(
      second.shadowRoot.querySelector(".placeholder").getAttribute("style")
    );
  });
});
