import { LightningElement } from "lwc";
import getPaymentReconciliationExceptions from "@salesforce/apex/LibraryLibrarianController.getPaymentReconciliationExceptions";
import reconcileMembershipPayment from "@salesforce/apex/LibraryLibrarianController.reconcileMembershipPayment";
import createPaymentReceipt from "@salesforce/apex/LibraryLibrarianController.createPaymentReceipt";
import getPaymentGatewayConfigurationStatus from "@salesforce/apex/LibraryLibrarianController.getPaymentGatewayConfigurationStatus";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryPaymentOperations extends LightningElement {
  rows = [];
  gateway = {
    ready: false,
    enabled: false,
    providerName: "Not configured",
    currencyCode: "INR",
    checkoutCredentialConfigured: false,
    webhookConfigured: false,
    message: "Payment gateway configuration has not been checked."
  };
  loading = false;
  error;

  connectedCallback() {
    this.refresh();
  }

  get hasRows() {
    return (this.rows || []).length > 0;
  }

  get gatewayStatusClass() {
    return this.gateway.ready ? "gateway-status ready" : "gateway-status";
  }

  get gatewayStatusLabel() {
    return this.gateway.ready ? "Ready" : "Action required";
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      const [exceptions, gateway] = await Promise.all([
        getPaymentReconciliationExceptions(),
        getPaymentGatewayConfigurationStatus()
      ]);
      this.rows = (exceptions || []).map((row) => ({
        ...row,
        reason: "",
        disabled: false
      }));
      this.gateway = gateway || this.gateway;
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load reconciliation exceptions.";
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }

  captureReason(event) {
    const id = event.currentTarget.dataset.id;
    this.rows = this.rows.map((row) =>
      row.id === id ? { ...row, reason: event.target.value } : row
    );
  }

  async reconcile(event) {
    const id = event.currentTarget.dataset.id;
    const status = event.currentTarget.dataset.status;
    const row = this.rows.find((item) => item.id === id);
    try {
      await reconcileMembershipPayment({
        paymentId: id,
        status,
        reason: row?.reason
      });
      await this.refresh();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Reconciliation updated",
          message: "The financial decision was recorded and audited.",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not reconcile payment",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }

  async receipt(event) {
    try {
      const result = await createPaymentReceipt({
        paymentId: event.currentTarget.dataset.id
      });
      if (result?.downloadUrl) window.open(result.downloadUrl, "_blank");
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Could not create receipt",
          message: error?.body?.message || error?.message || "Try again.",
          variant: "error"
        })
      );
    }
  }
}
