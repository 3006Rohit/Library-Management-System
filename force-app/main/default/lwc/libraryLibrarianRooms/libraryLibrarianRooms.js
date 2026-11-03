import { LightningElement } from "lwc";
import createLibraryRoom from "@salesforce/apex/LibraryLibrarianController.createLibraryRoom";
import getLibraryRoomsForLibrarian from "@salesforce/apex/LibraryLibrarianController.getLibraryRoomsForLibrarian";
import retireLibraryRoom from "@salesforce/apex/LibraryLibrarianController.retireLibraryRoom";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryLibrarianRooms extends LightningElement {
  rooms = [];
  name = "";
  location = "";
  seats = 6;
  roomType = "Shared";
  equipment = "";
  loading = false;
  saving = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  get hasRooms() {
    return this.rooms.length > 0;
  }

  get totalSeats() {
    return this.rooms.reduce((sum, room) => sum + (room.capacity || 0), 0);
  }

  get privateCount() {
    return this.rooms.filter((room) => room.isPrivate).length;
  }

  get summary() {
    const privateText = this.privateCount
      ? ` · ${this.privateCount} private`
      : "";
    return `${this.rooms.length} rooms · ${this.totalSeats} seats${privateText}`;
  }

  get isPrivateType() {
    return this.roomType === "Private";
  }

  get isSharedType() {
    return !this.isPrivateType;
  }

  get sharedTypeClass() {
    return this.isSharedType ? "type active" : "type";
  }

  get privateTypeClass() {
    return this.isPrivateType ? "type active" : "type";
  }

  get saveDisabled() {
    return this.saving;
  }

  get roomRows() {
    return this.rooms.map((room) => ({
      ...room,
      typeLabel: room.isPrivate ? "Private · 1 seat" : `${room.capacity} seats`,
      details: [room.location, room.equipment].filter(Boolean).join(" · ")
    }));
  }

  chooseType(event) {
    this.roomType = event.currentTarget.dataset.type;
  }

  handleInput(event) {
    this[event.target.name] = event.target.value;
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.rooms = (await getLibraryRoomsForLibrarian()) || [];
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load rooms.";
    } finally {
      this.loading = false;
    }
  }

  async addRoom(event) {
    event.preventDefault();
    const seats = this.isPrivateType ? 1 : Number(this.seats);
    if (!this.name.trim() || !Number.isInteger(seats) || seats < 1) {
      this.toast(
        "Check the form",
        "Enter a room name and a whole number of seats (at least 1).",
        "error"
      );
      return;
    }
    this.saving = true;
    try {
      await createLibraryRoom({
        name: this.name,
        location: this.location,
        capacity: seats,
        equipment: this.equipment,
        roomType: this.roomType
      });
      this.name = "";
      this.location = "";
      this.equipment = "";
      this.toast(
        "Room added",
        this.isPrivateType
          ? "The private room is now bookable."
          : `${seats} seats are now bookable.`,
        "success"
      );
      await this.refresh();
    } catch (error) {
      this.toast(
        "Could not add room",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    } finally {
      this.saving = false;
    }
  }

  async retire(event) {
    const roomId = event.currentTarget.dataset.id;
    const name = event.currentTarget.dataset.name;
    // eslint-disable-next-line no-alert, no-restricted-globals
    const confirmed = confirm(
      `Remove ${name}? Its upcoming seat reservations will be canceled.`
    );
    if (!confirmed) {
      return;
    }
    try {
      await retireLibraryRoom({ roomId });
      this.toast("Room removed", `${name} is no longer bookable.`, "success");
      await this.refresh();
    } catch (error) {
      this.toast(
        "Could not remove room",
        error?.body?.message || error?.message || "Try again.",
        "error"
      );
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
