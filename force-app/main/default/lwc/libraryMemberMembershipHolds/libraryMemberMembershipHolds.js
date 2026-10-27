import { LightningElement } from "lwc";
import getMyMembershipHolds from "@salesforce/apex/LibraryMemberSessionController.getMyMembershipHolds";
import getMyMembershipStatus from "@salesforce/apex/LibraryMemberSessionController.getMyMembershipStatus";
import submitMembershipHold from "@salesforce/apex/LibraryMemberSessionController.submitMembershipHold";
import cancelMembershipHold from "@salesforce/apex/LibraryMemberSessionController.cancelMembershipHold";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const isoDate = (date) => date.toISOString().slice(0, 10);

export default class LibraryMemberMembershipHolds extends LightningElement {
  holds = [];
  status;
  startDate = isoDate(new Date(Date.now() + 86400000));
  endDate = isoDate(new Date(Date.now() + 7 * 86400000));
  reason = "";
  loading = false;
  error;
  sessionToken = sessionStorage.getItem("libraryMemberSession");

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      [this.holds, this.status] = await Promise.all([
        getMyMembershipHolds({ sessionToken: this.sessionToken }),
        getMyMembershipStatus({ sessionToken: this.sessionToken })
      ]);
      this.holds = (this.holds || []).map((hold) => ({
        ...hold,
        canCancel: hold.status === "Pending"
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

  get hasHolds() {
    return this.holds.length > 0;
  }

  get graceMessage() {
    if (!this.status?.graceActive) return "";
    return `Your membership is in a read-only grace period through ${this.status.gracePeriodEndsOn}. Borrowing remains paused until renewal.`;
  }

  capture(event) {
    this[event.currentTarget.dataset.field] = event.target.value;
  }

  async submit() {
    try {
      await submitMembershipHold({
        sessionToken: this.sessionToken,
        startDate: this.startDate,
        endDate: this.endDate,
        reason: this.reason
      });
      this.reason = "";
      await this.refresh();
      this.toast(
        "Hold requested",
        "Your request is waiting for librarian review.",
        "success"
      );
    } catch (error) {
      this.toast(
        "Could not request hold",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    }
  }

  async cancel(event) {
    try {
      await cancelMembershipHold({
        sessionToken: this.sessionToken,
        holdId: event.currentTarget.dataset.id
      });
      await this.refresh();
      this.toast(
        "Request cancelled",
        "The pending hold request was cancelled.",
        "success"
      );
    } catch (error) {
      this.toast(
        "Could not cancel request",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
