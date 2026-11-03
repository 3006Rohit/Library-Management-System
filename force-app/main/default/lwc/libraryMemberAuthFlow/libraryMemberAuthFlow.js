import { LightningElement, api } from "lwc";
import activateAccount from "@salesforce/apex/LibraryMemberAuthController.activateAccount";
import forgotPassword from "@salesforce/apex/LibraryMemberAuthController.forgotPassword";
import resetPassword from "@salesforce/apex/LibraryMemberAuthController.resetPassword";

export default class LibraryMemberAuthFlow extends LightningElement {
  @api mode = "forgot";
  @api email = "";
  @api token = "";
  @api password = "";
  @api confirmation = "";
  routeToken = "";
  internalMode;
  message;
  error;
  busy = false;

  connectedCallback() {
    this.routeToken =
      new URL(window.location.href).searchParams.get("token") || "";
    const path = window.location.pathname.toLowerCase();
    if (path.includes("activate")) this.internalMode = "activate";
    if (path.includes("reset")) this.internalMode = "reset";
  }
  get effectiveMode() {
    return this.internalMode || this.mode;
  }
  get isForgot() {
    return this.effectiveMode === "forgot";
  }
  get isActivate() {
    return this.effectiveMode === "activate";
  }
  get isReset() {
    return this.effectiveMode === "reset";
  }
  get title() {
    return this.isForgot
      ? "Forgot password"
      : this.isActivate
        ? "Activate membership"
        : "Reset password";
  }
  get description() {
    return this.isForgot
      ? "Enter your email and we will generate reset instructions if an account exists."
      : this.isActivate
        ? "Set a password to activate your approved library membership."
        : "Choose a new password for your library account.";
  }
  showPassword = false;
  get needsToken() {
    return this.isActivate || this.isReset;
  }
  get needsPassword() {
    return this.isActivate || this.isReset;
  }
  get tokenLabel() {
    return this.isActivate ? "Activation token" : "Reset token";
  }
  get badge() {
    return this.isForgot
      ? "Forgot Password"
      : this.isActivate
        ? "Activate Account"
        : "Reset Password";
  }
  get submitLabel() {
    if (this.busy) return "Please wait…";
    return this.isForgot
      ? "Send reset instructions"
      : this.isActivate
        ? "Activate account"
        : "Reset password";
  }
  get panelTitle() {
    return this.isForgot
      ? "Back in a few clicks"
      : this.isActivate
        ? "Welcome to the library"
        : "A fresh start";
  }
  get panelText() {
    return this.isForgot
      ? "Enter the email on your membership and we will send you the steps to choose a new password."
      : this.isActivate
        ? "Your membership is approved. Set a password to start borrowing, reserving and tracking your books."
        : "Choose a new password to get back to your loans, reservations and reading list.";
  }
  get panelNoteTitle() {
    return this.isForgot
      ? "Check your inbox"
      : this.isActivate
        ? "Membership approved"
        : "Almost done";
  }
  get panelNoteText() {
    return this.isForgot
      ? "Reset instructions arrive by email"
      : this.isActivate
        ? "One step left to sign in"
        : "Sign in right after saving";
  }
  get passwordType() {
    return this.showPassword ? "text" : "password";
  }
  get passwordToggleLabel() {
    return this.showPassword ? "Hide password" : "Show password";
  }
  get passwordToggleIcon() {
    return this.showPassword ? "Hide" : "Show";
  }
  togglePassword() {
    this.showPassword = !this.showPassword;
  }
  handleSubmit(event) {
    event.preventDefault();
    return this.submit();
  }
  handleInput(event) {
    this[event.target.name] = event.target.value;
  }
  @api submit() {
    this.error = undefined;
    this.message = undefined;
    this.busy = true;
    let action;
    let params;
    if (this.isForgot) {
      action = forgotPassword;
      params = { email: this.email };
    } else if (this.isActivate) {
      action = activateAccount;
      params = {
        token: this.routeToken || this.token,
        password: this.password,
        confirmation: this.confirmation
      };
    } else {
      action = resetPassword;
      params = {
        token: this.routeToken || this.token,
        password: this.password,
        confirmation: this.confirmation
      };
    }
    return action(params)
      .then(() => {
        this.message = this.isForgot
          ? "If an account exists for this email, reset instructions have been generated."
          : "Your password has been set. You can now sign in.";
        if (!this.isForgot) window.location.assign("/library/login");
      })
      .catch((error) => {
        this.error =
          error?.body?.message || "The request could not be completed.";
      })
      .finally(() => {
        this.busy = false;
      });
  }
  backToLogin() {
    window.location.assign("/library/login");
  }
}
