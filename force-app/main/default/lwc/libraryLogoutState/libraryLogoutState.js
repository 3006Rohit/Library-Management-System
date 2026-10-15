import { LightningElement } from "lwc";
import logout from "@salesforce/apex/LibraryMemberAuthController.logout";

export default class LibraryLogoutState extends LightningElement {
  connectedCallback() {
    const token =
      sessionStorage.getItem("libraryMemberSession") ||
      localStorage.getItem("libraryMemberSession");
    sessionStorage.removeItem("libraryMemberSession");
    localStorage.removeItem("libraryMemberSession");
    logout({ sessionToken: token }).finally(() =>
      window.location.replace("/library/login")
    );
  }
}
