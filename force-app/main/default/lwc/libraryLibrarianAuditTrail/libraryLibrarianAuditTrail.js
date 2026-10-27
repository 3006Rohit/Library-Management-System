import { LightningElement } from "lwc";
import getOperationAudit from "@salesforce/apex/LibraryLibrarianController.getOperationAudit";

export default class LibraryLibrarianAuditTrail extends LightningElement {
  rows = [];
  operation = "";
  loading = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  get hasRows() {
    return (this.rows || []).length > 0;
  }

  get emptyMessage() {
    return this.operation
      ? "No audit entries match this operation."
      : "No operation audit entries are available.";
  }

  captureOperation(event) {
    this.operation = event.target.value;
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rows = await getOperationAudit({
        operation: this.operation.trim() || null,
        targetId: null,
        limitSize: 100
      });
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load the operation audit trail.";
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }
}
