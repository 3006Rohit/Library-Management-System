import { LightningElement, api } from "lwc";

export default class LibraryMemberBookCard extends LightningElement {
  @api book;
  @api actionLabel = "View Details";

  get hasCover() {
    return Boolean(this.book?.coverUrl);
  }

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
