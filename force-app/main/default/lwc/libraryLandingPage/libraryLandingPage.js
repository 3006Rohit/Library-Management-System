import { LightningElement } from "lwc";
import searchPublicCatalog from "@salesforce/apex/LibraryRegistrationGuestController.searchPublicCatalog";
import getActivePlans from "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans";
import getDisplayCurrency from "@salesforce/apex/LibraryRegistrationGuestController.getDisplayCurrency";
import startSession from "@salesforce/apex/LibraryPublicAgentController.startSession";
import sendMessage from "@salesforce/apex/LibraryPublicAgentController.sendMessage";
import endSession from "@salesforce/apex/LibraryPublicAgentController.endSession";

const COVER_COLORS = ["#2f4b7c", "#a4483a", "#3d6b57", "#6d5a8a"];
const BOT_CLASS = "bubble bot";
const USER_CLASS = "bubble user";

function durationLabel(days) {
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

// Prices are always shown in the library's own currency, never the visitor's.
function formatMoney(amount, currencyCode) {
  try {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: currencyCode || "INR",
      maximumFractionDigits: amount % 1 === 0 ? 0 : 2
    }).format(amount);
  } catch {
    return `${currencyCode} ${amount.toFixed(2)}`;
  }
}

// Whole months in a plan term, so 365 days is 12 months and 30 days is 1.
function monthsInTerm(days) {
  return Math.max(1, Math.round(days / 30.4375));
}

function errorText(error) {
  return (
    error?.body?.message ||
    error?.message ||
    (typeof error === "string" ? error : "Unknown error")
  );
}

export default class LibraryLandingPage extends LightningElement {
  books = [];
  rawPlans = [];
  currencyCode = "INR";
  billing = "annual";
  activeFilter = "";
  input = "";
  busy = false;
  sessionId;
  sequence = 0;
  messages = [
    {
      id: "welcome",
      className: BOT_CLASS,
      text: "Hi! I can answer questions about branch hours, membership plans and library policies. What would you like to know?"
    }
  ];

  filters = [
    { label: "Fiction", term: "fiction" },
    { label: "Science", term: "science" },
    { label: "Kids", term: "kids" },
    { label: "Available now", term: "" }
  ].map((f) => ({ ...f, key: f.label, className: "chip" }));

  suggestions = ["Branch hours", "Membership plans", "Library policies"];

  stats = [
    { value: "+25k", label: "Books and media" },
    { value: "+8k", label: "Active members" }
  ];

  members = [
    "Borrow and reserve books",
    "My Books, reading list, followed authors",
    "Fines, renewals and notifications"
  ];

  connectedCallback() {
    this.loadBooks("");
    this.loadPlans();
  }

  disconnectedCallback() {
    if (this.sessionId) {
      endSession({ sessionId: this.sessionId }).catch(() => undefined);
      this.sessionId = undefined;
    }
  }

  get filterItems() {
    return this.filters.map((f) => ({
      ...f,
      className: f.term === this.activeFilter && f.term ? "chip active" : "chip"
    }));
  }

  get showPlansSection() {
    return true;
  }

  get isMonthly() {
    return !this.isAnnual;
  }

  get isAnnual() {
    return this.billing === "annual";
  }

  get monthlyTabClass() {
    return this.isAnnual ? "tab" : "tab active";
  }

  get annualTabClass() {
    return this.isAnnual ? "tab active" : "tab";
  }

  handleBilling(event) {
    this.billing = event.currentTarget.dataset.billing;
  }

  get plans() {
    const rows = [...this.rawPlans].sort(
      (a, b) =>
        Number(a.Fee__c || 0) - Number(b.Fee__c || 0) ||
        String(a.Name).localeCompare(String(b.Name))
    );
    const topLimit = Math.max(
      0,
      ...rows.map((p) => Number(p.Borrow_Limit__c || 0))
    );
    const featuredId =
      rows.length > 1
        ? rows.find((p) => Number(p.Borrow_Limit__c || 0) === topLimit)?.Id
        : undefined;
    return rows.map((plan) => {
      const featured = plan.Id === featuredId;
      const limit = Number(plan.Borrow_Limit__c || 0);
      const days = Number(plan.Duration_Days__c || 0);
      const fee = Number(plan.Fee__c || 0);
      const term = durationLabel(days);
      const reservations = Number(plan.Reservation_Limit__c || 0);
      const renewals = Number(plan.Renewal_Limit__c || 0);
      const loanDays = Number(plan.Loan_Duration_Days__c || 0);
      let price = "Free";
      let unit = "";
      if (fee > 0 && days > 0) {
        const perMonth = fee / monthsInTerm(days);
        price = formatMoney(
          this.isAnnual ? perMonth * 12 : perMonth,
          this.currencyCode
        );
        unit = this.isAnnual ? "/year" : "/month";
      } else if (fee > 0) {
        price = formatMoney(fee, this.currencyCode);
        unit = `/${term}`;
      }
      const billedNote =
        fee > 0
          ? `${formatMoney(fee, this.currencyCode)} billed for ${term}`
          : `${term} membership`;
      const includes = [
        limit
          ? `Borrow up to ${limit} books at a time`
          : "Borrow without a set limit",
        loanDays ? `${loanDays}-day loan period` : null,
        reservations ? `Up to ${reservations} reservations` : null,
        renewals ? `${renewals} renewals per loan` : null,
        "Online reservations and tracking"
      ].filter(Boolean);
      return {
        id: plan.Id,
        name: plan.Name,
        price,
        unit,
        billedNote,
        description: plan.Description__c || "Library membership plan.",
        featured,
        className: featured ? "plan featured" : "plan",
        buttonClass: featured ? "btn white wide" : "btn outline wide",
        includes: includes.map((text) => ({ text, key: `${plan.Id}-${text}` }))
      };
    });
  }

  get customPlan() {
    return {
      includes: [
        "Bulk memberships for groups",
        "Custom borrow and loan limits",
        "Dedicated librarian support"
      ].map((text) => ({ text, key: `custom-${text}` }))
    };
  }

  async loadPlans() {
    try {
      const [plans, currencyCode] = await Promise.all([
        getActivePlans(),
        getDisplayCurrency().catch(() => "INR")
      ]);
      this.currencyCode = currencyCode || "INR";
      this.rawPlans = plans || [];
    } catch {
      this.rawPlans = [];
    }
  }

  get hasBooks() {
    return this.books.length > 0;
  }

  get sendLabel() {
    return this.busy ? "…" : "➤";
  }

  async loadBooks(term) {
    try {
      const rows = await searchPublicCatalog({ searchTerm: term });
      this.books = (rows || []).slice(0, 4).map((book, index) => ({
        id: book.id,
        title: book.title,
        coverUrl: book.coverUrl,
        style: `background:${COVER_COLORS[index % COVER_COLORS.length]}`
      }));
    } catch {
      this.books = [];
    }
  }

  handleFilter(event) {
    const term = event.currentTarget.dataset.term;
    this.activeFilter = term === this.activeFilter ? "" : term;
    this.loadBooks(this.activeFilter);
  }

  handleInput(event) {
    this.input = event.target.value;
  }

  handleSuggestion(event) {
    this.input = event.currentTarget.dataset.question;
    this.send();
  }

  async send(event) {
    event?.preventDefault();
    const question = this.input.trim();
    if (!question || this.busy) return;
    this.messages = [
      ...this.messages,
      { id: `q-${Date.now()}`, className: USER_CLASS, text: question }
    ];
    this.input = "";
    this.busy = true;
    try {
      if (!this.sessionId) {
        const session = await startSession();
        this.sessionId = session.sessionId;
        this.sequence = 0;
      }
      this.sequence += 1;
      const response = await sendMessage({
        sessionId: this.sessionId,
        sequenceId: this.sequence,
        text: question
      });
      this.messages = [
        ...this.messages,
        { id: `a-${Date.now()}`, className: BOT_CLASS, text: response.message }
      ];
    } catch (error) {
      this.messages = [
        ...this.messages,
        {
          id: `e-${Date.now()}`,
          className: BOT_CLASS,
          text: `The assistant is unavailable right now: ${errorText(error)}`
        }
      ];
      this.sessionId = undefined;
      this.sequence = 0;
    } finally {
      this.busy = false;
    }
  }
}
