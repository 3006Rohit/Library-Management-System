public without sharing class LibraryScanService {
  public class ScanResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String operation;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Id transactionId;
    @AuraEnabled
    public Id loanId;
    @AuraEnabled
    public String barcode;
    @AuraEnabled
    public String bookTitle;
    @AuraEnabled
    public Datetime dueDate;
  }

  public static ScanResult lookup(String sessionToken, String barcode) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    String normalizedBarcode = normalizeBarcode(barcode);
    if (String.isBlank(normalizedBarcode))
      return failure('Lookup', null, 'Enter a barcode to continue.');
    List<Book_Copy__c> copies = [
      SELECT Id, Barcode__c, Status__c, Book__r.Name
      FROM Book_Copy__c
      WHERE Barcode__c = :normalizedBarcode
      LIMIT 1
    ];
    if (copies.isEmpty())
      return failure('Lookup', null, 'That barcode was not found.');
    ScanResult result = new ScanResult();
    result.success = true;
    result.operation = 'Lookup';
    result.status = copies[0].Status__c;
    result.message = copies[0].Status__c == 'Available'
      ? 'Copy is available for checkout.'
      : 'Copy is currently ' + copies[0].Status__c + '.';
    result.barcode = copies[0].Barcode__c;
    result.bookTitle = copies[0].Book__r == null
      ? null
      : copies[0].Book__r.Name;
    return result;
  }

  public static ScanResult selfCheckout(
    String sessionToken,
    String barcode,
    String idempotencyKey
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String normalizedBarcode = normalizeBarcode(barcode);
    String normalizedKey = normalizeKey(idempotencyKey);
    if (String.isBlank(normalizedBarcode))
      return failure('Self Checkout', null, 'Enter a barcode to continue.');
    if (String.isBlank(normalizedKey))
      return failure(
        'Self Checkout',
        null,
        'A scan transaction key is required.'
      );
    Library_Scan_Transaction__c existing = findTransaction(
      normalizedKey,
      member.Id
    );
    if (existing != null)
      return fromTransaction(existing);
    Library_Scan_Transaction__c scan = begin(
      normalizedKey,
      'Self Checkout',
      member.Id
    );
    if (scan == null)
      return fromTransaction(findTransaction(normalizedKey, member.Id));
    try {
      Book_Copy__c copy = findCopy(normalizedBarcode);
      if (copy == null)
        return completeFailure(scan, 'That barcode was not found.');
      scan.Book_Copy__c = copy.Id;
      update scan;
      Id loanId = LibraryMemberBorrowService.checkout(member, copy.Id);
      Borrow_Record__c loan = [
        SELECT Id, Due_Date__c
        FROM Borrow_Record__c
        WHERE Id = :loanId
        LIMIT 1
      ];
      scan.Borrow_Record__c = loan.Id;
      scan.Status__c = 'Completed';
      scan.Result_Message__c = 'Checkout completed.';
      update scan;
      return success(
        'Self Checkout',
        scan,
        loan.Id,
        copy,
        loan.Due_Date__c,
        'Checkout completed.'
      );
    } catch (Exception error) {
      return completeFailure(scan, safeMessage(error));
    }
  }

  public static ScanResult returnItem(
    String sessionToken,
    String barcode,
    String idempotencyKey
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String normalizedBarcode = normalizeBarcode(barcode);
    String normalizedKey = normalizeKey(idempotencyKey);
    if (String.isBlank(normalizedBarcode))
      return failure('Return', null, 'Enter a barcode to continue.');
    if (String.isBlank(normalizedKey))
      return failure('Return', null, 'A scan transaction key is required.');
    Library_Scan_Transaction__c existing = findTransaction(
      normalizedKey,
      member.Id
    );
    if (existing != null)
      return fromTransaction(existing);
    Library_Scan_Transaction__c scan = begin(
      normalizedKey,
      'Return',
      member.Id
    );
    if (scan == null)
      return fromTransaction(findTransaction(normalizedKey, member.Id));
    try {
      List<Borrow_Record__c> loans = [
        SELECT
          Id,
          Book_Copy__c,
          Due_Date__c,
          Book_Copy__r.Barcode__c,
          Book_Copy__r.Book__r.Name
        FROM Borrow_Record__c
        WHERE
          Member__c = :member.Id
          AND Return_Date__c = NULL
          AND Book_Copy__r.Barcode__c = :normalizedBarcode
        ORDER BY Borrow_Date__c DESC
        LIMIT 1
      ];
      if (loans.isEmpty())
        return completeFailure(
          scan,
          'No active loan for this member matches that barcode.'
        );
      Borrow_Record__c loan = loans[0];
      scan.Book_Copy__c = loan.Book_Copy__c;
      scan.Borrow_Record__c = loan.Id;
      update scan;
      LibraryCirculationService.returnLoanForMember(loan.Id, member.Id);
      scan.Status__c = 'Completed';
      scan.Result_Message__c = 'Return completed.';
      update scan;
      ScanResult result = new ScanResult();
      result.success = true;
      result.operation = 'Return';
      result.status = 'Completed';
      result.message = 'Return completed.';
      result.transactionId = scan.Id;
      result.loanId = loan.Id;
      result.barcode = loan.Book_Copy__r.Barcode__c;
      result.bookTitle = loan.Book_Copy__r.Book__r == null
        ? null
        : loan.Book_Copy__r.Book__r.Name;
      return result;
    } catch (Exception error) {
      return completeFailure(scan, safeMessage(error));
    }
  }

  private static Book_Copy__c findCopy(String barcode) {
    List<Book_Copy__c> copies = [
      SELECT Id, Barcode__c, Status__c, Book__r.Name
      FROM Book_Copy__c
      WHERE Barcode__c = :barcode
      LIMIT 1
    ];
    return copies.isEmpty() ? null : copies[0];
  }

  private static Library_Scan_Transaction__c begin(
    String key,
    String operation,
    Id memberId
  ) {
    Library_Scan_Transaction__c scan = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = operation,
      Member__c = memberId,
      Status__c = 'Processing',
      Created_At__c = System.now()
    );
    try {
      Database.insert(scan, AccessLevel.SYSTEM_MODE);
      return scan;
    } catch (DmlException error) {
      return null;
    }
  }

  private static Library_Scan_Transaction__c findTransaction(
    String key,
    Id memberId
  ) {
    if (String.isBlank(key) || memberId == null)
      return null;
    List<Library_Scan_Transaction__c> rows = [
      SELECT
        Id,
        Idempotency_Key__c,
        Operation__c,
        Status__c,
        Result_Message__c,
        Book_Copy__r.Barcode__c,
        Book_Copy__r.Book__r.Name,
        Borrow_Record__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :memberId
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static ScanResult fromTransaction(Library_Scan_Transaction__c scan) {
    if (scan == null)
      return failure('Scan', null, 'The scan transaction could not be found.');
    ScanResult result = new ScanResult();
    result.success = scan.Status__c == 'Completed';
    result.operation = scan.Operation__c;
    result.status = scan.Status__c;
    result.message = scan.Result_Message__c == null
      ? 'This scan is already being processed.'
      : scan.Result_Message__c;
    result.transactionId = scan.Id;
    result.loanId = scan.Borrow_Record__c;
    result.barcode = scan.Book_Copy__r == null
      ? null
      : scan.Book_Copy__r.Barcode__c;
    result.bookTitle = scan.Book_Copy__r == null ||
      scan.Book_Copy__r.Book__r == null
      ? null
      : scan.Book_Copy__r.Book__r.Name;
    return result;
  }

  private static ScanResult completeFailure(
    Library_Scan_Transaction__c scan,
    String message
  ) {
    scan.Status__c = 'Failed';
    scan.Result_Message__c = message;
    update scan;
    ScanResult result = fromTransaction(scan);
    result.success = false;
    return result;
  }

  private static ScanResult success(
    String operation,
    Library_Scan_Transaction__c scan,
    Id loanId,
    Book_Copy__c copy,
    Datetime dueDate,
    String message
  ) {
    ScanResult result = new ScanResult();
    result.success = true;
    result.operation = operation;
    result.status = 'Completed';
    result.message = message;
    result.transactionId = scan.Id;
    result.loanId = loanId;
    result.barcode = copy.Barcode__c;
    result.bookTitle = copy.Book__r == null ? null : copy.Book__r.Name;
    result.dueDate = dueDate;
    return result;
  }

  private static ScanResult failure(
    String operation,
    Id transactionId,
    String message
  ) {
    ScanResult result = new ScanResult();
    result.success = false;
    result.operation = operation;
    result.status = 'Failed';
    result.message = message;
    result.transactionId = transactionId;
    return result;
  }

  private static String normalizeBarcode(String barcode) {
    return String.isBlank(barcode) ? null : barcode.trim();
  }

  private static String normalizeKey(String key) {
    if (String.isBlank(key))
      return null;
    String value = key.trim();
    return value.length() > 100 ? value.substring(0, 100) : value;
  }

  private static String safeMessage(Exception error) {
    String message = error == null ? null : error.getMessage();
    return String.isBlank(message)
      ? 'The scan could not be completed. Please try again.'
      : message;
  }
}
