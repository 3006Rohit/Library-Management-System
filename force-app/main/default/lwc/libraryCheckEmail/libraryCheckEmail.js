import { LightningElement } from "lwc";

export default class LibraryCheckEmail extends LightningElement {
  backToLogin() {
    window.location.assign("/library/login");
  }
  sendAgain() {
    window.location.assign("/library/ForgotPassword");
  }
}
