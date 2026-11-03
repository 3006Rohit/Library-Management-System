import { createElement } from "lwc";
import LibraryLibrarianRoomInsights from "c/libraryLibrarianRoomInsights";
import getRoomInsights from "@salesforce/apex/LibraryLibrarianController.getRoomInsights";

jest.mock(
  "@salesforce/apex/LibraryLibrarianController.getRoomInsights",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

const hours = Array.from({ length: 14 }, (_, i) => ({
  hour: 8 + i,
  label: `${8 + i > 12 ? 8 + i - 12 : 8 + i} ${8 + i >= 12 ? "PM" : "AM"}`,
  bookings: i === 9 ? 6 : 1,
  percent: i === 9 ? 100 : 17,
  level: i === 9 ? "High" : "Low"
}));

const DATA = {
  hasData: true,
  activeBookings: 19,
  canceledBookings: 3,
  totalBookings: 22,
  cancellationPercent: 14,
  peakHourLabel: "5 PM - 6 PM",
  peakDayLabel: "Thursday",
  quietTimes: ["9 AM - 10 AM", "10 AM - 11 AM"],
  hours,
  days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((label, i) => ({
    day: i + 1,
    label,
    bookings: i === 3 ? 8 : 2,
    percent: i === 3 ? 100 : 25,
    level: i === 3 ? "High" : "Low"
  })),
  rooms: [
    {
      roomId: "r1",
      name: "Room A",
      roomType: "Shared",
      capacity: 6,
      bookings: 12,
      bookedHours: 20,
      sharePercent: 63,
      level: "High"
    },
    {
      roomId: "r2",
      name: "Quiet Pod",
      roomType: "Private",
      capacity: 1,
      bookings: 7,
      bookedHours: 9,
      sharePercent: 37,
      level: "Medium"
    }
  ],
  topSeats: [{ roomId: "r1", roomName: "Room A", seatNo: 2, bookings: 5 }],
  suggestions: ["Demand peaks at 5 PM - 6 PM.", "Add another private room."],
  generatedAt: "2026-11-03T10:00:00.000Z"
};

function mount() {
  const element = createElement("c-library-librarian-room-insights", {
    is: LibraryLibrarianRoomInsights
  });
  document.body.appendChild(element);
  return element;
}

describe("c-library-librarian-room-insights", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("shows peak times, busiest rooms, seats and suggestions", async () => {
    getRoomInsights.mockResolvedValue(DATA);
    const element = mount();
    await flush();
    const text = element.shadowRoot.textContent;
    expect(text).toContain("5 PM - 6 PM");
    expect(text).toContain("Thursday");
    expect(text).toContain("14%");
    expect(text).toContain("Room A");
    expect(text).toContain("Quiet Pod");
    expect(text).toContain("Private");
    expect(text).toContain("Room A · Seat 2");
    expect(text).toContain("Add another private room.");
    expect(text).toContain("Quietest: 9 AM - 10 AM, 10 AM - 11 AM");
    expect(element.shadowRoot.querySelectorAll(".chart .col")).toHaveLength(21);
  });

  it("explains when there is no booking history yet", async () => {
    getRoomInsights.mockResolvedValue({
      hasData: false,
      suggestions: ["No room bookings yet. Insights will appear."]
    });
    const element = mount();
    await flush();
    expect(element.shadowRoot.textContent).toContain("No room bookings yet");
    expect(element.shadowRoot.querySelector(".cards")).toBeNull();
  });

  it("shows the error when loading fails", async () => {
    getRoomInsights.mockRejectedValue({ body: { message: "No access." } });
    const element = mount();
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "No access."
    );
  });
});
