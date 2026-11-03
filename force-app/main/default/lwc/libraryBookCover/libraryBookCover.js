import { LightningElement, api } from "lwc";

const PALETTE = [
  "#2f4b7c",
  "#a4483a",
  "#3d6b57",
  "#6d5a8a",
  "#8a5a2b",
  "#2b6777",
  "#7a3b57",
  "#475569"
];

function hash(value) {
  let total = 0;
  for (let i = 0; i < value.length; i += 1) {
    total = (total * 31 + value.charCodeAt(i)) % 100003;
  }
  return total;
}

export default class LibraryBookCover extends LightningElement {
  @api title = "";
  @api author = "";
  @api coverUrl = "";
  @api size = "card";

  get hasCover() {
    return Boolean(this.coverUrl);
  }

  get wrapperClass() {
    if (this.size === "large") return "cover large";
    if (this.size === "thumb") return "cover thumb";
    return "cover";
  }

  get initial() {
    return (this.title || "?").trim().charAt(0).toUpperCase();
  }

  get showAuthor() {
    return Boolean(this.author) && this.author !== "Author unavailable";
  }

  get displayTitle() {
    const value = this.title || "Untitled";
    return value.length > 64 ? `${value.slice(0, 61)}…` : value;
  }

  get placeholderStyle() {
    const color = PALETTE[hash(this.title || "") % PALETTE.length];
    return `background-color:${color}`;
  }
}
