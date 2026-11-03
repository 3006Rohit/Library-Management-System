import { createElement } from "lwc";
import LibraryContact from "c/libraryContact";
import getBranches from "@salesforce/apex/LibraryContactController.getBranches";
import submitMessage from "@salesforce/apex/LibraryContactController.submitMessage";

jest.mock(
  "@salesforce/apex/LibraryContactController.getBranches",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryContactController.submitMessage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

function mount() {
  const element = createElement("c-library-contact", { is: LibraryContact });
  document.body.appendChild(element);
  return element;
}

function type(element, name, value) {
  const input = element.shadowRoot.querySelector(`[name="${name}"]`);
  input.value = value;
  input.dispatchEvent(new CustomEvent("input"));
}

function submit(element) {
  element.shadowRoot
    .querySelector("form")
    .dispatchEvent(new CustomEvent("submit", { cancelable: true }));
}

describe("c-library-contact", () => {
  beforeEach(() => {
    getBranches.mockResolvedValue([
      { name: "Central", address: "1 Main St", openingHours: "Mon-Fri 9-5" }
    ]);
  });

  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("shows published branch address and hours", async () => {
    const element = mount();
    await flush();
    expect(element.shadowRoot.textContent).toContain("Central, 1 Main St");
    expect(element.shadowRoot.textContent).toContain("Mon-Fri 9-5");
  });

  it("validates before sending", async () => {
    const element = mount();
    await flush();
    submit(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Enter your first and last name."
    );
    expect(submitMessage).not.toHaveBeenCalled();
  });

  it("sends the message and shows a confirmation", async () => {
    submitMessage.mockResolvedValue();
    const element = mount();
    await flush();
    type(element, "firstName", "Jane");
    type(element, "lastName", "Doe");
    type(element, "email", "jane@example.com");
    type(element, "message", "Hello there");
    submit(element);
    await flush();
    expect(submitMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        firstName: "Jane",
        email: "jane@example.com",
        message: "Hello there"
      })
    );
    expect(element.shadowRoot.textContent).toContain("Message sent");
  });

  it("shows the server error when sending fails", async () => {
    submitMessage.mockRejectedValue({ body: { message: "Try later." } });
    const element = mount();
    await flush();
    type(element, "firstName", "Jane");
    type(element, "lastName", "Doe");
    type(element, "email", "jane@example.com");
    type(element, "message", "Hello there");
    submit(element);
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "Try later."
    );
  });
});
