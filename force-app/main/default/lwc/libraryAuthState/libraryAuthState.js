import { api, LightningElement } from "lwc";
import authHero from "@salesforce/resourceUrl/LibraryAuthHero";

export default class LibraryAuthState extends LightningElement {
  @api title = "Registration Submitted!";
  @api message = "Your registration has been received.";
  @api actionLabel = "Back to Home";
  @api actionUrl;
  @api icon = "◷";
  @api variant = "pending";

  get heroStyle() {
    return `background-image: url("${authHero}")`;
  }

  get hasActionUrl() {
    return Boolean(this.actionUrl);
  }

  get iconClass() {
    return `state-icon ${this.variant}`;
  }

  handleAction() {
    this.dispatchEvent(new CustomEvent("stateaction"));
  }
}
