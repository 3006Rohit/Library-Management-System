public without sharing class LibraryCatalogImportService {
  private static final String OPERATION = 'Catalog Import';
  private static final Integer MAX_ROWS = 200;

  public class RowDTO {
    @AuraEnabled
    public Integer rowNumber;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String isbn;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String error;
  }
  public class ImportDTO {
    @AuraEnabled
    public String importKey;
    @AuraEnabled
    public Integer created;
    @AuraEnabled
    public Integer rejected;
    @AuraEnabled
    public Id auditId;
  }
  private class ParsedRow {
    Integer rowNumber;
    Map<String, String> values;
    RowDTO dto;
  }

  public static List<RowDTO> preview(String csvText) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    List<ParsedRow> rows = parseRows(csvText);
    List<RowDTO> result = new List<RowDTO>();
    Set<String> isbns = new Set<String>();
    for (ParsedRow row : rows) {
      validate(row, isbns);
      result.add(row.dto);
      if (row.dto.status == 'Valid')
        isbns.add(row.dto.isbn);
    }
    return result;
  }

  public static ImportDTO executeImport(String importKey, String csvText) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(importKey) || importKey.trim().length() < 8)
      throw new AuraHandledException(
        'Provide a stable import key so retries remain idempotent.'
      );
    String key = 'CATALOG_IMPORT:' + importKey.trim().left(80);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :OPERATION AND Idempotency_Key__c = :key
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (!existing.isEmpty())
      return fromLedger(existing[0]);
    List<ParsedRow> rows = parseRows(csvText);
    Set<String> isbns = new Set<String>();
    Integer rejected = 0;
    for (ParsedRow row : rows) {
      validate(row, isbns);
      if (row.dto.status == 'Valid')
        isbns.add(row.dto.isbn);
      else
        rejected++;
    }
    if (rejected > 0)
      throw new AuraHandledException(
        'Preview contains invalid rows. Correct them before importing.'
      );
    List<Book__c> books = new List<Book__c>();
    for (ParsedRow row : rows) {
      Map<String, String> v = row.values;
      books.add(
        new Book__c(
          Name = v.get('title'),
          ISBN__c = v.get('isbn'),
          Publisher__c = v.get('publisher'),
          Publication_Year__c = parseYear(v.get('publicationyear')),
          Edition__c = v.get('edition'),
          Language__c = v.get('language'),
          Description__c = v.get('description'),
          Status__c = 'Active',
          Total_Copies__c = 0,
          Available_Copies__c = 0
        )
      );
    }
    Database.insert(books, AccessLevel.SYSTEM_MODE);
    Library_Scan_Transaction__c ledger = new Library_Scan_Transaction__c(
      Idempotency_Key__c = key,
      Operation__c = OPERATION,
      Status__c = 'Completed',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'k' => importKey,
            'c' => books.size(),
            'r' => 0
          }
        )
        .left(255)
    );
    Database.insert(ledger, AccessLevel.SYSTEM_MODE);
    LibraryOperationAuditService.record(
      'Catalog Import',
      'Manage_Library_Catalog',
      null,
      key,
      'Validated CSV catalog import',
      'Completed',
      null,
      new Map<String, Object>{ 'created' => books.size() }
    );
    ImportDTO result = new ImportDTO();
    result.importKey = importKey;
    result.created = books.size();
    result.rejected = 0;
    result.auditId = ledger.Id;
    return result;
  }

  private static List<ParsedRow> parseRows(String csvText) {
    if (String.isBlank(csvText))
      throw new AuraHandledException('CSV content is required.');
    List<String> lines = csvText.replace('\r', '').split('\n');
    if (lines.size() < 2)
      throw new AuraHandledException(
        'Include a header and at least one data row.'
      );
    List<String> headers = parseLine(lines[0]);
    Map<Integer, String> headerMap = new Map<Integer, String>();
    for (Integer i = 0; i < headers.size(); i++)
      headerMap.put(i, normalize(headers[i]));
    if (
      !headerMap.values().contains('title') ||
      !headerMap.values().contains('isbn')
    )
      throw new AuraHandledException(
        'CSV headers must include title and isbn.'
      );
    List<ParsedRow> result = new List<ParsedRow>();
    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i]))
        continue;
      if (result.size() >= MAX_ROWS)
        throw new AuraHandledException(
          'A single import is limited to 200 rows.'
        );
      List<String> values = parseLine(lines[i]);
      ParsedRow row = new ParsedRow();
      row.rowNumber = i + 1;
      row.values = new Map<String, String>();
      for (Integer c = 0; c < values.size() && headerMap.containsKey(c); c++)
        row.values.put(headerMap.get(c), values[c].trim());
      row.dto = new RowDTO();
      row.dto.rowNumber = row.rowNumber;
      row.dto.title = row.values.get('title');
      row.dto.isbn = row.values.get('isbn');
      result.add(row);
    }
    return result;
  }
  private static void validate(ParsedRow row, Set<String> seenIsbns) {
    row.dto.status = 'Valid';
    row.dto.error = null;
    if (String.isBlank(row.dto.title) || String.isBlank(row.dto.isbn))
      row.dto.error = 'Title and ISBN are required.';
    else if (seenIsbns.contains(row.dto.isbn))
      row.dto.error = 'ISBN is duplicated in this file.';
    else if ([SELECT COUNT() FROM Book__c WHERE ISBN__c = :row.dto.isbn WITH SYSTEM_MODE] > 0)
      row.dto.error = 'ISBN already exists in the catalog.';
    else if (row.dto.title.length() > 255)
      row.dto.error = 'Title is too long.';
    if (row.dto.error != null)
      row.dto.status = 'Invalid';
  }
  private static List<String> parseLine(String line) {
    List<String> result = new List<String>();
    String current = '';
    Boolean quoted = false;
    for (Integer i = 0; i < line.length(); i++) {
      String ch = line.substring(i, i + 1);
      if (ch == '"') {
        if (
          quoted &&
          i + 1 < line.length() &&
          line.substring(i + 1, i + 2) == '"'
        ) {
          current += '"';
          i++;
        } else
          quoted = !quoted;
      } else if (ch == ',' && !quoted) {
        result.add(current);
        current = '';
      } else
        current += ch;
    }
    result.add(current);
    return result;
  }
  private static String normalize(String value) {
    return String.isBlank(value)
      ? ''
      : value.trim().toLowerCase().replace(' ', '');
  }
  private static Decimal parseYear(String value) {
    try {
      return String.isBlank(value) ? null : Decimal.valueOf(value);
    } catch (Exception ignored) {
      return null;
    }
  }
  private static ImportDTO fromLedger(Library_Scan_Transaction__c row) {
    Map<String, Object> p = (Map<String, Object>) JSON.deserializeUntyped(
      row.Result_Message__c
    );
    ImportDTO result = new ImportDTO();
    result.importKey = String.valueOf(p.get('k'));
    result.created = Integer.valueOf(String.valueOf(p.get('c')));
    result.rejected = Integer.valueOf(String.valueOf(p.get('r')));
    result.auditId = row.Id;
    return result;
  }
}
