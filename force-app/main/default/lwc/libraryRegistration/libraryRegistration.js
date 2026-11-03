import { LightningElement } from "lwc";
import getActivePlans from "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans";
import getInterestOptions from "@salesforce/apex/LibraryRegistrationGuestController.getInterestOptions";
import getPaymentQuote from "@salesforce/apex/LibraryRegistrationGuestController.getPaymentQuote";
import submitRegistrationWithPayment from "@salesforce/apex/LibraryRegistrationGuestController.submitRegistrationWithPayment";

// Interests__c is a 255-character text field, so the joined selection must fit.
const MAX_INTERESTS_LENGTH = 255;
const DEFAULT_INTERESTS = [
  "Fiction",
  "Non-fiction",
  "Mystery",
  "Romance",
  "Fantasy",
  "Science",
  "Technology",
  "History",
  "Biography",
  "Children"
];
const PAYMENT_METHODS = [
  { name: "Card", icon: "▭", hint: "Credit or debit card" },
  { name: "UPI", icon: "◎", hint: "Pay from any UPI app" },
  { name: "Net banking", icon: "⌂", hint: "Your bank's website" },
  { name: "Wallet", icon: "◈", hint: "Saved wallet balance" }
];

function newIdempotencyKey() {
  const random =
    typeof crypto !== "undefined" && crypto.randomUUID
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  return `reg-${random}`.slice(0, 80);
}

function durationText(days) {
  const value = Number(days || 0);
  if (!value) return "Flexible term";
  if (value % 365 === 0) {
    const years = value / 365;
    return `${years} year${years === 1 ? "" : "s"}`;
  }
  if (value % 30 === 0) {
    const months = value / 30;
    return `${months} month${months === 1 ? "" : "s"}`;
  }
  return `${value} days`;
}

export default class LibraryRegistration extends LightningElement {
  form = {};
  plans = [];
  interestOptions = [];
  selectedInterests = [];
  interestsOpen = false;
  loading = false;
  submitted = false;
  errorMessage;
  successMessage =
    "Your membership application has been submitted successfully. A librarian will review your application and you will receive an email when a decision is made.";

  pendingInput;
  quote;
  showPayment = false;
  selectedMethod = "Card";
  paymentError;
  paying = false;
  idempotencyKey;

  connectedCallback() {
    getActivePlans()
      .then((data) => {
        this.plans = data || [];
      })
      .catch((error) => {
        this.errorMessage = this.message(error);
      });
    getInterestOptions()
      .then((names) => {
        this.interestOptions =
          names && names.length ? names : DEFAULT_INTERESTS;
      })
      .catch(() => {
        this.interestOptions = DEFAULT_INTERESTS;
      });
  }
  get interestItems() {
    return this.interestOptions.map((name) => {
      const checked = this.selectedInterests.includes(name);
      return {
        name,
        checked,
        disabled: !checked && !this.canAddInterest(name),
        className: checked ? "option selected" : "option"
      };
    });
  }
  get hasSelectedInterests() {
    return this.selectedInterests.length > 0;
  }
  get interestChips() {
    return this.selectedInterests.map((name) => ({ name }));
  }
  get interestsPlaceholder() {
    return this.hasSelectedInterests
      ? `${this.selectedInterests.length} selected`
      : "Choose your interests";
  }
  get interestsLimitReached() {
    return this.interestItems.some((item) => item.disabled);
  }
  get interestsListClass() {
    return this.interestsOpen ? "ms-list open" : "ms-list";
  }
  canAddInterest(name) {
    return (
      [...this.selectedInterests, name].join(", ").length <=
      MAX_INTERESTS_LENGTH
    );
  }
  toggleInterests() {
    this.interestsOpen = !this.interestsOpen;
  }
  handleInterestsFocusOut(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      this.interestsOpen = false;
    }
  }
  handleInterestChange(event) {
    const name = event.target.dataset.name;
    if (event.target.checked) {
      if (this.canAddInterest(name)) {
        this.selectedInterests = [...this.selectedInterests, name];
      }
    } else {
      this.removeInterestByName(name);
    }
  }
  handleRemoveInterest(event) {
    this.removeInterestByName(event.currentTarget.dataset.name);
  }
  removeInterestByName(name) {
    this.selectedInterests = this.selectedInterests.filter(
      (item) => item !== name
    );
  }
  get today() {
    return new Date().toISOString().slice(0, 10);
  }
  get planOptions() {
    return this.plans.map((plan) => ({ label: plan.Name, value: plan.Id }));
  }
  get selectedPlan() {
    return this.plans.find((plan) => plan.Id === this.form.requestedPlanId);
  }
  get submitLabel() {
    const fee = Number(this.selectedPlan?.Fee__c || 0);
    if (this.loading) return "Please wait…";
    return fee > 0 ? "Continue to payment" : "Submit";
  }
  handleChange(event) {
    const fieldName = event.currentTarget.dataset.field;
    this.form = { ...this.form, [fieldName]: event.currentTarget.value };
  }

  get paymentMethods() {
    return PAYMENT_METHODS.map((method) => {
      const selected = method.name === this.selectedMethod;
      return {
        ...method,
        selected,
        className: selected ? "method selected" : "method"
      };
    });
  }
  get selectedMethodHint() {
    return `Demo mode: no ${this.selectedMethod} details are needed and nothing is charged.`;
  }
  get amountLabel() {
    if (!this.quote) return "";
    try {
      return new Intl.NumberFormat(undefined, {
        style: "currency",
        currency: this.quote.currencyCode || "INR",
        maximumFractionDigits: this.quote.amount % 1 === 0 ? 0 : 2
      }).format(this.quote.amount);
    } catch {
      return `${this.quote.currencyCode} ${this.quote.amount}`;
    }
  }
  get termLabel() {
    return durationText(this.quote?.durationDays);
  }
  get payLabel() {
    return this.paying ? "Processing payment…" : `Pay ${this.amountLabel}`;
  }

  collectInput() {
    const fields = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-textarea, lightning-combobox"
      )
    ];
    // Validate every field (no short-circuit) so each shows its own message.
    const validity = fields.map((field) => field.reportValidity());
    if (validity.includes(false)) return undefined;
    this.form = fields.reduce((values, field) => {
      const fieldName = field.dataset.field;
      if (fieldName) values[fieldName] = field.value;
      return values;
    }, {});
    // Apex Date parameters cannot deserialize an empty string. Optional form
    // fields must be omitted when the member leaves them blank.
    const input = { ...this.form };
    if (!input.dateOfBirth) delete input.dateOfBirth;
    if (this.hasSelectedInterests) {
      input.interests = this.selectedInterests.join(", ");
    }
    return input;
  }

  handleSubmit(event) {
    event.preventDefault();
    this.errorMessage = undefined;
    const input = this.collectInput();
    if (!input) return undefined;
    this.pendingInput = input;
    this.loading = true;
    return getPaymentQuote({ planId: input.requestedPlanId })
      .then((quote) => {
        this.quote = quote;
        if (quote.paymentRequired) {
          this.idempotencyKey = newIdempotencyKey();
          this.selectedMethod = "Card";
          this.paymentError = undefined;
          this.showPayment = true;
          return undefined;
        }
        return this.completeRegistration(null);
      })
      .catch((error) => {
        this.errorMessage = this.message(error);
      })
      .finally(() => {
        this.loading = false;
      });
  }

  handleSelectMethod(event) {
    if (this.paying) return;
    this.selectedMethod = event.currentTarget.dataset.method;
  }

  closePayment() {
    if (this.paying) return;
    this.showPayment = false;
    this.paymentError = undefined;
  }

  handleDialogKeydown(event) {
    if (event.key === "Escape") this.closePayment();
  }

  handlePay() {
    if (this.paying) return undefined;
    this.paying = true;
    this.paymentError = undefined;
    return this.completeRegistration(this.selectedMethod)
      .catch((error) => {
        this.paymentError = this.message(error);
      })
      .finally(() => {
        this.paying = false;
      });
  }

  completeRegistration(method) {
    return submitRegistrationWithPayment({
      input: this.pendingInput,
      paymentMethod: method,
      idempotencyKey: method ? this.idempotencyKey : null
    }).then(() => {
      if (method) {
        this.successMessage = `Payment of ${this.amountLabel} received. Your membership application has been submitted successfully. A librarian will review it and you will receive an email when a decision is made.`;
      }
      this.showPayment = false;
      this.submitted = true;
    });
  }

  message(error) {
    return (
      error?.body?.message ||
      "We could not submit your application. Please check your details and try again."
    );
  }
}
