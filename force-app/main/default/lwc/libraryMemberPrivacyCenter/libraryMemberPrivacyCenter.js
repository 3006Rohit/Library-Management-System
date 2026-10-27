import { LightningElement } from "lwc";
import getMyPrivacyRequests from "@salesforce/apex/LibraryMemberSessionController.getMyPrivacyRequests";
import requestMyPrivacyExport from "@salesforce/apex/LibraryMemberSessionController.requestMyPrivacyExport";
import requestMyPrivacyCorrection from "@salesforce/apex/LibraryMemberSessionController.requestMyPrivacyCorrection";
import requestMyPrivacyDeletion from "@salesforce/apex/LibraryMemberSessionController.requestMyPrivacyDeletion";
import cancelMyPrivacyRequest from "@salesforce/apex/LibraryMemberSessionController.cancelMyPrivacyRequest";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberPrivacyCenter extends LightningElement {
  requests = [];
  currentPassword = "";
  firstName = "";
  lastName = "";
  phone = "";
  address = "";
  correctionReason = "";
  deletionReason = "";
  loading = false;
  error;
  deletionRequested = false;
  sessionToken = sessionStorage.getItem("libraryMemberSession");

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.requests = (
        (await getMyPrivacyRequests({ sessionToken: this.sessionToken })) || []
      ).map((request) => ({
        ...request,
        disabled: request.status !== "Pending"
      }));
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load privacy requests.";
    } finally {
      this.loading = false;
    }
  }

  get hasRequests() {
    return this.requests.length > 0;
  }

  capture(event) {
    this[event.currentTarget.dataset.field] = event.target.value;
  }

  async exportData() {
    try {
      await requestMyPrivacyExport({
        sessionToken: this.sessionToken,
        currentPassword: this.currentPassword
      });
      await this.refresh();
      this.toast(
        "Export ready",
        "Your protected export is available for 24 hours.",
        "success"
      );
    } catch (error) {
      this.toast("Could not create export", this.message(error), "error");
    }
  }

  async submitCorrection() {
    try {
      await requestMyPrivacyCorrection({
        sessionToken: this.sessionToken,
        currentPassword: this.currentPassword,
        firstName: this.firstName,
        lastName: this.lastName,
        phone: this.phone,
        address: this.address,
        reason: this.correctionReason
      });
      await this.refresh();
      this.toast(
        "Correction submitted",
        "A librarian will review the requested changes.",
        "success"
      );
    } catch (error) {
      this.toast("Could not submit correction", this.message(error), "error");
    }
  }

  async submitDeletion() {
    try {
      await requestMyPrivacyDeletion({
        sessionToken: this.sessionToken,
        currentPassword: this.currentPassword,
        reason: this.deletionReason
      });
      this.deletionRequested = true;
      await this.refresh();
      this.toast(
        "Closure request submitted",
        "Your account remains active until review is complete.",
        "success"
      );
    } catch (error) {
      this.toast(
        "Could not submit closure request",
        this.message(error),
        "error"
      );
    }
  }

  async cancel(event) {
    try {
      await cancelMyPrivacyRequest({
        sessionToken: this.sessionToken,
        requestId: event.currentTarget.dataset.id
      });
      await this.refresh();
      this.toast(
        "Request cancelled",
        "The pending privacy request was cancelled.",
        "success"
      );
    } catch (error) {
      this.toast("Could not cancel request", this.message(error), "error");
    }
  }

  message(error) {
    return error?.body?.message || error?.message || "Try again.";
  }
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
