import { LightningElement } from "lwc";
import login from "@salesforce/apex/LibraryMemberAuthController.login";
export default class LibraryMemberLogin extends LightningElement {
  email = "";
  password = "";
  error;
  busy = false;
  handleInput(event) {
    this[event.target.name] = event.target.value;
  }
  submit() {
    this.error = undefined;
    this.busy = true;
    return login({ email: this.email, password: this.password })
      .then((result) => {
        sessionStorage.setItem("libraryMemberSession", result.sessionToken);
        localStorage.removeItem("libraryMemberSession");
        window.location.assign("/library/member");
      })
      .catch((error) => {
        this.error = error?.body?.message || "Invalid email or password.";
      })
      .finally(() => {
        this.busy = false;
      });
  }
  forgot() {
    window.location.assign("/library/ForgotPassword");
  }
  activate() {
    window.location.assign("/library/activate");
  }
  signup() {
    window.location.assign("/library/register");
  }
}
