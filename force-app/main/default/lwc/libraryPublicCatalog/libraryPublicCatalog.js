import { LightningElement } from "lwc";
import searchPublicCatalog from "@salesforce/apex/LibraryRegistrationGuestController.searchPublicCatalog";

export default class LibraryPublicCatalog extends LightningElement {
  books = [];
  query = "";
  loading = true;
  errorMessage = "";

  connectedCallback() {
    this.loadBooks();
  }

  get hasBooks() {
    return this.books.length > 0;
  }

  get resultLabel() {
    return `${this.books.length} book${this.books.length === 1 ? "" : "s"} found`;
  }

  handleQuery(event) {
    this.query = event.target.value;
  }

  handleKeydown(event) {
    if (event.key === "Enter") this.loadBooks();
  }

  async loadBooks() {
    this.loading = true;
    this.errorMessage = "";
    try {
      const rows = await searchPublicCatalog({ searchTerm: this.query });
      this.books = (rows || []).map((book) => ({
        ...book,
        availabilityLabel:
          Number(book.availableCopies || 0) > 0
            ? `${book.availableCopies} available`
            : "Currently unavailable",
        availabilityClass:
          Number(book.availableCopies || 0) > 0
            ? "availability available"
            : "availability unavailable",
        yearLabel: book.publicationYear ? ` · ${book.publicationYear}` : ""
      }));
    } catch (error) {
      this.books = [];
      this.errorMessage =
        error?.body?.message ||
        "The catalog could not be loaded. Please try again.";
    } finally {
      this.loading = false;
    }
  }
}
