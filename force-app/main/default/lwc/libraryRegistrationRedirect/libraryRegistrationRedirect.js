import { LightningElement } from "lwc";
import userIsGuest from "@salesforce/user/isGuest";

export default class LibraryRegistrationRedirect extends LightningElement {
  isGuestUser = userIsGuest;

  connectedCallback() {
    if (this.isGuestUser) {
      window.location.replace("/library/register");
    }
  }
}
