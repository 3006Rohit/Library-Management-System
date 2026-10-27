import { LightningElement } from "lwc";
import issueCard from "@salesforce/apex/LibraryMemberSessionController.issueMyDigitalMemberCard";

export default class LibraryDigitalMemberCard extends LightningElement {
  card;
  loading = true;
  error = "";
  copied = false;

  connectedCallback() {
    this.refreshCard();
  }

  get sessionToken() {
    return window.sessionStorage.getItem("libraryMemberSession") || "";
  }

  get hasCard() {
    return Boolean(this.card?.valid);
  }

  get cardLabel() {
    return this.loading ? "Generating card…" : "Refresh card token";
  }

  get copyLabel() {
    return this.copied ? "Copied" : "Copy token";
  }

  get expiryLabel() {
    return this.card?.expiresAt
      ? new Intl.DateTimeFormat(undefined, {
          dateStyle: "medium",
          timeStyle: "short"
        }).format(new Date(this.card.expiresAt))
      : "Not available";
  }

  async refreshCard() {
    this.loading = true;
    this.error = "";
    this.copied = false;
    try {
      this.card = await issueCard({ sessionToken: this.sessionToken });
    } catch (error) {
      this.card = undefined;
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to generate a member card.";
    } finally {
      this.loading = false;
    }
  }

  async copyToken() {
    if (!this.card?.token) return;
    try {
      await navigator.clipboard.writeText(this.card.token);
      this.copied = true;
    } catch {
      this.error = "Copy is unavailable. Select the token manually.";
    }
  }
}
