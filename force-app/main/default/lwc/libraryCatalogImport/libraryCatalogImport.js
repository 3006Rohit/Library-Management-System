import { LightningElement } from "lwc";
import previewCatalogImport from "@salesforce/apex/LibraryLibrarianController.previewCatalogImport";
import commitCatalogImport from "@salesforce/apex/LibraryLibrarianController.commitCatalogImport";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryCatalogImport extends LightningElement {
  csvText = "title,isbn,publisher,publicationYear\n";
  importKey = "";
  rows = [];
  loading = false;
  committing = false;
  error;

  get hasRows() {
    return (this.rows || []).length > 0;
  }
  get hasInvalidRows() {
    return (this.rows || []).some((row) => row.status === "Invalid");
  }
  get commitDisabled() {
    return (
      this.committing ||
      !this.hasRows ||
      this.hasInvalidRows ||
      !this.importKey.trim()
    );
  }

  captureCsv(event) {
    this.csvText = event.target.value;
  }
  captureKey(event) {
    this.importKey = event.target.value;
  }

  async preview() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rows = (await previewCatalogImport({ csvText: this.csvText })) || [];
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Could not preview the CSV.";
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }

  async commit() {
    this.committing = true;
    try {
      const result = await commitCatalogImport({
        importKey: this.importKey,
        csvText: this.csvText
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Catalog import completed",
          message: `${result.created} book(s) created.`,
          variant: "success"
        })
      );
      this.rows = [];
      this.csvText = "title,isbn,publisher,publicationYear\n";
      this.importKey = "";
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Catalog import failed",
          message:
            error?.body?.message ||
            error?.message ||
            "Correct the preview errors and try again.",
          variant: "error"
        })
      );
    } finally {
      this.committing = false;
    }
  }
}
