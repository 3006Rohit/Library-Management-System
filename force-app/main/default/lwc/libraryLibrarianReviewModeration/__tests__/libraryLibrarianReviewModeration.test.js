import { createElement } from "lwc";
import LibraryLibrarianReviewModeration from "c/libraryLibrarianReviewModeration";
import getPendingBookReviews from "@salesforce/apex/LibraryLibrarianController.getPendingBookReviews";
import moderateBookReview from "@salesforce/apex/LibraryLibrarianController.moderateBookReview";

jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getPendingBookReviews",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.moderateBookReview",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: class ShowToastEvent extends CustomEvent {
      constructor(detail) {
        super("lightning__showtoast", { detail });
      }
    }
  }),
  { virtual: true }
);

const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

const PENDING = [
  {
    id: "rev-1",
    bookTitle: "Clean Code",
    rating: 4,
    reviewText: "Clear and practical.",
    memberName: "Rita Reader",
    status: "Pending"
  }
];

function mount() {
  const element = createElement("c-library-librarian-review-moderation", {
    is: LibraryLibrarianReviewModeration
  });
  document.body.appendChild(element);
  return element;
}

describe("c-library-librarian-review-moderation", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("lists pending reviews with the member and book", async () => {
    getPendingBookReviews.mockResolvedValue(PENDING);
    const element = mount();
    await flush();
    const text = element.shadowRoot.textContent;
    expect(text).toContain("Clean Code");
    expect(text).toContain("Clear and practical.");
    expect(text).toContain("Rita Reader");
    expect(text).toContain("1 waiting");
  });

  it("approves a review and removes it from the queue", async () => {
    getPendingBookReviews.mockResolvedValue(PENDING);
    moderateBookReview.mockResolvedValue();
    const element = mount();
    await flush();
    element.shadowRoot.querySelector("button.primary").click();
    await flush();
    expect(moderateBookReview).toHaveBeenCalledWith({
      reviewId: "rev-1",
      status: "Published"
    });
    expect(element.shadowRoot.textContent).toContain(
      "No reviews are waiting for approval."
    );
  });

  it("rejects a review", async () => {
    getPendingBookReviews.mockResolvedValue(PENDING);
    moderateBookReview.mockResolvedValue();
    const element = mount();
    await flush();
    element.shadowRoot.querySelector("button.secondary").click();
    await flush();
    expect(moderateBookReview).toHaveBeenCalledWith({
      reviewId: "rev-1",
      status: "Rejected"
    });
  });

  it("keeps the review listed when the update fails", async () => {
    getPendingBookReviews.mockResolvedValue(PENDING);
    moderateBookReview.mockRejectedValue({ body: { message: "Denied." } });
    const element = mount();
    await flush();
    element.shadowRoot.querySelector("button.primary").click();
    await flush();
    expect(element.shadowRoot.textContent).toContain("Clean Code");
  });

  it("shows the error when loading fails", async () => {
    getPendingBookReviews.mockRejectedValue({
      body: { message: "No access." }
    });
    const element = mount();
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "No access."
    );
  });
});
