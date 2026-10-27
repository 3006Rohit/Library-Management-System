import { LightningElement } from "lwc";
import getExecutiveSummaries from "@salesforce/apex/LibraryLibrarianController.getExecutiveSummaries";
import generateExecutiveSummary from "@salesforce/apex/LibraryLibrarianController.generateExecutiveSummary";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryExecutiveSummary extends LightningElement {
  rows = [];
  loading = false;
  generating = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  get hasRows() {
    return (this.rows || []).length > 0;
  }

  get latest() {
    return this.rows?.[0];
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rows = (await getExecutiveSummaries({ limitSize: 14 })) || [];
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load executive summaries.";
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }

  async generate() {
    this.generating = true;
    try {
      await generateExecutiveSummary();
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Summary generated",
          message: "The privacy-safe daily snapshot is ready.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not generate summary",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    } finally {
      this.generating = false;
    }
  }

  get generateLabel() {
    return this.generating ? "Generating…" : "Generate today";
  }
}
