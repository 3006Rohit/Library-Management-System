import { createElement } from "lwc";
import LibraryDamageReplacementPanel from "c/libraryDamageReplacementPanel";
import getReplacementOptions from "@salesforce/apex/LibraryLibrarianController.getReplacementOptions";
import reportDefectiveCopy from "@salesforce/apex/LibraryLibrarianController.reportDefectiveCopy";
import replaceDefectiveCopy from "@salesforce/apex/LibraryLibrarianController.replaceDefectiveCopy";

jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getReplacementOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.reportDefectiveCopy",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryLibrarianController.replaceDefectiveCopy",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-damage-replacement-panel", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("loads replacement options with readable labels", async () => {
    getReplacementOptions.mockResolvedValue([
      {
        Id: "copy-1",
        Name: "Copy 1",
        Barcode__c: "BC1",
        Shelf_Location__c: "A1"
      }
    ]);
    const element = createElement("c-library-damage-replacement-panel", {
      is: LibraryDamageReplacementPanel
    });
    element.recordId = "loan-1";
    document.body.appendChild(element);
    await flush();
    expect(
      element.shadowRoot.querySelector("lightning-combobox").options[0]
    ).toEqual(
      expect.objectContaining({ label: "Copy 1 — BC1 — A1", value: "copy-1" })
    );
    expect(getReplacementOptions).toHaveBeenCalledWith({ loanId: "loan-1" });
  });

  it("rejects replacement without a selected copy", async () => {
    getReplacementOptions.mockResolvedValue([]);
    const element = createElement("c-library-damage-replacement-panel", {
      is: LibraryDamageReplacementPanel
    });
    document.body.appendChild(element);
    await flush();
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    buttons[1].click();
    await flush();
    expect(
      element.shadowRoot.querySelector('[role="alert"]').textContent
    ).toContain("Select an available replacement copy.");
    expect(replaceDefectiveCopy).not.toHaveBeenCalled();
    expect(reportDefectiveCopy).not.toHaveBeenCalled();
  });
});
