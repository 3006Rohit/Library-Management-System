import { LightningElement } from "lwc";
import getAcquisitionRecommendations from "@salesforce/apex/LibraryLibrarianController.getAcquisitionRecommendations";
import decideAcquisitionRecommendation from "@salesforce/apex/LibraryLibrarianController.decideAcquisitionRecommendation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const FILTERS = [
  { value: "Open", label: "To review" },
  { value: "Decided", label: "Decided" }
];

export default class LibraryAcquisitionDashboard extends LightningElement {
  recommendations = [];
  filter = "Open";
  loading = false;
  savingId;
  error;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      const rows = (await getAcquisitionRecommendations()) || [];
      this.recommendations = rows
        .map((row) => this.decorate(row))
        .sort((a, b) => b.scoreValue - a.scoreValue);
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load acquisition recommendations.";
    } finally {
      this.loading = false;
    }
  }

  decorate(row) {
    const scoreValue = Math.round(row.score || 0);
    const priority = scoreValue >= 70 ? "High" : scoreValue >= 40 ? "Medium" : "Low";
    const isBuy = row.recommendationType === "Purchase";
    const quantity = row.recommendedQuantity || 1;
    return {
      ...row,
      notes: row.decisionNotes || "",
      scoreValue,
      scoreLabel: `${scoreValue}/100`,
      scoreStyle: `width:${scoreValue}%`,
      priority,
      priorityClass: `priority priority-${priority.toLowerCase()}`,
      actionLabel: isBuy ? "Buy more" : "Replace",
      headline: `${isBuy ? "Buy" : "Replace"} ${quantity === 1 ? "1 copy" : `${quantity} copies`}`,
      isOpen: (row.status || "Open") === "Open",
      statusClass: `status-pill status-${(row.status || "open").toLowerCase()}`
    };
  }

  get visibleRows() {
    return this.recommendations.filter((row) => {
      return this.filter === "Open" ? row.isOpen : !row.isOpen;
    });
  }

  get hasRows() {
    return this.visibleRows.length > 0;
  }

  get filters() {
    return FILTERS.map((item) => {
      const count = this.recommendations.filter((row) => {
        return item.value === "Open" ? row.isOpen : !row.isOpen;
      }).length;
      return {
        ...item,
        label: `${item.label} (${count})`,
        className: item.value === this.filter ? "tab active" : "tab",
        selected: String(item.value === this.filter)
      };
    });
  }

  get emptyMessage() {
    if (this.loading) return "Checking borrowing and reservation activity…";
    return this.filter === "Open"
      ? "Nothing to review right now. Every book has enough copies."
      : "No decisions yet.";
  }

  handleFilter(event) {
    this.filter = event.currentTarget.dataset.value;
  }

  handleNotes(event) {
    const id = event.target.dataset.id;
    const notes = event.target.value;
    this.recommendations = this.recommendations.map((row) => {
      return row.id === id ? { ...row, notes } : row;
    });
  }

  async decide(event) {
    const { id, status } = event.currentTarget.dataset;
    const row = this.recommendations.find((item) => item.id === id);
    if (!row || this.savingId) return;
    this.savingId = id;
    try {
      await decideAcquisitionRecommendation({
        recommendationId: id,
        status,
        notes: status === "Open" ? "" : row.notes || ""
      });
      this.recommendations = this.recommendations.map((item) => {
        if (item.id !== id) {
          return item;
        }
        return this.decorate({
          ...item,
          status,
          decisionNotes: status === "Open" ? "" : item.notes
        });
      });
      this.toast(
        status === "Open" ? "Moved back to review" : `Marked ${status}`,
        row.bookTitle,
        "success"
      );
    } catch (error) {
      this.toast(
        "Could not save decision",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    } finally {
      this.savingId = undefined;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
