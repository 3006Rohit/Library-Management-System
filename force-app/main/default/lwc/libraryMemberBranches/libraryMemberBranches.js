import { LightningElement } from "lwc";
import getLibraryBranches from "@salesforce/apex/LibraryMemberSessionController.getLibraryBranches";

export default class LibraryMemberBranches extends LightningElement {
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
        (await getLibraryBranches({ sessionToken: this.sessionToken })) || [];
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load branches.";
    } finally {
      this.loading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }
}
