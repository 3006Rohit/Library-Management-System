import { LightningElement } from "lwc";
import getUpcomingEvents from "@salesforce/apex/LibraryMemberSessionController.getUpcomingEvents";
import registerForEvent from "@salesforce/apex/LibraryMemberSessionController.registerForEvent";
import cancelEventRegistration from "@salesforce/apex/LibraryMemberSessionController.cancelEventRegistration";
import issueEventCheckInToken from "@salesforce/apex/LibraryMemberSessionController.issueEventCheckInToken";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberEvents extends LightningElement {
  rows = [];
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
      this.rows = this.decorate(
        (await getUpcomingEvents({ sessionToken: this.sessionToken })) || []
      );
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load events.";
    } finally {
      this.loading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  async register(event) {
    await this.mutateRegistration(
      event.currentTarget.dataset.id,
      registerForEvent,
      "Event registration updated"
    );
  }

  async cancel(event) {
    const eventId = event.currentTarget.dataset.id;
    try {
      await cancelEventRegistration({
        sessionToken: this.sessionToken,
        eventId
      });
      this.rows = this.rows.map((row) => {
        if (row.id !== eventId) return row;
        return {
          ...row,
          registrationStatus: undefined,
          registeredCount: Math.max((row.registeredCount || 1) - 1, 0)
        };
      });
    } catch (error) {
      this.toast("Could not cancel registration", error, "error");
    }
  }

  async issueToken(event) {
    const eventId = event.currentTarget.dataset.id;
    try {
      const token = await issueEventCheckInToken({
        sessionToken: this.sessionToken,
        eventId
      });
      this.rows = this.rows.map((row) => {
        return row.id === eventId ? { ...row, checkInToken: token } : row;
      });
    } catch (error) {
      this.toast("Could not create check-in code", error, "error");
    }
  }

  async mutateRegistration(eventId, action, successMessage) {
    try {
      const updated = await action({
        sessionToken: this.sessionToken,
        eventId
      });
      this.rows = this.rows.map((row) => {
        return row.id === eventId ? this.decorate([updated])[0] : row;
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: successMessage,
          message: "",
          variant: "success"
        })
      );
    } catch (error) {
      this.toast("Could not update registration", error, "error");
    }
  }

  toast(title, error, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message: error?.body?.message || error?.message || "Try again.",
        variant
      })
    );
  }

  decorate(rows) {
    return rows.map((row) => ({
      ...row,
      canIssueCheckIn: row.registrationStatus === "Registered"
    }));
  }
}
