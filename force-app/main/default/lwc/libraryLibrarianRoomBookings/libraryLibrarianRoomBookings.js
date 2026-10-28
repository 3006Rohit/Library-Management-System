import { LightningElement } from "lwc";
import getAllRoomBookings from "@salesforce/apex/LibraryLibrarianSessionController.getAllRoomBookings";
import cancelRoomBookingAsLibrarian from "@salesforce/apex/LibraryLibrarianSessionController.cancelRoomBookingAsLibrarian";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryLibrarianRoomBookings extends LightningElement {
  bookings = [];
  loading = false;
  error;
  filterBooked = true;
  filterCanceled = false;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.bookings =
        (await getAllRoomBookings()).map((booking) => ({
          ...booking,
          startAtLabel: this.formatDatetime(booking.startAt),
          endAtLabel: this.formatDatetime(booking.endAt),
          statusClass: this.getStatusClass(booking.status),
          canCancel: booking.status === "Booked"
        })) || [];
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load bookings.";
    } finally {
      this.loading = false;
    }
  }

  handleFilterChange(event) {
    const status = event.target.dataset.status;
    if (status === "Booked") {
      this.filterBooked = event.target.checked;
    } else if (status === "Canceled") {
      this.filterCanceled = event.target.checked;
    }
  }

  get filteredBookings() {
    return this.bookings.filter((booking) => {
      if (booking.status === "Booked" && this.filterBooked) return true;
      if (booking.status === "Canceled" && this.filterCanceled) return true;
      return false;
    });
  }

  get hasBookings() {
    return this.filteredBookings.length > 0;
  }

  async handleCancel(event) {
    const bookingId = event.currentTarget.dataset.id;
    if (!confirm("Are you sure you want to cancel this booking?")) {
      return;
    }
    try {
      await cancelRoomBookingAsLibrarian({ bookingId });
      await this.refresh();
      this.toast(
        "Booking canceled",
        "The room booking has been canceled.",
        "success"
      );
    } catch (error) {
      this.toast(
        "Could not cancel booking",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    }
  }

  formatDatetime(datetimeStr) {
    if (!datetimeStr) return "";
    try {
      const date = new Date(datetimeStr);
      return date.toLocaleString("en-US", {
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit"
      });
    } catch {
      return datetimeStr;
    }
  }

  getStatusClass(status) {
    if (status === "Booked") return "status-booked";
    if (status === "Canceled") return "status-canceled";
    return "";
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
