import { LightningElement } from "lwc";
import getRepairCases from "@salesforce/apex/LibraryLibrarianController.getRepairCases";
import openRepairByBarcode from "@salesforce/apex/LibraryLibrarianController.openRepairByBarcode";
import resolveRepair from "@salesforce/apex/LibraryLibrarianController.resolveRepair";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryRepairCases extends LightningElement {
  status = "Open";
  barcode = "";
  reason = "";
  resolution = "";
  note = "";
  cases = [];
  busy = false;

  connectedCallback() {
    this.refresh();
  }

  get statusOptions() {
    return [
      { label: "Open", value: "Open" },
      { label: "Repaired", value: "Repaired" },
      { label: "Unrepairable", value: "Unrepairable" },
      { label: "All cases", value: "" }
    ];
  }

  get hasCases() {
    return (this.cases || []).length > 0;
  }

  get openCases() {
    return (this.cases || []).filter((item) => item.status === "Open");
  }

  get openCaseCount() {
    return this.openCases.length;
  }

  get openDisabled() {
    return this.busy || !this.barcode.trim() || this.reason.trim().length < 10;
  }

  get resolveDisabled() {
    return this.busy || this.note.trim().length < 10;
  }

  capture(event) {
    this[event.currentTarget.dataset.field] = event.target.value;
  }

  async refresh() {
    this.busy = true;
    try {
      const rows = await getRepairCases({ status: this.status });
      this.cases = (rows || []).map((row) => ({
        ...row,
        isOpen: row.status === "Open"
      }));
    } catch (error) {
      this.toastError(error, "Could not load repair cases");
    } finally {
      this.busy = false;
    }
  }

  async changeStatus(event) {
    this.status = event.target.value;
    await this.refresh();
  }

  async openCase() {
    this.busy = true;
    try {
      await openRepairByBarcode({
        barcode: this.barcode,
        reason: this.reason
      });
      this.barcode = "";
      this.reason = "";
      this.toast(
        "Repair case opened",
        "Copy moved to Maintenance for review.",
        "success"
      );
      await this.refresh();
    } catch (error) {
      this.toastError(error, "Could not open repair case");
    } finally {
      this.busy = false;
    }
  }

  async resolveCase(event) {
    const repairId = event.currentTarget.dataset.id;
    const status = event.currentTarget.dataset.status;
    this.busy = true;
    try {
      await resolveRepair({
        repairId,
        resolution: this.resolution,
        status,
        note: this.note
      });
      this.resolution = "";
      this.note = "";
      this.toast(
        "Repair case resolved",
        "Inventory status and condition were updated.",
        "success"
      );
      await this.refresh();
    } catch (error) {
      this.toastError(error, "Could not resolve repair case");
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
