import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getPendingBookReviews from "@salesforce/apex/LibraryLibrarianController.getPendingBookReviews";
import moderateBookReview from "@salesforce/apex/LibraryLibrarianController.moderateBookReview";

function stars(rating) {
  const value = Math.max(0, Math.min(5, Number(rating || 0)));
  return "★".repeat(value) + "☆".repeat(5 - value);
}

function dateLabel(value) {
  if (!value) return "";
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric"
  }).format(new Date(value));
}

export default class LibraryLibrarianReviewModeration extends LightningElement {
  reviews = [];
  loading = false;
  busyId;
  error;

  connectedCallback() {
    this.refresh();
  }

  get rows() {
    return this.reviews.map((review) => ({
      ...review,
      stars: stars(review.rating),
      dateLabel: dateLabel(review.submittedAt),
      memberLabel: review.memberName || "Library member",
      disabled: this.busyId === review.id
    }));
  }

  get hasReviews() {
    return this.reviews.length > 0;
  }

  get countLabel() {
    const count = this.reviews.length;
    return `${count} waiting`;
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.reviews = (await getPendingBookReviews()) || [];
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load reviews.";
    } finally {
      this.loading = false;
    }
  }

  approve(event) {
    return this.decide(event.currentTarget.dataset.id, "Published");
  }

  reject(event) {
    return this.decide(event.currentTarget.dataset.id, "Rejected");
  }

  async decide(reviewId, status) {
    if (this.busyId) return;
    this.busyId = reviewId;
    try {
      await moderateBookReview({ reviewId, status });
      this.reviews = this.reviews.filter((review) => review.id !== reviewId);
      this.dispatchEvent(
        new ShowToastEvent({
          title: status === "Published" ? "Review approved" : "Review rejected",
          message:
            status === "Published"
              ? "Members can now see this review on the book."
              : "The review will not be shown to members.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not update review",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    } finally {
      this.busyId = undefined;
    }
  }
}
