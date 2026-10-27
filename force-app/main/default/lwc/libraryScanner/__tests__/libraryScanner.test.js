import { createElement } from "lwc";
import LibraryScanner from "c/libraryScanner";
import lookupScannedCopy from "@salesforce/apex/LibraryMemberSessionController.lookupScannedCopy";
import scanSelfCheckout from "@salesforce/apex/LibraryMemberSessionController.scanSelfCheckout";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.lookupScannedCopy",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.scanSelfCheckout",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.scanReturn",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-scanner", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
    sessionStorage.clear();
  });

  it("previews and confirms a manual barcode checkout", async () => {
    sessionStorage.setItem("libraryMemberSession", "session-token");
    lookupScannedCopy.mockResolvedValue({
      success: true,
      status: "Available",
      barcode: "BAR-1",
      bookTitle: "A Book",
      message: "Copy is available for checkout."
    });
    scanSelfCheckout.mockResolvedValue({
      success: true,
      message: "Checkout completed."
    });
    const element = createElement("c-library-scanner", {
      is: LibraryScanner
    });
    document.body.appendChild(element);
    const input = element.shadowRoot.querySelector("lightning-input");
    input.value = "BAR-1";
    input.dispatchEvent(
      new CustomEvent("change", { detail: { value: "BAR-1" } })
    );
    element.shadowRoot.querySelector(".button.primary").click();
    await flush();
    expect(lookupScannedCopy).toHaveBeenCalledWith({
      sessionToken: "session-token",
      barcode: "BAR-1"
    });
    expect(element.shadowRoot.textContent).toContain("A Book");
    Array.from(element.shadowRoot.querySelectorAll("button"))
      .find((button) => button.textContent.includes("Confirm checkout"))
      .click();
    await flush();
    expect(scanSelfCheckout).toHaveBeenCalledWith(
      expect.objectContaining({
        sessionToken: "session-token",
        barcode: "BAR-1"
      })
    );
    expect(element.shadowRoot.textContent).toContain("Checkout completed.");
  });

  it("explains when camera scanning is unavailable", async () => {
    const element = createElement("c-library-scanner", {
      is: LibraryScanner
    });
    document.body.appendChild(element);
    Array.from(element.shadowRoot.querySelectorAll("button"))
      .find((button) => button.textContent.includes("Use camera"))
      .click();
    await flush();
    expect(element.shadowRoot.textContent).toContain(
      "Camera scanning is not available here"
    );
  });
});
