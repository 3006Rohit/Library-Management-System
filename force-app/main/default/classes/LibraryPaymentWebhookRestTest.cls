@IsTest
private class LibraryPaymentWebhookRestTest {
  @IsTest
  static void malformedWebhookReturnsBadRequest() {
    RestRequest request = new RestRequest();
    request.requestUri = '/services/apexrest/library/payments/webhook';
    request.httpMethod = 'POST';
    request.requestBody = Blob.valueOf('{"id":"evt-1"}');
    request.addHeader('X-Library-Payment-Signature', 'bad');
    RestResponse response = new RestResponse();
    RestContext.request = request;
    RestContext.response = response;
    Test.startTest();
    LibraryPaymentWebhookRest.receive();
    Test.stopTest();
    System.assertEquals(400, response.statusCode);
  }
}
