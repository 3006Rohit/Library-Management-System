import { createElement } from "lwc";
import LibraryRegistration from "c/libraryRegistration";
import getActivePlans from "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans";
import getInterestOptions from "@salesforce/apex/LibraryRegistrationGuestController.getInterestOptions";
import getPaymentQuote from "@salesforce/apex/LibraryRegistrationGuestController.getPaymentQuote";
import submitRegistrationWithPayment from "@salesforce/apex/LibraryRegistrationGuestController.submitRegistrationWithPayment";

jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getPaymentQuote",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getInterestOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.submitRegistrationWithPayment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flushPromises = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("libraryRegistration", () => {
  beforeEach(() => {
    getInterestOptions.mockResolvedValue(["Fiction", "Science", "History"]);
  });

  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("loads active membership plans into selectable options", async () => {
    getActivePlans.mockResolvedValue([
      { Id: "plan-1", Name: "Standard" },
      { Id: "plan-2", Name: "Premium" }
    ]);
    const element = createElement("c-library-registration", {
      is: LibraryRegistration
    });
    document.body.appendChild(element);
    await flushPromises();
    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    expect(combobox.options).toEqual([
      { label: "Standard", value: "plan-1" },
      { label: "Premium", value: "plan-2" }
    ]);
    expect(element.shadowRoot.querySelector('[role="alert"]')).toBeNull();
  });

  it("exposes a useful plan-loading error", async () => {
    getActivePlans.mockRejectedValue({
      body: { message: "Membership plan access denied." }
    });
    const element = createElement("c-library-registration", {
      is: LibraryRegistration
    });
    document.body.appendChild(element);
    await flushPromises();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Membership plan access denied."
    );
  });

  it("lets members pick several book interests", async () => {
    getActivePlans.mockResolvedValue([]);
    const element = createElement("c-library-registration", {
      is: LibraryRegistration
    });
    document.body.appendChild(element);
    await flushPromises();
    const boxes = element.shadowRoot.querySelectorAll(
      ".ms-list input[type=checkbox]"
    );
    expect(boxes).toHaveLength(3);
    boxes[0].checked = true;
    boxes[0].dispatchEvent(new CustomEvent("change"));
    boxes[2].checked = true;
    boxes[2].dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    const chips = [...element.shadowRoot.querySelectorAll(".ms-chip")].map(
      (chip) => chip.textContent.replace("×", "").trim()
    );
    expect(chips).toEqual(["Fiction", "History"]);
    element.shadowRoot.querySelector(".ms-chip button").click();
    await flushPromises();
    expect(element.shadowRoot.querySelectorAll(".ms-chip")).toHaveLength(1);
  });

  async function fillAndSubmit() {
    getActivePlans.mockResolvedValue([
      { Id: "plan-1", Name: "Gold", Fee__c: 499 }
    ]);
    const element = createElement("c-library-registration", {
      is: LibraryRegistration
    });
    document.body.appendChild(element);
    await flushPromises();
    const values = {
      firstName: "Pay",
      lastName: "Tester",
      email: "pay@example.com",
      requestedPlanId: "plan-1"
    };
    element.shadowRoot.querySelectorAll("[data-field]").forEach((field) => {
      const value = values[field.dataset.field];
      if (value) {
        field.value = value;
        field.dispatchEvent(new CustomEvent("change"));
      }
    });
    element.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit", { cancelable: true }));
    await flushPromises();
    return element;
  }

  it("opens the payment popup for a paid plan and completes after paying", async () => {
    getPaymentQuote.mockResolvedValue({
      planId: "plan-1",
      planName: "Gold",
      amount: 499,
      currencyCode: "INR",
      durationDays: 365,
      paymentRequired: true
    });
    submitRegistrationWithPayment.mockResolvedValue("a01000000000001");
    const element = await fillAndSubmit();
    expect(getPaymentQuote).toHaveBeenCalledWith({ planId: "plan-1" });
    expect(submitRegistrationWithPayment).not.toHaveBeenCalled();
    const dialog = element.shadowRoot.querySelector('[role="dialog"]');
    expect(dialog).not.toBeNull();
    expect(dialog.textContent).toContain("Gold");
    expect(dialog.textContent).toContain("1 year");

    element.shadowRoot.querySelector('[data-method="UPI"]').click();
    await flushPromises();
    dialog.querySelector("button.submit-button").click();
    await flushPromises();

    expect(submitRegistrationWithPayment).toHaveBeenCalledWith(
      expect.objectContaining({
        paymentMethod: "UPI",
        idempotencyKey: expect.stringMatching(/^reg-/),
        input: expect.objectContaining({
          email: "pay@example.com",
          requestedPlanId: "plan-1"
        })
      })
    );
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
    expect(
      element.shadowRoot.querySelector("c-library-auth-state")
    ).not.toBeNull();
  });

  it("registers a free plan directly without a popup", async () => {
    getPaymentQuote.mockResolvedValue({
      planId: "plan-1",
      planName: "Free",
      amount: 0,
      currencyCode: "INR",
      paymentRequired: false
    });
    submitRegistrationWithPayment.mockResolvedValue("a01000000000002");
    const element = await fillAndSubmit();
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
    expect(submitRegistrationWithPayment).toHaveBeenCalledWith(
      expect.objectContaining({ paymentMethod: null, idempotencyKey: null })
    );
  });

  it("keeps the popup open and shows the error when payment fails", async () => {
    getPaymentQuote.mockResolvedValue({
      planId: "plan-1",
      planName: "Gold",
      amount: 499,
      currencyCode: "INR",
      durationDays: 30,
      paymentRequired: true
    });
    submitRegistrationWithPayment.mockRejectedValue({
      body: { message: "We could not complete your payment." }
    });
    const element = await fillAndSubmit();
    const dialog = element.shadowRoot.querySelector('[role="dialog"]');
    dialog.querySelector("button.submit-button").click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector('[role="dialog"] [role="alert"]')
        .textContent
    ).toBe("We could not complete your payment.");
  });

  it("falls back to default interests when none are configured", async () => {
    getInterestOptions.mockResolvedValue([]);
    getActivePlans.mockResolvedValue([]);
    const element = createElement("c-library-registration", {
      is: LibraryRegistration
    });
    document.body.appendChild(element);
    await flushPromises();
    expect(
      element.shadowRoot.querySelectorAll(".ms-list input[type=checkbox]")
        .length
    ).toBeGreaterThan(3);
  });
});
