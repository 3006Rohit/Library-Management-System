# Events, rooms & library calendar

## Events — `LibraryEventService`

- Librarian (catalog permission) `create(title, schedule, location, capacity)`.
- Members: `getUpcoming`, `register` (one per event; **waitlist** when full), `cancel`.
- The event ledger row is **locked** before every capacity decision. Cancelling a registered member promotes the earliest waitlisted member.
- Check-in: `issueCheckInToken` (short-lived, hashed, raw never stored) → librarian `checkIn(eventId, token)` → registration becomes **Attended**.
- UI: `libraryMemberEvents`. Public assistant reads events via `LibraryPublicEventsAction`.

## Rooms — `LibraryRoomBookingService`

- Librarians: `createRoom` (location, capacity, equipment, type), `listRooms`, `retireRoom` (UI `libraryLibrarianRooms`).
- Members: `getRooms(filter, minCapacity)`, `getAvailability`, `getSeats`, `book(window, purpose)`, `getMyBookings`, `cancel` own only (UI `libraryMemberRooms`).
- Rules: future windows only, max **8 hours**, **overlap prevention** after locking the room row, capacity filter.
- Librarian oversight: `LibraryLibrarianSessionController.getAllRoomBookings` / `cancelRoomBookingAsLibrarian` (`libraryLibrarianRoomBookings`).
- Insights/forecast: `LibraryRoomInsightService.getInsights/getAgentInsights/getForecast` → `libraryLibrarianRoomInsights`, member demand forecast, and agent actions `LibraryAgentRoom*Action` ("when is the library busy?").

## Closures & due dates — `LibraryCalendarService`

`createClosure(range, branch?, timezone, planned|emergency)` (idempotent per branch + range), `getClosures`, `calculateDueDate(start, days, branch)` and `nextOpenDate`. Circulation uses it so a due date landing in a closure moves to the next open day; **existing loans are not rewritten**. UI: `libraryLibrarianClosures`.

## No-show processing

Librarian dashboard action: delegates expired Ready reservations to circulation (with queue promotion), marks finished room bookings and past registered events as `No-show`, writes a count row to the ledger, and never changes Attended/Cancelled/Waitlisted/already-processed records.

## Tests

`LibraryEventServiceTest`, `LibraryRoomBookingServiceTest`, `LibraryRoomInsightServiceTest`, `LibraryCalendarServiceTest`, `LibraryAgentRoomActionsTest`; Jest `libraryMemberEvents`, `libraryMemberRooms`, `libraryLibrarianRoomInsights`.
