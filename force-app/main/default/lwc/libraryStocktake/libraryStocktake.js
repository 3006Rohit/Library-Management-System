import { LightningElement } from "lwc";
import startStocktake from "@salesforce/apex/LibraryLibrarianController.startStocktake";
import scanStocktake from "@salesforce/apex/LibraryLibrarianController.scanStocktake";
import closeStocktake from "@salesforce/apex/LibraryLibrarianController.closeStocktake";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryStocktake extends LightningElement {
  audit;
  name = "";
  scope = "";
  barcode = "";
  observedStatus = "";
  note = "";
  summary = "";
  lines = [];
  busy = false;

  get hasAudit() {
    return Boolean(this.audit);
  }
  get hasLines() {
    return (this.lines || []).length > 0;
  }
  get startDisabled() {
    return this.busy || !this.name.trim();
  }
  get scanDisabled() {
    return this.busy || !this.barcode.trim();
  }
  get closeDisabled() {
    return this.busy || !this.summary.trim() || this.summary.trim().length < 10;
  }

  capture(event) {
    this[event.currentTarget.dataset.field] = event.target.value;
  }

  async start() {
    this.busy = true;
    try {
      this.audit = await startStocktake({ name: this.name, scope: this.scope });
      this.lines = [];
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Stocktake started",
          message:
            "Scan copies to record observed status without changing inventory.",
          variant: "success"
        })
      );
    } catch (error) {
      this.toastError(error, "Could not start stocktake");
    } finally {
      this.busy = false;
    }
  }

  async scan() {
    this.busy = true;
    try {
      const line = await scanStocktake({
        auditId: this.audit.id,
        barcode: this.barcode,
        observedStatus: this.observedStatus,
        note: this.note
      });
      this.lines = [
        line,
        ...(this.lines || []).filter((row) => row.id !== line.id)
      ];
      this.barcode = "";
      this.note = "";
    } catch (error) {
      this.toastError(error, "Could not record scan");
    } finally {
      this.busy = false;
    }
  }

  async close() {
    this.busy = true;
    try {
      await closeStocktake({ auditId: this.audit.id, summary: this.summary });
      this.audit = { ...this.audit, status: "Closed" };
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Stocktake closed",
          message: "The closing summary and discrepancies were recorded.",
          variant: "success"
        })
      );
    } catch (error) {
      this.toastError(error, "Could not close stocktake");
    } finally {
      this.busy = false;
    }
  }

  toastError(error, title) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message: error?.body?.message || error?.message || "Try again.",
        variant: "error"
      })
    );
  }
}
