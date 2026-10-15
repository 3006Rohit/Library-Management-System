import { LightningElement } from "lwc";
import authHero from "@salesforce/resourceUrl/LibraryAuthHero";

export default class LibraryAuthHero extends LightningElement {
  get heroStyle() {
    return `background-image: url("${authHero}")`;
  }
}
