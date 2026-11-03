import { LightningElement } from "lwc";
import getRoomInsights from "@salesforce/apex/LibraryLibrarianController.getRoomInsights";

export default class LibraryLibrarianRoomInsights extends LightningElement {
  insights;
  loading = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      this.insights = await getRoomInsights();
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load room insights.";
    } finally {
      this.loading = false;
    }
  }

  get hasData() {
    return Boolean(this.insights?.hasData);
  }

  get showEmpty() {
    return Boolean(this.insights) && !this.hasData && !this.error;
  }

  get summaryCards() {
    const i = this.insights || {};
    return [
      { label: "Peak hour", value: i.peakHourLabel || "—", icon: "◷" },
      { label: "Busiest day", value: i.peakDayLabel || "—", icon: "▦" },
      { label: "Bookings", value: i.activeBookings ?? 0, icon: "✓" },
      {
        label: "Canceled",
        value: `${i.cancellationPercent ?? 0}%`,
        icon: "×"
      }
    ];
  }

  get hourBars() {
    return (this.insights?.hours || []).map((bucket) => ({
      key: `h${bucket.hour}`,
      label: bucket.label.replace(" ", ""),
      bookings: bucket.bookings,
      title: `${bucket.label}: ${bucket.bookings} seat-hours (${bucket.level})`,
      barStyle: `height:${Math.max(bucket.percent, bucket.bookings ? 8 : 3)}%`,
      className: `bar level-${String(bucket.level).toLowerCase()}`
    }));
  }

  get dayBars() {
    return (this.insights?.days || []).map((bucket) => ({
      key: `d${bucket.day}`,
      label: bucket.label,
      bookings: bucket.bookings,
      title: `${bucket.label}: ${bucket.bookings} bookings (${bucket.level})`,
      barStyle: `height:${Math.max(bucket.percent, bucket.bookings ? 8 : 3)}%`,
      className: `bar level-${String(bucket.level).toLowerCase()}`
    }));
  }

  get roomRows() {
    return (this.insights?.rooms || []).map((room) => ({
      key: room.roomId,
      name: room.name,
      isPrivate: room.roomType === "Private",
      typeLabel:
        room.roomType === "Private" ? "Private" : `${room.capacity} seats`,
      detail: `${room.bookings} booking${room.bookings === 1 ? "" : "s"} · ${room.bookedHours} seat-hours`,
      share: `${room.sharePercent}%`,
      barStyle: `width:${Math.max(room.sharePercent, room.bookings ? 4 : 0)}%`,
      levelClass: `level-${String(room.level).toLowerCase()}`
    }));
  }

  get hasRooms() {
    return this.roomRows.length > 0;
  }

  get seatRows() {
    return (this.insights?.topSeats || []).map((seat, index) => ({
      key: `${seat.roomId}-${seat.seatNo}`,
      rank: index + 1,
      title: `${seat.roomName} · Seat ${seat.seatNo}`,
      count: `${seat.bookings} booking${seat.bookings === 1 ? "" : "s"}`
    }));
  }

  get hasSeats() {
    return this.seatRows.length > 0;
  }

  get tipRows() {
    return (this.insights?.suggestions || []).map((text, index) => ({
      key: `tip-${index}`,
      number: index + 1,
      text
    }));
  }

  get quietText() {
    const times = this.insights?.quietTimes || [];
    return times.length ? times.join(", ") : "";
  }

  get updatedText() {
    return this.insights?.generatedAt
      ? new Date(this.insights.generatedAt).toLocaleString(undefined, {
          month: "short",
          day: "numeric",
          hour: "numeric",
          minute: "2-digit"
        })
      : "";
  }
}
