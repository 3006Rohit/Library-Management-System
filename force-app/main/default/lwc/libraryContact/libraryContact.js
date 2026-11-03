import { LightningElement } from "lwc";
import getBranches from "@salesforce/apex/LibraryContactController.getBranches";
import submitMessage from "@salesforce/apex/LibraryContactController.submitMessage";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const EMPTY_FORM = {
  firstName: "",
  lastName: "",
  email: "",
  phone: "",
  subject: "",
  message: ""
};

export default class LibraryContact extends LightningElement {
  branches = [];
  form = { ...EMPTY_FORM };
  busy = false;
  sent = false;
  error;

  connectedCallback() {
    getBranches()
      .then((rows) => {
        this.branches = rows || [];
      })
      .catch(() => {
        this.branches = [];
      });
  }

  get branch() {
    return this.branches[0];
  }

  get addressText() {
    const branch = this.branch;
    if (!branch) return "Branch details coming soon";
    return [branch.name, branch.address].filter(Boolean).join(", ");
  }

  get hoursText() {
    return this.branch?.openingHours || "Hours will be published soon";
  }

  get submitLabel() {
    return this.busy ? "Sending…" : "Submit";
  }

  handleInput(event) {
    this.form = { ...this.form, [event.target.name]: event.target.value };
  }

  validate() {
    const { firstName, lastName, email, message } = this.form;
    if (!firstName.trim() || !lastName.trim()) {
      return "Enter your first and last name.";
    }
    if (!EMAIL_PATTERN.test(email.trim())) {
      return "Enter a valid email address.";
    }
    if (!message.trim()) {
      return "Enter a message.";
    }
    return undefined;
  }

  handleSubmit(event) {
    event.preventDefault();
    if (this.busy) return undefined;
    this.error = this.validate();
    if (this.error) return undefined;
    this.busy = true;
    return submitMessage({ ...this.form })
      .then(() => {
        this.sent = true;
      })
      .catch((error) => {
        this.error =
          error?.body?.message ||
          "We could not send your message. Please try again later.";
      })
      .finally(() => {
        this.busy = false;
      });
  }

  sendAnother() {
    this.form = { ...EMPTY_FORM };
    this.sent = false;
    this.error = undefined;
  }
}
