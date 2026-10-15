import { createElement } from "lwc";
import LibraryRegistration from "c/libraryRegistration";
import getActivePlans from "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans";

jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.submitRegistration",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flushPromises = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("libraryRegistration", () => {
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
});
