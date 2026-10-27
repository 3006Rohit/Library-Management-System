@RestResource(urlMapping='/library/payments/webhook')
global without sharing class LibraryPaymentWebhookRest {
  @HttpPost
  global static void receive() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    String signature = request.headers.get('X-Library-Payment-Signature');
    try {
      LibraryPaymentGatewayService.processWebhook(
        request.requestBody == null ? null : request.requestBody.toString(),
        signature
      );
      response.statusCode = 200;
      response.responseBody = Blob.valueOf('{"accepted":true}');
    } catch (AuraHandledException ex) {
      response.statusCode = 400;
      response.responseBody = Blob.valueOf('{"accepted":false}');
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf('{"accepted":false}');
    }
  }
}
