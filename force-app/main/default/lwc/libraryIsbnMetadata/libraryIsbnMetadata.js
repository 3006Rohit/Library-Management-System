import { LightningElement } from "lwc";
import lookupBookMetadata from "@salesforce/apex/LibraryLibrarianController.lookupBookMetadata";
import applyBookMetadata from "@salesforce/apex/LibraryLibrarianController.applyBookMetadata";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryIsbnMetadata extends LightningElement {
  isbn = "";
  bookId = "";
  metadata;
  busy = false;
  selected = new Set([
    "isbn",
    "title",
    "publisher",
    "publicationYear",
    "edition",
    "language",
    "description",
    "coverUrl"
  ]);

  get hasMetadata() {
    return Boolean(this.metadata);
  }
  get selectedFieldsCsv() {
    return Array.from(this.selected).join(",");
  }
  get selectedCount() {
    return this.selected.size;
  }
  get isIsbnSelected() {
    return this.selected.has("isbn");
  }
  get isTitleSelected() {
    return this.selected.has("title");
  }
  get isPublisherSelected() {
    return this.selected.has("publisher");
  }
  get isPublicationYearSelected() {
    return this.selected.has("publicationYear");
  }
  get isEditionSelected() {
    return this.selected.has("edition");
  }
  get isLanguageSelected() {
    return this.selected.has("language");
  }
  get isDescriptionSelected() {
    return this.selected.has("description");
  }
  get isCoverUrlSelected() {
    return this.selected.has("coverUrl");
  }
  get canLookup() {
    return this.busy || !this.isbn.trim();
  }
  get canApply() {
    return (
      this.busy ||
      !this.bookId.trim() ||
      !this.metadata ||
      this.selected.size === 0
    );
  }
  get warningText() {
    return (this.metadata?.warnings || []).join(" ");
  }
  get hasWarnings() {
    return Boolean(this.warningText);
  }

  capture(event) {
    this[event.currentTarget.dataset.field] = event.target.value;
  }

  toggleField(event) {
    const field = event.currentTarget.dataset.field;
    const next = new Set(this.selected);
    if (event.target.checked) next.add(field);
    else next.delete(field);
    this.selected = next;
  }

  async lookup() {
    this.busy = true;
    try {
      const result = await lookupBookMetadata({ isbn: this.isbn });
      this.metadata = {
        ...result,
        authorsLabel: result.authors || "Not provided",
        categoriesLabel: result.categories || "Not provided"
      };
      this.toast(
        "Metadata preview ready",
        "Review the provider values before applying them.",
        "success"
      );
    } catch (error) {
      this.toastError(error, "Could not look up ISBN");
    } finally {
      this.busy = false;
    }
  }

  async apply() {
    this.busy = true;
    try {
      await applyBookMetadata({
        bookId: this.bookId,
        selectedFieldsCsv: this.selectedFieldsCsv,
        isbn: this.metadata.isbn,
        title: this.metadata.title,
        publisher: this.metadata.publisher,
        publicationYear: this.metadata.publicationYear,
        edition: this.metadata.edition,
        language: this.metadata.language,
        description: this.metadata.description,
        coverUrl: this.metadata.coverUrl
      });
      this.toast(
        "Catalog updated",
        `${this.selectedCount} explicitly selected fields were applied.`,
        "success"
      );
    } catch (error) {
      this.toastError(error, "Could not apply metadata");
    } finally {
      this.busy = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
  toastError(error, title) {
    this.toast(
      title,
      error?.body?.message || error?.message || "Try again.",
      "error"
    );
  }
}
