import { createElement } from "lwc";
import LibraryLandingPage from "c/libraryLandingPage";
import getActivePlans from "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans";
import getDisplayCurrency from "@salesforce/apex/LibraryRegistrationGuestController.getDisplayCurrency";
import getLibraryStats from "@salesforce/apex/LibraryRegistrationGuestController.getLibraryStats";
import endSession from "@salesforce/apex/LibraryPublicAgentController.endSession";
import startSession from "@salesforce/apex/LibraryPublicAgentController.startSession";
import sendMessage from "@salesforce/apex/LibraryPublicAgentController.sendMessage";
import searchPublicCatalog from "@salesforce/apex/LibraryRegistrationGuestController.searchPublicCatalog";

jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getActivePlans",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getDisplayCurrency",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.getLibraryStats",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryRegistrationGuestController.searchPublicCatalog",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryPublicAgentController.startSession",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryPublicAgentController.sendMessage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryPublicAgentController.endSession",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

// Deliberately returned in name order, as the Apex query does.
const PLANS = [
  {
    Id: "p1",
    Name: "Basic",
    Fee__c: 200,
    Duration_Days__c: 365,
    Borrow_Limit__c: 2
  },
  {
    Id: "p2",
    Name: "Premium",
    Fee__c: 1000,
    Duration_Days__c: 365,
    Borrow_Limit__c: 10
  },
  {
    Id: "p3",
    Name: "Standard",
    Fee__c: 500,
    Duration_Days__c: 365,
    Borrow_Limit__c: 5
  }
];

async function mount() {
  searchPublicCatalog.mockResolvedValue([]);
  getActivePlans.mockResolvedValue(PLANS);
  getDisplayCurrency.mockResolvedValue("INR");
  getLibraryStats.mockResolvedValue({ bookCount: 1234, memberCount: 56 });
  const element = createElement("c-library-landing-page", {
    is: LibraryLandingPage
  });
  document.body.appendChild(element);
  await flush();
  return element;
}

const planCards = (element) => [
  ...element.shadowRoot.querySelectorAll(".plan-grid .plan")
];

describe("c-library-landing-page plans", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("lists plans from cheapest to dearest", async () => {
    const element = await mount();
    const names = planCards(element)
      .slice(0, 3)
      .map((card) => card.querySelector(".plan-name").textContent);
    expect(names).toEqual(["Basic", "Standard", "Premium"]);
  });

  it("shows each plan's real fee in rupees per year", async () => {
    const element = await mount();
    const prices = planCards(element)
      .slice(0, 3)
      .map((card) => card.querySelector(".plan-price").textContent);
    expect(prices[0]).toContain("₹200");
    expect(prices[1]).toContain("₹500");
    expect(prices[2]).toContain("₹1,000");
    prices.forEach((price) => {
      expect(price).toContain("/year");
      expect(price).not.toContain("$");
    });
  });

  it("converts to a clean monthly price when the toggle changes", async () => {
    const element = await mount();
    element.shadowRoot.querySelector('button[data-billing="monthly"]').click();
    await flush();
    const prices = planCards(element)
      .slice(0, 3)
      .map((card) => card.querySelector(".plan-price").textContent);
    expect(prices[0]).toContain("₹16.67");
    expect(prices[1]).toContain("₹41.67");
    expect(prices[2]).toContain("₹83.33");
    prices.forEach((price) => expect(price).toContain("/month"));
  });

  it("marks the plan with the highest borrow limit as most popular", async () => {
    const element = await mount();
    const featured = element.shadowRoot.querySelector(".plan.featured");
    expect(featured.textContent).toContain("Premium");
    expect(featured.querySelector(".popular")).not.toBeNull();
  });
});

describe("c-library-landing-page assistant", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  async function ask(reply) {
    endSession.mockResolvedValue();
    startSession.mockResolvedValue({ sessionId: "s1" });
    sendMessage.mockResolvedValue({ message: reply });
    const element = await mount();
    const input = element.shadowRoot.querySelector(".composer input");
    input.value = "question";
    input.dispatchEvent(new CustomEvent("input"));
    element.shadowRoot
      .querySelector(".composer")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    return element;
  }

  it("shows Register and Log in buttons when a reply needs membership", async () => {
    const element = await ask("Holds need registration and a membership.");
    const links = [...element.shadowRoot.querySelectorAll(".gate-actions a")];
    expect(links.map((a) => a.getAttribute("href"))).toEqual([
      "/library/register",
      "/library/login"
    ]);
  });

  it("does not show the buttons for a plain availability reply", async () => {
    const element = await ask("Dune: 2 of 3 copies available.");
    expect(element.shadowRoot.querySelector(".gate-actions")).toBeNull();
  });
});
