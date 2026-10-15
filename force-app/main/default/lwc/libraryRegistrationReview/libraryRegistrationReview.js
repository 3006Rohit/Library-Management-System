import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRegistrationForReview from "@salesforce/apex/LibraryExternalRegistrationController.getRegistrationForReview";
import approveRegistration from "@salesforce/apex/LibraryExternalRegistrationController.approveRegistration";
import rejectRegistration from "@salesforce/apex/LibraryExternalRegistrationController.rejectRegistration";
import retryProvisioning from "@salesforce/apex/LibraryExternalRegistrationController.retryProvisioning";

export default class LibraryRegistrationReview extends LightningElement {
  @api recordId;
  registration;
  loading = true;
  working = false;
  rejecting = false;
  approving = false;
  reason = "";
  errorMessage;
  connectedCallback() {
    this.refresh();
  }
  get isPending() {
    return this.registration?.Status__c === "Pending";
  }
  get isFailed() {
    return this.registration?.Provisioning_Status__c === "Failed";
  }
  get isProvisioning() {
    return ["Queued", "Processing"].includes(
      this.registration?.Provisioning_Status__c
    );
  }
  get isCompleted() {
    return this.registration?.Provisioning_Status__c === "Completed";
  }
  get isExternalAuth() {
    return Boolean(this.registration?.External_Auth_Id__c);
  }
  refresh() {
    this.loading = true;
    getRegistrationForReview({ registrationId: this.recordId })
      .then((data) => {
        this.registration = data;
        this.errorMessage = undefined;
      })
      .catch((e) => {
        this.errorMessage = this.message(e);
      })
      .finally(() => {
        this.loading = false;
      });
  }
  approve() {
    this.approving = true;
  }
  closeApprove() {
    this.approving = false;
  }
  confirmApprove() {
    this.working = true;
    approveRegistration({ registrationId: this.recordId })
      .then(() => {
        this.toast(
          "Success",
          this.isExternalAuth
            ? "The external member account is now active."
            : "Member provisioning has been queued.",
          "success"
        );
        this.approving = false;
        this.refresh();
      })
      .catch((e) => {
        this.errorMessage = this.message(e);
      })
      .finally(() => {
        this.working = false;
      });
  }
  openReject() {
    this.reason = "";
    this.rejecting = true;
  }
  closeReject() {
    this.rejecting = false;
  }
  changeReason(e) {
    this.reason = e.target.value;
  }
  reject() {
    const field = this.template.querySelector("lightning-textarea");
    if (!field.reportValidity()) return;
    this.working = true;
    rejectRegistration({ registrationId: this.recordId, reason: this.reason })
      .then(() => {
        this.toast("Success", "The application was rejected.", "success");
        this.rejecting = false;
        this.refresh();
      })
      .catch((e) => {
        this.errorMessage = this.message(e);
      })
      .finally(() => {
        this.working = false;
      });
  }
  retry() {
    this.working = true;
    retryProvisioning({ registrationId: this.recordId })
      .then(() => {
        this.toast(
          "Success",
          "Member provisioning has been queued for retry.",
          "success"
        );
        this.refresh();
      })
      .catch((e) => {
        this.errorMessage = this.message(e);
      })
      .finally(() => {
        this.working = false;
      });
  }
  message(e) {
    return e?.body?.message || "The request could not be completed.";
  }
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
