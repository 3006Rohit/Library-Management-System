import { LightningElement } from "lwc";
import getPreferences from "@salesforce/apex/LibraryMemberSessionController.getMyAccessibilityPreferences";
import savePreferences from "@salesforce/apex/LibraryMemberSessionController.saveMyAccessibilityPreferences";

export default class LibraryMemberAccessibility extends LightningElement {
  sessionToken = "";
  preferredLanguage = "English";
  timezone = "UTC";
  highContrast = false;
  largeText = false;
  reducedMotion = false;
  screenReader = false;
  loading = true;
  saving = false;
  message = "";
  error = "";

  languageOptions = [
    { label: "English", value: "English" },
    { label: "हिन्दी (Hindi)", value: "Hindi" },
    { label: "Other", value: "Other" }
  ];

  connectedCallback() {
    this.sessionToken =
      window.sessionStorage.getItem("libraryMemberSession") || "";
    this.load();
  }

  get saveLabel() {
    return this.saving ? "Saving…" : "Save preferences";
  }

  get saveDisabled() {
    return this.saving || this.loading;
  }

  async load() {
    this.loading = true;
    this.error = "";
    try {
      const result = await getPreferences({ sessionToken: this.sessionToken });
      this.apply(result || {});
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.loading = false;
    }
  }

  apply(value) {
    this.preferredLanguage = value.preferredLanguage || "English";
    this.timezone = value.timezone || "UTC";
    this.highContrast = value.highContrast === true;
    this.largeText = value.largeText === true;
    this.reducedMotion = value.reducedMotion === true;
    this.screenReader = value.screenReader === true;
    this.applyAccessibilityClasses();
  }

  handleInput(event) {
    const target = event.currentTarget || event.target;
    const field = target.dataset.field;
    if (target.type === "checkbox") {
      this[field] = target.checked;
    } else {
      this[field] = event.detail?.value || target.value;
    }
    this.applyAccessibilityClasses();
  }

  async save() {
    this.saving = true;
    this.message = "";
    this.error = "";
    try {
      const result = await savePreferences({
        sessionToken: this.sessionToken,
        preferredLanguage: this.preferredLanguage,
        timezone: this.timezone,
        highContrast: this.highContrast,
        largeText: this.largeText,
        reducedMotion: this.reducedMotion,
        screenReader: this.screenReader
      });
      this.apply(result || {});
      this.message = "Accessibility preferences saved.";
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.saving = false;
    }
  }

  applyAccessibilityClasses() {
    if (typeof document !== "undefined" && document.documentElement) {
      document.documentElement.classList.toggle(
        "library-high-contrast",
        this.highContrast
      );
      document.documentElement.classList.toggle(
        "library-large-text",
        this.largeText
      );
      document.documentElement.classList.toggle(
        "library-reduced-motion",
        this.reducedMotion
      );
    }
    this.dispatchEvent(
      new CustomEvent("accessibilitychange", {
        bubbles: true,
        composed: true,
        detail: {
          highContrast: this.highContrast,
          largeText: this.largeText,
          reducedMotion: this.reducedMotion
        }
      })
    );
  }

  errorMessage(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "Unable to load accessibility preferences."
    );
  }
}
