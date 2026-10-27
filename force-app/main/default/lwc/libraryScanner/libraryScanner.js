import { LightningElement } from "lwc";
import lookupScannedCopy from "@salesforce/apex/LibraryMemberSessionController.lookupScannedCopy";
import scanSelfCheckout from "@salesforce/apex/LibraryMemberSessionController.scanSelfCheckout";
import scanReturn from "@salesforce/apex/LibraryMemberSessionController.scanReturn";

export default class LibraryScanner extends LightningElement {
  barcode = "";
  mode = "Checkout";
  preview;
  message = "";
  success = false;
  busy = false;
  cameraActive = false;
  cameraMessage = "Point the camera at a book barcode.";
  mediaStream;
  detector;
  scanTimer;

  get sessionToken() {
    return sessionStorage.getItem("libraryMemberSession");
  }

  get hasPreview() {
    return Boolean(this.preview?.success);
  }

  get hasMessage() {
    return Boolean(this.message);
  }

  get messageClass() {
    return this.success ? "scan-message success" : "scan-message error";
  }

  get cameraButtonLabel() {
    return this.cameraActive ? "Stop camera" : "Use camera";
  }

  get isReturnMode() {
    return this.mode === "Return";
  }

  get checkoutModeClass() {
    return this.mode === "Checkout" ? "mode-button active" : "mode-button";
  }

  get returnModeClass() {
    return this.isReturnMode ? "mode-button active" : "mode-button";
  }

  get confirmLabel() {
    return this.isReturnMode ? "Confirm return" : "Confirm checkout";
  }

  changeMode(event) {
    this.mode = event.currentTarget.dataset.mode;
    this.preview = undefined;
    this.message = "";
  }

  handleBarcodeChange(event) {
    this.barcode = event.detail?.value || event.target.value || "";
    this.preview = undefined;
    this.message = "";
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.previewCopy();
    }
  }

  previewCopy() {
    const value = this.barcode.trim();
    if (!value) {
      this.showMessage("Enter or scan a barcode first.", false);
      return;
    }
    this.busy = true;
    lookupScannedCopy({ sessionToken: this.sessionToken, barcode: value })
      .then((result) => {
        this.preview = result;
        this.showMessage(
          result?.message || "Copy preview loaded.",
          Boolean(result?.success)
        );
      })
      .catch((error) => this.showMessage(this.errorMessage(error), false))
      .finally(() => {
        this.busy = false;
      });
  }

  confirmCheckout() {
    if (!this.barcode.trim()) return;
    this.busy = true;
    this.message = "";
    const operation = this.isReturnMode ? scanReturn : scanSelfCheckout;
    operation({
      sessionToken: this.sessionToken,
      barcode: this.barcode.trim(),
      idempotencyKey: this.transactionKey()
    })
      .then((result) => {
        this.preview = undefined;
        this.showMessage(
          result?.message || "Checkout processed.",
          Boolean(result?.success)
        );
        if (result?.success) this.barcode = "";
      })
      .catch((error) => this.showMessage(this.errorMessage(error), false))
      .finally(() => {
        this.busy = false;
      });
  }

  transactionKey() {
    if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
    return `scan-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  }

  async toggleCamera() {
    if (this.cameraActive) {
      this.stopCamera();
      return;
    }
    if (
      !globalThis.navigator?.mediaDevices?.getUserMedia ||
      !globalThis.BarcodeDetector
    ) {
      this.showMessage(
        "Camera scanning is not available here. Enter the barcode manually.",
        false
      );
      return;
    }
    try {
      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" }
      });
      this.cameraActive = true;
      this.detector = new BarcodeDetector();
      this.cameraMessage = "Point the camera at a book barcode.";
      await Promise.resolve();
      const video = this.template.querySelector("video");
      video.srcObject = this.mediaStream;
      await video.play();
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this.scanTimer = window.setInterval(() => this.detectFrame(), 400);
    } catch {
      this.stopCamera();
      this.showMessage(
        "Camera permission was not granted. Enter the barcode manually.",
        false
      );
    }
  }

  async detectFrame() {
    const video = this.template.querySelector("video");
    if (!video || !this.detector || video.readyState < 2) return;
    try {
      const codes = await this.detector.detect(video);
      if (codes?.[0]?.rawValue) {
        this.barcode = codes[0].rawValue;
        this.stopCamera();
        this.previewCopy();
      }
    } catch {
      this.cameraMessage = "Hold the barcode steady and try again.";
    }
  }

  stopCamera() {
    if (this.scanTimer) window.clearInterval(this.scanTimer);
    this.scanTimer = undefined;
    this.mediaStream?.getTracks?.().forEach((track) => track.stop());
    this.mediaStream = undefined;
    this.cameraActive = false;
    this.detector = undefined;
  }

  disconnectedCallback() {
    this.stopCamera();
  }

  showMessage(message, success) {
    this.message = message;
    this.success = success;
  }

  errorMessage(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "The scan could not be completed."
    );
  }
}
