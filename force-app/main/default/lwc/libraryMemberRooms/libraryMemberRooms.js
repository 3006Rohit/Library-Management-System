import { LightningElement } from "lwc";
import getLibraryRooms from "@salesforce/apex/LibraryMemberSessionController.getLibraryRooms";
import getLibraryRoomSeats from "@salesforce/apex/LibraryMemberSessionController.getLibraryRoomSeats";
import bookLibraryRoom from "@salesforce/apex/LibraryMemberSessionController.bookLibraryRoom";
import getMyRoomBookings from "@salesforce/apex/LibraryMemberSessionController.getMyRoomBookings";
import cancelLibraryRoomBooking from "@salesforce/apex/LibraryMemberSessionController.cancelLibraryRoomBooking";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const pad = (value) => String(value).padStart(2, "0");

// datetime-local inputs use local "YYYY-MM-DDTHH:mm" values, not ISO/UTC.
const toLocalInput = (date) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;

export default class LibraryMemberRooms extends LightningElement {
  rooms = [];
  bookings = [];
  seats = [];
  selectedRoom;
  selectedSeat;
  startAt = this.localHoursFromNow(24);
  endAt = this.localHoursFromNow(26);
  minimumCapacity = 1;
  purpose = "";
  loading = false;
  loadingSeats = false;
  booking = false;
  error;
  sessionToken = sessionStorage.getItem("libraryMemberSession");

  connectedCallback() {
    this.refreshBookings();
    this.search();
  }

  localHoursFromNow(hours) {
    const date = new Date(Date.now() + hours * 60 * 60 * 1000);
    date.setMinutes(0, 0, 0);
    return toLocalInput(date);
  }

  get startIso() {
    return new Date(this.startAt).toISOString();
  }

  get endIso() {
    return new Date(this.endAt).toISOString();
  }

  handleInput(event) {
    this[event.target.name] = event.target.value;
    if (event.target.name === "startAt" || event.target.name === "endAt") {
      this.clearSelection();
    }
  }

  clearSelection() {
    this.selectedRoom = undefined;
    this.selectedSeat = undefined;
    this.seats = [];
  }

  async search() {
    this.error = undefined;
    if (
      !this.startAt ||
      !this.endAt ||
      new Date(this.endAt) <= new Date(this.startAt)
    ) {
      this.error = "Choose an end time after the start time.";
      return;
    }
    this.loading = true;
    this.clearSelection();
    try {
      const rows =
        (await getLibraryRooms({
          sessionToken: this.sessionToken,
          startAt: this.startIso,
          endAt: this.endIso,
          minimumCapacity: Number(this.minimumCapacity) || 1
        })) || [];
      this.rooms = rows.map((room) => ({
        ...room,
        seatSummary: `${room.availableSeats} of ${room.capacity} seats free`,
        details: [room.location, room.equipment].filter(Boolean).join(" · "),
        disabled: room.available === false
      }));
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load rooms.";
    } finally {
      this.loading = false;
    }
  }

  async chooseRoom(event) {
    await this.loadSeats(event.currentTarget.dataset.id);
  }

  async loadSeats(roomId) {
    const room = this.rooms.find((row) => row.id === roomId);
    if (!room) return;
    this.selectedRoom = room;
    this.selectedSeat = undefined;
    this.loadingSeats = true;
    try {
      this.seats = await getLibraryRoomSeats({
        sessionToken: this.sessionToken,
        roomId: room.id,
        startAt: this.startIso,
        endAt: this.endIso
      });
    } catch (error) {
      this.seats = [];
      this.error =
        error?.body?.message || error?.message || "Unable to load seats.";
    } finally {
      this.loadingSeats = false;
    }
  }

  chooseSeat(event) {
    this.selectedSeat = Number(event.currentTarget.dataset.number);
  }

  get seatItems() {
    return this.seats.map((seat) => {
      const selected = seat.seatNo === this.selectedSeat;
      let className = "seat free";
      if (seat.taken) className = "seat taken";
      else if (selected) className = "seat selected";
      return {
        seatNo: seat.seatNo,
        taken: seat.taken,
        label: `Seat ${seat.seatNo}, ${seat.taken ? "taken" : "free"}`,
        className,
        pressed: String(selected)
      };
    });
  }

  get hasRooms() {
    return this.rooms.length > 0;
  }

  get hasBookings() {
    return this.bookings.length > 0;
  }

  get reserveDisabled() {
    return !this.selectedSeat || this.booking;
  }

  get reserveLabel() {
    return this.selectedSeat
      ? `Reserve seat ${this.selectedSeat}`
      : "Select a seat";
  }

  async refreshBookings() {
    try {
      const rows =
        (await getMyRoomBookings({ sessionToken: this.sessionToken })) || [];
      this.bookings = rows.map((row) => ({
        ...row,
        when: `${this.format(row.startAt)} – ${this.format(row.endAt)}`
      }));
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load bookings.";
    }
  }

  format(value) {
    return value
      ? new Date(value).toLocaleString(undefined, {
          month: "short",
          day: "numeric",
          hour: "numeric",
          minute: "2-digit"
        })
      : "";
  }

  async reserve() {
    if (!this.selectedRoom || !this.selectedSeat) return;
    const roomId = this.selectedRoom.id;
    this.booking = true;
    try {
      await bookLibraryRoom({
        sessionToken: this.sessionToken,
        roomId,
        seatNumber: this.selectedSeat,
        startAt: this.startIso,
        endAt: this.endIso,
        purpose: this.purpose
      });
      this.toast("Seat reserved", "Your seat was saved.", "success");
      await Promise.all([this.search(), this.refreshBookings()]);
    } catch (error) {
      this.toast(
        "Could not reserve seat",
        error?.body?.message || error?.message || "Try another seat or time.",
        "error"
      );
      await this.loadSeats(roomId);
    } finally {
      this.booking = false;
    }
  }

  async cancel(event) {
    try {
      await cancelLibraryRoomBooking({
        sessionToken: this.sessionToken,
        bookingId: event.currentTarget.dataset.id
      });
      await Promise.all([this.search(), this.refreshBookings()]);
      this.toast("Booking canceled", "The seat is available again.", "success");
    } catch (error) {
      this.toast(
        "Could not cancel booking",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
