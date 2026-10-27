import { LightningElement } from "lwc";
import getMyFines from "@salesforce/apex/LibraryMemberSessionController.getMyFines";
import getMyFineAppeals from "@salesforce/apex/LibraryMemberSessionController.getMyFineAppeals";
import submitFineAppeal from "@salesforce/apex/LibraryMemberSessionController.submitFineAppeal";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberFineAppeals extends LightningElement {
  rows = [];
  reasons = {};
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
      const [fines, appeals] = await Promise.all([
        getMyFines({ sessionToken: this.sessionToken }),
        getMyFineAppeals({ sessionToken: this.sessionToken })
      ]);
      const byFine = new Map(
        (appeals || []).map((appeal) => [appeal.fineId, appeal])
      );
      this.rows = (fines || []).map((fine) => ({
        ...fine,
        appeal: byFine.get(fine.Id)
      }));
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load fine appeals.";
    } finally {
      this.loading = false;
    }
  }

  captureReason(event) {
    this.reasons[event.currentTarget.dataset.id] = event.target.value;
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  async submit(event) {
    const fineId = event.currentTarget.dataset.id;
    try {
      await submitFineAppeal({
        sessionToken: this.sessionToken,
        fineId,
        reason: this.reasons[fineId]
      });
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Appeal submitted",
          message: "A librarian will review your appeal.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not submit appeal",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
