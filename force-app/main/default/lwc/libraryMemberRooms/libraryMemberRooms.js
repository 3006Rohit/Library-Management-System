import { LightningElement } from "lwc";
import getLibraryRooms from "@salesforce/apex/LibraryMemberSessionController.getLibraryRooms";
import bookLibraryRoom from "@salesforce/apex/LibraryMemberSessionController.bookLibraryRoom";
import getMyRoomBookings from "@salesforce/apex/LibraryMemberSessionController.getMyRoomBookings";
import cancelLibraryRoomBooking from "@salesforce/apex/LibraryMemberSessionController.cancelLibraryRoomBooking";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberRooms extends LightningElement {
  rooms = [];
  bookings = [];
  startAt = this.isoHoursFromNow(24);
  endAt = this.isoHoursFromNow(26);
  minimumCapacity = 1;
  purpose = "";
  loading = false;
  error;
  sessionToken = sessionStorage.getItem("libraryMemberSession");

  connectedCallback() {
    this.refreshBookings();
    this.search();
  }

  isoHoursFromNow(hours) {
    const date = new Date(Date.now() + hours * 60 * 60 * 1000);
    date.setMinutes(0, 0, 0);
    return date.toISOString();
  }

  handleInput(event) {
    this[event.target.name] = event.target.value;
  }

  async search() {
    this.loading = true;
    this.error = undefined;
    try {
      const rows =
        (await getLibraryRooms({
          sessionToken: this.sessionToken,
          startAt: this.startAt,
          endAt: this.endAt,
          minimumCapacity: Number(this.minimumCapacity)
        })) || [];
      this.rooms = rows.map((room) => ({
        ...room,
        disabled: room.available === false
      }));
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load rooms.";
    } finally {
      this.loading = false;
    }
  }

  async refreshBookings() {
    try {
      this.bookings =
        (await getMyRoomBookings({ sessionToken: this.sessionToken })) || [];
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load bookings.";
    }
  }

  get hasBookings() {
    return this.bookings.length > 0;
  }

  async book(event) {
    const roomId = event.currentTarget.dataset.id;
    try {
      await bookLibraryRoom({
        sessionToken: this.sessionToken,
        roomId,
        startAt: this.startAt,
        endAt: this.endAt,
        purpose: this.purpose
      });
      this.toast("Room booked", "Your booking was saved.", "success");
      await Promise.all([this.search(), this.refreshBookings()]);
    } catch (error) {
      this.toast(
        "Could not book room",
        error?.body?.message || error?.message || "Try another time.",
        "error"
      );
    }
  }

  async cancel(event) {
    try {
      await cancelLibraryRoomBooking({
        sessionToken: this.sessionToken,
        bookingId: event.currentTarget.dataset.id
      });
      await this.refreshBookings();
      this.toast("Booking canceled", "The room is available again.", "success");
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
