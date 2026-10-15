import { LightningElement } from "lwc";
import getMyNotifications from "@salesforce/apex/LibraryMemberController.getMyNotifications";
import markNotificationRead from "@salesforce/apex/LibraryMemberController.markNotificationRead";
export default class LibraryMemberNotifications extends LightningElement {
  notifications = [];
  loading = false;
  error;
  connectedCallback() {
    this.refresh();
  }
  refresh() {
    this.loading = true;
    getMyNotifications()
      .then((rows) => {
        this.notifications = (rows || []).map((row) => ({
          ...row,
          canMarkRead: row.Status__c !== "Read"
        }));
        this.error = undefined;
      })
      .catch((error) => {
        this.error =
          error?.body?.message ||
          error?.message ||
          "Notifications could not be loaded.";
      })
      .finally(() => {
        this.loading = false;
      });
  }
  markRead(event) {
    this.loading = true;
    markNotificationRead({ notificationId: event.currentTarget.dataset.id })
      .then(() => this.refresh())
      .catch((error) => {
        this.error = error?.body?.message || error?.message;
        this.loading = false;
      });
  }
}
