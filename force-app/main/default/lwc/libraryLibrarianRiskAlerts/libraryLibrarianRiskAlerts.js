import { LightningElement } from "lwc";
import getRiskAlerts from "@salesforce/apex/LibraryLibrarianController.getRiskAlerts";
import scanRiskInsights from "@salesforce/apex/LibraryLibrarianController.scanRiskInsights";
import decideRiskAlert from "@salesforce/apex/LibraryLibrarianController.decideRiskAlert";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryLibrarianRiskAlerts extends LightningElement {
  rows = [];
  status = "Open";
  loading = false;
  scanning = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  get hasRows() {
    return (this.rows || []).length > 0;
  }

  get statusOptions() {
    return [
      { label: "Open", value: "Open" },
      { label: "Resolved", value: "Resolved" },
      { label: "False Positive", value: "False Positive" },
      { label: "All", value: "" }
    ];
  }

  get scanLabel() {
    return this.scanning ? "Scanning…" : "Run scan";
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rows = (
        (await getRiskAlerts({ status: this.status || null })) || []
      ).map((row) => ({
        ...row,
        reviewerNote: "",
        disabled: row.status !== "Open"
      }));
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load risk alerts.";
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }

  changeStatus(event) {
    this.status = event.target.value;
    this.refresh();
  }

  captureNote(event) {
    const id = event.currentTarget.dataset.id;
    this.rows = this.rows.map((row) =>
      row.id === id ? { ...row, reviewerNote: event.target.value } : row
    );
  }

  async scan() {
    this.scanning = true;
    try {
      const result = await scanRiskInsights();
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Risk scan complete",
          message: `${result.created} new alert(s) created.`,
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Risk scan failed",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    } finally {
      this.scanning = false;
    }
  }

  async decide(event) {
    const id = event.currentTarget.dataset.id;
    const status = event.currentTarget.dataset.status;
    const row = this.rows.find((item) => item.id === id);
    try {
      await decideRiskAlert({
        alertId: id,
        status,
        reviewerNote: row?.reviewerNote
      });
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Risk alert reviewed",
          message: "The review decision was recorded and audited.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not review alert",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
