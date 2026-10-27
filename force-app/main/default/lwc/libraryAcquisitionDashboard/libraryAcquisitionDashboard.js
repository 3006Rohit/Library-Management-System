import { LightningElement } from "lwc";
import getAcquisitionRecommendations from "@salesforce/apex/LibraryLibrarianController.getAcquisitionRecommendations";
import decideAcquisitionRecommendation from "@salesforce/apex/LibraryLibrarianController.decideAcquisitionRecommendation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryAcquisitionDashboard extends LightningElement {
  recommendations = [];
  loading = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      const rows = await getAcquisitionRecommendations();
      this.recommendations = (rows || []).map((row) => ({
        ...row,
        scoreLabel: row.score == null ? "—" : `${Math.round(row.score)}/100`,
        quantityLabel: row.recommendedQuantity || 1,
        windowLabel: `${row.evidenceWindowStart || ""} to ${row.evidenceWindowEnd || ""}`,
        statusClass: `status-pill status-${(row.status || "open").toLowerCase()}`,
        confidenceClass: `confidence confidence-${(row.confidence || "low").toLowerCase()}`
      }));
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load acquisition recommendations.";
    } finally {
      this.loading = false;
    }
  }

  get hasRecommendations() {
    return this.recommendations.length > 0;
  }

  get emptyMessage() {
    return this.loading
      ? "Calculating evidence-backed recommendations…"
      : "No actionable recommendation has enough evidence yet.";
  }

  handleNotes(event) {
    const id = event.target.dataset.id;
    this.recommendations = this.recommendations.map((row) => {
      if (row.id === id) return { ...row, notes: event.target.value };
      return row;
    });
  }

  async decide(event) {
    const { id, status } = event.currentTarget.dataset;
    const row = this.recommendations.find((item) => item.id === id);
    try {
      await decideAcquisitionRecommendation({
        recommendationId: id,
        status,
        notes: row?.notes || ""
      });
      this.recommendations = this.recommendations.map((item) => {
        if (item.id === id) {
          return {
            ...item,
            status,
            statusClass: `status-pill status-${status.toLowerCase()}`
          };
        }
        return item;
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Recommendation updated",
          message: `${status} decision saved.`,
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not save decision",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
