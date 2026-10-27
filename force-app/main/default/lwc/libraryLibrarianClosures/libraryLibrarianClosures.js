import { LightningElement } from "lwc";
import getLibraryClosures from "@salesforce/apex/LibraryLibrarianController.getLibraryClosures";
import getManagedLibraryBranches from "@salesforce/apex/LibraryLibrarianController.getManagedLibraryBranches";
import createLibraryClosure from "@salesforce/apex/LibraryLibrarianController.createLibraryClosure";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const dateValue = (offset) =>
  new Date(Date.now() + offset * 86400000).toISOString().slice(0, 10);

export default class LibraryLibrarianClosures extends LightningElement {
  closures = [];
  branches = [];
  name = "";
  startDate = dateValue(1);
  endDate = dateValue(1);
  timezone = "UTC";
  branchId = "";
  emergency = false;
  loading = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      [this.closures, this.branches] = await Promise.all([
        getLibraryClosures(),
        getManagedLibraryBranches()
      ]);
      this.closures = this.closures || [];
      this.branches = this.branches || [];
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load closure calendar.";
    } finally {
      this.loading = false;
    }
  }

  get branchOptions() {
    return [
      { label: "All branches", value: "" },
      ...this.branches.map((branch) => ({
        label: `${branch.code} · ${branch.name}`,
        value: branch.id
      }))
    ];
  }

  get hasClosures() {
    return this.closures.length > 0;
  }

  capture(event) {
    this[event.currentTarget.dataset.field] =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
  }

  async submit() {
    try {
      await createLibraryClosure({
        name: this.name,
        startDate: this.startDate,
        endDate: this.endDate,
        branchId: this.branchId || null,
        timezone: this.timezone,
        emergency: this.emergency
      });
      this.name = "";
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Closure published",
          message: "Due-date calculations will honor this closure.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not publish closure",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
