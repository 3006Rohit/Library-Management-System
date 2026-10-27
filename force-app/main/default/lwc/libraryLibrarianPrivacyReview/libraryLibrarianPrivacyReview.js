import { LightningElement } from "lwc";
import getPrivacyRequests from "@salesforce/apex/LibraryLibrarianController.getPrivacyRequests";
import decidePrivacyRequest from "@salesforce/apex/LibraryLibrarianController.decidePrivacyRequest";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryLibrarianPrivacyReview extends LightningElement {
  rows = [];
  loading = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rows = ((await getPrivacyRequests()) || []).map((row) => ({
        ...row,
        decisionReason: "",
        disabled: row.status !== "Pending"
      }));
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load privacy requests.";
    } finally {
      this.loading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  captureReason(event) {
    const id = event.currentTarget.dataset.id;
    const value = event.target.value;
    this.rows = this.rows.map((row) => {
      return row.id === id ? { ...row, decisionReason: value } : row;
    });
  }

  async decide(event) {
    const id = event.currentTarget.dataset.id;
    const status = event.currentTarget.dataset.status;
    const row = this.rows.find((item) => item.id === id);
    try {
      await decidePrivacyRequest({
        requestId: id,
        status,
        decisionReason: row?.decisionReason
      });
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: `Privacy request ${status.toLowerCase()}`,
          message: "The decision was recorded and audited.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not decide request",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
