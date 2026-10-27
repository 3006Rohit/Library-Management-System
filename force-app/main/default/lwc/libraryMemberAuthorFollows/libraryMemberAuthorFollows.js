import { LightningElement } from "lwc";
import getMyAuthorFollows from "@salesforce/apex/LibraryMemberSessionController.getMyAuthorFollows";
import unfollowAuthor from "@salesforce/apex/LibraryMemberSessionController.unfollowAuthor";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberAuthorFollows extends LightningElement {
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
      this.rows =
        (await getMyAuthorFollows({ sessionToken: this.sessionToken })) || [];
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load followed authors.";
    } finally {
      this.loading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  async remove(event) {
    const followId = event.currentTarget.dataset.id;
    try {
      await unfollowAuthor({ sessionToken: this.sessionToken, followId });
      this.rows = this.rows.filter((row) => row.id !== followId);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not unfollow author",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
