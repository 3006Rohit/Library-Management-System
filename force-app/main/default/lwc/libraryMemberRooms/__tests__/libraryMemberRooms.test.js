import { createElement } from "lwc";
import LibraryMemberRooms from "c/libraryMemberRooms";
import getLibraryRooms from "@salesforce/apex/LibraryMemberSessionController.getLibraryRooms";
import getLibraryRoomSeats from "@salesforce/apex/LibraryMemberSessionController.getLibraryRoomSeats";
import bookLibraryRoom from "@salesforce/apex/LibraryMemberSessionController.bookLibraryRoom";
import getMyRoomBookings from "@salesforce/apex/LibraryMemberSessionController.getMyRoomBookings";
import getRoomDemandForecast from "@salesforce/apex/LibraryMemberSessionController.getRoomDemandForecast";

jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getLibraryRooms",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getLibraryRoomSeats",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.bookLibraryRoom",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getMyRoomBookings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.cancelLibraryRoomBooking",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryMemberSessionController.getRoomDemandForecast",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: class ShowToastEvent extends CustomEvent {
      constructor(detail) {
        super("lightning__showtoast", { detail });
      }
    }
  }),
  { virtual: true }
);

const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

const FORECAST = {
  hasData: true,
  peakHourLabel: "5 PM - 6 PM",
  peakDayLabel: "Thursday",
  quietTimes: ["9 AM - 10 AM"],
  hours: Array.from({ length: 14 }, (_, i) => ({
    hour: 8 + i,
    label: `${8 + i}`,
    bookings: 1,
    percent: 20,
    level: "Low"
  })),
  days: Array.from({ length: 7 }, (_, i) => ({
    day: i + 1,
    label: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i],
    bookings: 1,
    percent: 20,
    level: "Low"
  })),
  suggestions: ["Rooms are usually busiest at 5 PM - 6 PM."]
};

const ROOMS = [
  {
    id: "shared-1",
    name: "Study Room A",
    capacity: 6,
    availableSeats: 4,
    available: true,
    isPrivate: false,
    roomType: "Shared"
  },
  {
    id: "pod-1",
    name: "Quiet Pod",
    capacity: 1,
    availableSeats: 1,
    available: true,
    isPrivate: true,
    roomType: "Private"
  }
];

function mount() {
  const element = createElement("c-library-member-rooms", {
    is: LibraryMemberRooms
  });
  document.body.appendChild(element);
  return element;
}

describe("c-library-member-rooms", () => {
  beforeEach(() => {
    getLibraryRooms.mockResolvedValue(ROOMS);
    getMyRoomBookings.mockResolvedValue([]);
    getRoomDemandForecast.mockResolvedValue(FORECAST);
    getLibraryRoomSeats.mockResolvedValue([
      { seatNo: 1, taken: false },
      { seatNo: 2, taken: false }
    ]);
    bookLibraryRoom.mockResolvedValue({});
  });

  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("shows the busy-times guide with the best times to book", async () => {
    const element = mount();
    await flush();
    const text = element.shadowRoot.querySelector(".forecast").textContent;
    expect(text).toContain("When are the rooms busiest?");
    expect(text).toContain("Best times to book:");
    expect(text).toContain("9 AM - 10 AM");
    expect(text).toContain("busiest at 5 PM - 6 PM");
    expect(element.shadowRoot.querySelectorAll(".chart .col")).toHaveLength(21);
    expect(element.shadowRoot.querySelector(".expected")).not.toBeNull();
  });

  it("still lets members book when the forecast is unavailable", async () => {
    getRoomDemandForecast.mockRejectedValue({ body: { message: "No." } });
    const element = mount();
    await flush();
    expect(element.shadowRoot.querySelector(".forecast")).toBeNull();
    expect(element.shadowRoot.querySelectorAll(".room-card")).toHaveLength(2);
  });

  it("books a whole private room without a seat map", async () => {
    const element = mount();
    await flush();
    const podButton = [
      ...element.shadowRoot.querySelectorAll(".room-card")
    ].find((card) => card.textContent.includes("Quiet Pod"));
    expect(podButton.textContent).toContain("Private room");
    expect(podButton.textContent).toContain("Book private room");
    podButton.querySelector("button").click();
    await flush();
    expect(getLibraryRoomSeats).not.toHaveBeenCalled();
    expect(element.shadowRoot.querySelector(".seat-grid")).toBeNull();
    expect(element.shadowRoot.querySelector(".private-note")).not.toBeNull();
    const reserve = [
      ...element.shadowRoot.querySelectorAll(".seat-panel button")
    ].find((button) => button.textContent.includes("Reserve private room"));
    expect(reserve.disabled).toBe(false);
    reserve.click();
    await flush();
    expect(bookLibraryRoom).toHaveBeenCalledWith(
      expect.objectContaining({ roomId: "pod-1", seatNumber: 1 })
    );
  });

  it("still shows the seat map for shared rooms", async () => {
    const element = mount();
    await flush();
    const shared = [...element.shadowRoot.querySelectorAll(".room-card")].find(
      (card) => card.textContent.includes("Study Room A")
    );
    shared.querySelector("button").click();
    await flush();
    expect(getLibraryRoomSeats).toHaveBeenCalled();
    expect(element.shadowRoot.querySelectorAll(".seat")).toHaveLength(2);
    expect(element.shadowRoot.querySelector(".private-note")).toBeNull();
  });
});
