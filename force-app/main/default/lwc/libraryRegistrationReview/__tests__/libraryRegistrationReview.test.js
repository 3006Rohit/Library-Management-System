import { createElement } from "lwc";
import LibraryRegistrationReview from "c/libraryRegistrationReview";
import getRegistrationForReview from "@salesforce/apex/LibraryExternalRegistrationController.getRegistrationForReview";

jest.mock(
  "@salesforce/apex/LibraryExternalRegistrationController.getRegistrationForReview",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryExternalRegistrationController.rejectRegistration",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryExternalRegistrationController.retryProvisioning",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-library-registration-review", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("loads a pending registration and queues approval", async () => {
    getRegistrationForReview.mockResolvedValue({
      Id: "reg-1",
      Status__c: "Pending",
      Provisioning_State__c: "Not Started",
      Requested_Plan__r: {},
      Approved_By__r: {},
      Created_Contact__r: {},
      Created_Member__r: {}
    });
    const element = createElement("c-library-registration-review", {
      is: LibraryRegistrationReview
    });
    element.recordId = "reg-1";
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("Pending");
    expect(getRegistrationForReview).toHaveBeenCalledWith({
      registrationId: "reg-1"
    });
  });
});
