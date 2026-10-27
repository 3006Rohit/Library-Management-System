import { LightningElement } from "lwc";
import getMembershipHolds from "@salesforce/apex/LibraryLibrarianController.getMembershipHolds";
import decideMembershipHold from "@salesforce/apex/LibraryLibrarianController.decideMembershipHold";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryLibrarianMembershipHolds extends LightningElement {
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
      const rows = await getMembershipHolds();
      this.rows = (rows || []).map((row) => ({
        ...row,
        decisionReason: "",
        disabled: row.status !== "Pending"
      }));
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load membership holds.";
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
      await decideMembershipHold({
        holdId: id,
        status,
        decisionReason: row?.decisionReason
      });
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: `Hold ${status.toLowerCase()}`,
          message: "The hold decision was recorded.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not decide hold",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
