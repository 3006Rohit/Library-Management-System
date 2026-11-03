import { LightningElement, api } from "lwc";

export default class LibraryMemberBookCard extends LightningElement {
  @api book;
  @api actionLabel = "View Details";

  handleAction() {
    this.dispatchEvent(
      new CustomEvent("bookaction", {
        detail: { id: this.book?.Id },
        bubbles: true,
        composed: true
      })
    );
  }
}
