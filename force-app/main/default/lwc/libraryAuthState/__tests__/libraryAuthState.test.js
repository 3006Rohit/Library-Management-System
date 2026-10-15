import { createElement } from "lwc";
import LibraryAuthState from "c/libraryAuthState";

describe("c-library-auth-state", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
  });

  it("renders the configured state and emits stateaction", () => {
    const element = createElement("c-library-auth-state", {
      is: LibraryAuthState
    });
    element.title = "Pending approval";
    element.actionLabel = "Return";
    const handler = jest.fn();
    element.addEventListener("stateaction", handler);
    document.body.appendChild(element);
    expect(element.shadowRoot.textContent).toContain("Pending approval");
    element.shadowRoot.querySelector("button").click();
    expect(handler).toHaveBeenCalledTimes(1);
  });
});
