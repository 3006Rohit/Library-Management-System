import { LightningElement } from "lwc";
import getActivePlans from "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans";
import submitRegistration from "@salesforce/apex/LibraryRegistrationGuestController.submitRegistration";

export default class LibraryRegistration extends LightningElement {
  form = {};
  plans = [];
  loading = false;
  submitted = false;
  errorMessage;
  successMessage =
    "Your membership application has been submitted successfully. A librarian will review your application and you will receive an email when a decision is made.";

  connectedCallback() {
    getActivePlans()
      .then((data) => {
        this.plans = data || [];
      })
      .catch((error) => {
        this.errorMessage = this.message(error);
      });
  }
  get today() {
    return new Date().toISOString().slice(0, 10);
  }
  get planOptions() {
    return this.plans.map((plan) => ({ label: plan.Name, value: plan.Id }));
  }
  handleChange(event) {
    const fieldName = event.currentTarget.dataset.field;
    this.form = { ...this.form, [fieldName]: event.currentTarget.value };
  }
  handleSubmit(event) {
    event.preventDefault();
    this.errorMessage = undefined;
    const fields = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-textarea, lightning-combobox"
      )
    ];
    if (!fields.every((field) => field.reportValidity())) return;
    this.form = fields.reduce((values, field) => {
      const fieldName = field.dataset.field;
      if (fieldName) values[fieldName] = field.value;
      return values;
    }, {});
    // Apex Date parameters cannot deserialize an empty string. Optional form
    // fields must be omitted when the member leaves them blank.
    const input = { ...this.form };
    if (!input.dateOfBirth) delete input.dateOfBirth;
    this.loading = true;
    submitRegistration({ input })
      .then(() => {
        this.submitted = true;
      })
      .catch((error) => {
        this.errorMessage = this.message(error);
      })
      .finally(() => {
        this.loading = false;
      });
  }
  message(error) {
    return (
      error?.body?.message ||
      "We could not submit your application. Please check your details and try again."
    );
  }
}
