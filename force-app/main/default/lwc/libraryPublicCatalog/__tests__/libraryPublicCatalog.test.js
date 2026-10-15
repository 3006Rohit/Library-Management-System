import { createElement } from "lwc";
import LibraryPublicCatalog from "c/libraryPublicCatalog";
import searchPublicCatalog from "@salesforce/apex/LibraryRegistrationGuestController.searchPublicCatalog";

jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.searchPublicCatalog",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-public-catalog", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("normalizes availability labels and searches on Enter", async () => {
    searchPublicCatalog.mockResolvedValue([
      {
        id: "b-1",
        title: "Clean Code",
        availableCopies: 2,
        publicationYear: 2008
      }
    ]);
    const element = createElement("c-library-public-catalog", {
      is: LibraryPublicCatalog
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("2 available");
    expect(element.shadowRoot.textContent).toContain(" · 2008");
    const input = element.shadowRoot.querySelector(
      'input[aria-label="Search catalog"]'
    );
    input.value = "clean";
    input.dispatchEvent(new CustomEvent("input"));
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flush();
    expect(searchPublicCatalog).toHaveBeenLastCalledWith({
      searchTerm: "clean"
    });
  });

  it("shows the unavailable label for zero copies", async () => {
    searchPublicCatalog.mockResolvedValue([
      { id: "b-2", title: "Unavailable", availableCopies: 0 }
    ]);
    const element = createElement("c-library-public-catalog", {
      is: LibraryPublicCatalog
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("Currently unavailable");
  });
});
