import { LightningElement, api } from "lwc";
import getReplacementOptions from "@salesforce/apex/LibraryLibrarianController.getReplacementOptions";
import reportDefectiveCopy from "@salesforce/apex/LibraryLibrarianController.reportDefectiveCopy";
import replaceDefectiveCopy from "@salesforce/apex/LibraryLibrarianController.replaceDefectiveCopy";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
export default class LibraryDamageReplacementPanel extends LightningElement {
  @api recordId;
  copies = [];
  selectedCopyId;
  notes = "";
  loading = false;
  error;
  connectedCallback() {
    this.refresh();
  }
  refresh() {
    this.loading = true;
    getReplacementOptions({ loanId: this.recordId })
      .then((rows) => {
        this.copies = (rows || []).map((row) => ({
          ...row,
          label: `${row.Name} — ${row.Barcode__c || ""} — ${row.Shelf_Location__c || ""}`,
          value: row.Id
        }));
        this.error = undefined;
      })
      .catch((e) => {
        this.error =
          e?.body?.message ||
          e?.message ||
          "Replacement options could not be loaded.";
      })
      .finally(() => {
        this.loading = false;
      });
  }
  change(e) {
    this[e.target.name] = e.target.value;
  }
  report() {
    this.loading = true;
    reportDefectiveCopy({ loanId: this.recordId, notes: this.notes })
      .then(() => {
        this.toast(
          "Defect recorded",
          "The copy was marked damaged. Select a replacement when available.",
          "success"
        );
        this.refresh();
      })
      .catch((e) => {
        this.error = e?.body?.message || e?.message;
      })
      .finally(() => {
        this.loading = false;
      });
  }
  replace() {
    if (!this.selectedCopyId) {
      this.error = "Select an available replacement copy.";
      return;
    }
    this.loading = true;
    replaceDefectiveCopy({
      loanId: this.recordId,
      replacementCopyId: this.selectedCopyId
    })
      .then(() => {
        this.toast(
          "Replacement assigned",
          "The member loan was updated and the due date adjusted.",
          "success"
        );
        this.refresh();
      })
      .catch((e) => {
        this.error = e?.body?.message || e?.message;
      })
      .finally(() => {
        this.loading = false;
      });
  }
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
