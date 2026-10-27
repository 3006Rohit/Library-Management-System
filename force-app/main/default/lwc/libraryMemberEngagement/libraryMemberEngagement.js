import { LightningElement } from "lwc";
import getMyEngagements from "@salesforce/apex/LibraryMemberSessionController.getMyEngagements";
import saveMyEngagement from "@salesforce/apex/LibraryMemberSessionController.saveMyEngagement";
import removeMyEngagement from "@salesforce/apex/LibraryMemberSessionController.removeMyEngagement";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberEngagement extends LightningElement {
  rows = [];
  sessionToken = sessionStorage.getItem("libraryMemberSession");
  loading = false;
  error;
  stateOptions = [
    { label: "Want to Read", value: "Want to Read" },
    { label: "Currently Reading", value: "Currently Reading" },
    { label: "Completed", value: "Completed" },
    { label: "Abandoned", value: "Abandoned" }
  ];

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rows =
        (await getMyEngagements({ sessionToken: this.sessionToken })) || [];
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load your reading list.";
    } finally {
      this.loading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  handleState(event) {
    const id = event.target.dataset.id;
    this.save(id, { state: event.detail.value });
  }

  handleNotes(event) {
    const id = event.target.dataset.id;
    const row = this.rows.find((item) => item.id === id);
    this.save(id, { notes: event.target.value, state: row?.state });
  }

  handleRating(event) {
    const id = event.target.dataset.id;
    const row = this.rows.find((item) => item.id === id);
    const value = event.target.value === "" ? null : Number(event.target.value);
    this.save(id, { rating: value, state: row?.state });
  }

  handleNotify(event) {
    const id = event.target.dataset.id;
    const row = this.rows.find((item) => item.id === id);
    this.save(id, {
      notifyWhenAvailable: event.target.checked,
      state: row?.state
    });
  }

  async save(id, changes) {
    const row = this.rows.find((item) => item.id === id);
    if (!row) return;
    try {
      const updated = await saveMyEngagement({
        sessionToken: this.sessionToken,
        bookId: row.bookId,
        state: changes.state || row.state,
        notes: changes.notes ?? row.privateNotes,
        rating: changes.rating ?? row.rating,
        notifyWhenAvailable:
          changes.notifyWhenAvailable ?? row.notifyWhenAvailable
      });
      this.rows = this.rows.map((item) => (item.id === id ? updated : item));
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not save reading status",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }

  async remove(event) {
    const id = event.currentTarget.dataset.id;
    try {
      await removeMyEngagement({
        sessionToken: this.sessionToken,
        engagementId: id
      });
      this.rows = this.rows.filter((row) => row.id !== id);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not remove book",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
