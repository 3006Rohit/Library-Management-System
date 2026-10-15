import { createElement } from "lwc";
import LibraryMemberAuthFlow from "c/libraryMemberAuthFlow";
import activateAccount from "@salesforce/apex/LibraryMemberAuthController.activateAccount";
import forgotPassword from "@salesforce/apex/LibraryMemberAuthController.forgotPassword";
import resetPassword from "@salesforce/apex/LibraryMemberAuthController.resetPassword";

jest.mock(
  "@salesforce/apex/LibraryMemberAuthController.activateAccount",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberAuthController.forgotPassword",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberAuthController.resetPassword",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
function element(mode) {
  const value = createElement("c-library-member-auth-flow", {
    is: LibraryMemberAuthFlow
  });
  value.mode = mode;
  document.body.appendChild(value);
  return value;
}
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
});

it("generates a generic forgot-password response", async () => {
  const value = element("forgot");
  value.email = "member@example.com";
  value.submit();
  await flush();
  await flush();
  expect(forgotPassword).toHaveBeenCalledWith({ email: "member@example.com" });
  expect(value.shadowRoot.textContent).toContain("If an account exists");
});
it("submits activation and reset with the route token", async () => {
  const activate = element("activate");
  activate.token = "activation-token";
  activate.password = "StrongPass123";
  activate.confirmation = "StrongPass123";
  activate.submit();
  await flush();
  expect(activateAccount).toHaveBeenCalledWith({
    token: "activation-token",
    password: "StrongPass123",
    confirmation: "StrongPass123"
  });
  document.body.removeChild(activate);
  const reset = element("reset");
  reset.token = "reset-token";
  reset.password = "StrongPass123";
  reset.confirmation = "StrongPass123";
  reset.submit();
  await flush();
  expect(resetPassword).toHaveBeenCalledWith({
    token: "reset-token",
    password: "StrongPass123",
    confirmation: "StrongPass123"
  });
});
