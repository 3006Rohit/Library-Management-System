import { LightningElement } from "lwc";
import login from "@salesforce/apex/LibraryMemberAuthController.login";
export default class LibraryMemberLogin extends LightningElement {
  email = "";
  password = "";
  error;
  busy = false;
  showPassword = false;
  get passwordType() {
    return this.showPassword ? "text" : "password";
  }
  get passwordToggleLabel() {
    return this.showPassword ? "Hide password" : "Show password";
  }
  get passwordToggleIcon() {
    return this.showPassword ? "Hide" : "Show";
  }
  get submitLabel() {
    return this.busy ? "Signing in…" : "Sign in";
  }
  togglePassword() {
    this.showPassword = !this.showPassword;
  }
  handleInput(event) {
    this[event.target.name] = event.target.value;
  }
  submit(event) {
    event?.preventDefault();
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
