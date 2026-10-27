import { createElement } from "lwc";
import LibraryPaymentOperations from "c/libraryPaymentOperations";
import getPaymentReconciliationExceptions from "@salesforce/apex/LibraryLibrarianController.getPaymentReconciliationExceptions";
import getPaymentGatewayConfigurationStatus from "@salesforce/apex/LibraryLibrarianController.getPaymentGatewayConfigurationStatus";

jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getPaymentReconciliationExceptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getPaymentGatewayConfigurationStatus",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.reconcileMembershipPayment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.createPaymentReceipt",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("libraryPaymentOperations", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("shows safe gateway readiness without exposing provider secrets", async () => {
    getPaymentReconciliationExceptions.mockResolvedValue([]);
    getPaymentGatewayConfigurationStatus.mockResolvedValue({
      ready: false,
      enabled: false,
      providerName: null,
      currencyCode: "INR",
      checkoutCredentialConfigured: false,
      webhookConfigured: false,
      message: "No default payment gateway configuration is present."
    });
    const element = createElement("c-library-payment-operations", {
      is: LibraryPaymentOperations
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".gateway-status").textContent
    ).toContain("Action required");
    expect(element.shadowRoot.textContent).toContain(
      "No default payment gateway configuration is present."
    );
    expect(element.shadowRoot.textContent).not.toContain("Webhook secret");
  });

  it("renders ready gateway state when all safe configuration checks pass", async () => {
    getPaymentReconciliationExceptions.mockResolvedValue([]);
    getPaymentGatewayConfigurationStatus.mockResolvedValue({
      ready: true,
      enabled: true,
      providerName: "Hosted Provider",
      currencyCode: "INR",
      checkoutCredentialConfigured: true,
      webhookConfigured: true,
      message: "Payment gateway configuration is ready for provider validation."
    });
    const element = createElement("c-library-payment-operations", {
      is: LibraryPaymentOperations
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(
      element.shadowRoot
        .querySelector(".gateway-status")
        .classList.contains("ready")
    ).toBe(true);
    expect(element.shadowRoot.textContent).toContain("Ready");
  });
});
