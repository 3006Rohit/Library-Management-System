public without sharing class LibraryMetadataService {
  private static final String NAMED_CREDENTIAL = 'Library_Metadata';
  private static final String OPERATION = 'Catalog Metadata';

  public class MetadataDTO {
    @AuraEnabled
    public String isbn;
    @AuraEnabled
    public String normalizedIsbn;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String subtitle;
    @AuraEnabled
    public String authors;
    @AuraEnabled
    public String publisher;
    @AuraEnabled
    public Integer publicationYear;
    @AuraEnabled
    public String edition;
    @AuraEnabled
    public String language;
    @AuraEnabled
    public String categories;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String coverUrl;
    @AuraEnabled
    public String provider;
    @AuraEnabled
    public String duplicateBookId;
    @AuraEnabled
    public Integer qualityScore;
    @AuraEnabled
    public List<String> warnings = new List<String>();
  }

  public static MetadataDTO lookup(String isbn) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    String normalized = normalize(isbn);
    if (!isValid(normalized)) {
      throw new AuraHandledException('Enter a valid ISBN-10 or ISBN-13.');
    }
    HttpRequest request = new HttpRequest();
    request.setEndpoint(
      'callout:' + NAMED_CREDENTIAL + '/books/' + normalized + '.json'
    );
    request.setMethod('GET');
    request.setHeader('Accept', 'application/json');
    request.setTimeout(30000);
    HttpResponse response;
    try {
      response = new Http().send(request);
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Metadata provider is temporarily unavailable. Existing catalog data was not changed.'
      );
    }
    if (response.getStatusCode() == 404) {
      throw new AuraHandledException('No metadata was found for that ISBN.');
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      throw new AuraHandledException(
        'Metadata provider returned an error. Existing catalog data was not changed.'
      );
    }
    Map<String, Object> payload;
    try {
      payload = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Metadata provider returned an invalid response.'
      );
    }
    MetadataDTO result = fromPayload(payload, isbn, normalized);
    List<Book__c> duplicates = [
      SELECT Id, Name, ISBN__c
      FROM Book__c
      WHERE ISBN__c = :normalized OR ISBN__c = :isbn.trim()
      LIMIT 1
    ];
    if (!duplicates.isEmpty())
      result.duplicateBookId = String.valueOf(duplicates[0].Id);
    return result;
  }

  public static void apply(
    Id bookId,
    String selectedFieldsCsv,
    String isbn,
    String title,
    String publisher,
    Integer publicationYear,
    String edition,
    String language,
    String description,
    String coverUrl
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (bookId == null || String.isBlank(selectedFieldsCsv)) {
      throw new AuraHandledException(
        'Choose a book and at least one metadata field.'
      );
    }
    Set<String> selected = new Set<String>();
    for (String fieldName : selectedFieldsCsv.split(',')) {
      if (!String.isBlank(fieldName))
        selected.add(fieldName.trim());
    }
    Set<String> allowed = new Set<String>{
      'isbn',
      'title',
      'publisher',
      'publicationYear',
      'edition',
      'language',
      'description',
      'coverUrl'
    };
    if (!allowed.containsAll(selected))
      throw new AuraHandledException(
        'One or more metadata fields are not supported.'
      );
    Book__c current = [
      SELECT Id, ISBN__c
      FROM Book__c
      WHERE Id = :bookId
      FOR UPDATE
    ];
    Book__c updateRecord = new Book__c(Id = bookId);
    if (selected.contains('isbn')) {
      String normalized = normalize(isbn);
      if (!isValid(normalized))
        throw new AuraHandledException('The selected ISBN is invalid.');
      if (
        [
          SELECT COUNT()
          FROM Book__c
          WHERE ISBN__c = :normalized AND Id != :bookId
        ] > 0
      )
        throw new AuraHandledException('Another book already uses this ISBN.');
      updateRecord.ISBN__c = normalized;
    }
    if (selected.contains('title')) {
      if (String.isBlank(title))
        throw new AuraHandledException('Title cannot be blank.');
      updateRecord.Name = title.trim();
    }
    if (selected.contains('publisher'))
      updateRecord.Publisher__c = trimValue(publisher, 150);
    if (selected.contains('publicationYear'))
      updateRecord.Publication_Year__c = publicationYear;
    if (selected.contains('edition'))
      updateRecord.Edition__c = trimValue(edition, 50);
    if (selected.contains('language'))
      updateRecord.Language__c = normalizeLanguage(language);
    if (selected.contains('description'))
      updateRecord.Description__c = trimValue(description, 32768);
    if (selected.contains('coverUrl'))
      updateRecord.Cover_Image_URL__c = trimValue(coverUrl, 255);
    update updateRecord;
    LibraryOperationAuditService.record(
      'Catalog Metadata Applied',
      'Manage_Library_Catalog',
      bookId,
      null,
      selectedFieldsCsv,
      'Applied',
      new Map<String, Object>{ 'isbn' => current.ISBN__c },
      new Map<String, Object>{ 'fields' => selectedFieldsCsv }
    );
  }

  public static String normalize(String raw) {
    if (String.isBlank(raw))
      return '';
    return raw.replaceAll('[^0-9Xx]', '').toUpperCase();
  }

  public static Boolean isValid(String value) {
    if (String.isBlank(value))
      return false;
    if (value.length() == 10) {
      Integer sum = 0;
      for (Integer i = 0; i < 10; i++) {
        Integer digit = value.substring(i, i + 1) == 'X'
          ? 10
          : Integer.valueOf(value.substring(i, i + 1));
        sum += (10 - i) * digit;
      }
      return Math.mod(sum, 11) == 0;
    }
    if (value.length() == 13) {
      Integer sum = 0;
      for (Integer i = 0; i < 12; i++)
        sum +=
          Integer.valueOf(value.substring(i, i + 1)) *
          (Math.mod(i, 2) == 0 ? 1 : 3);
      Integer check = Math.mod(10 - Math.mod(sum, 10), 10);
      return check == Integer.valueOf(value.substring(12, 13));
    }
    return false;
  }

  private static MetadataDTO fromPayload(
    Map<String, Object> payload,
    String rawIsbn,
    String normalized
  ) {
    MetadataDTO result = new MetadataDTO();
    result.isbn = rawIsbn;
    result.normalizedIsbn = normalized;
    result.provider = 'Open Library via Library_Metadata';
    result.title = stringValue(payload.get('title'));
    result.subtitle = stringValue(payload.get('subtitle'));
    result.publisher = firstString(payload.get('publishers'));
    result.edition = stringValue(payload.get('edition_name'));
    result.description = descriptionValue(payload.get('description'));
    result.authors = joinNames(payload.get('authors'));
    result.categories = joinSubjects(payload.get('subjects'));
    result.language = languageValue(payload.get('languages'));
    result.publicationYear = yearValue(
      stringValue(payload.get('publish_date'))
    );
    result.coverUrl = coverValue(payload.get('covers'));
    Integer score = 0;
    if (!String.isBlank(result.title))
      score++;
    if (!String.isBlank(result.authors))
      score++;
    if (!String.isBlank(result.publisher))
      score++;
    if (result.publicationYear != null)
      score++;
    if (!String.isBlank(result.description))
      score++;
    if (!String.isBlank(result.coverUrl))
      score++;
    result.qualityScore = score;
    if (String.isBlank(result.title))
      result.warnings.add('Provider did not return a title.');
    if (String.isBlank(result.authors))
      result.warnings.add('Authors were not returned.');
    if (String.isBlank(result.coverUrl))
      result.warnings.add('No cover image was returned.');
    return result;
  }
  private static String firstString(Object value) {
    if (!(value instanceof List<Object>))
      return null;
    List<Object> rows = (List<Object>) value;
    return rows.isEmpty() ? null : stringValue(rows[0]);
  }
  private static String joinNames(Object value) {
    if (!(value instanceof List<Object>))
      return null;
    List<String> names = new List<String>();
    for (Object row : (List<Object>) value)
      if (row instanceof Map<String, Object>)
        names.add(stringValue(((Map<String, Object>) row).get('name')));
    return String.join(names, ', ');
  }
  private static String joinSubjects(Object value) {
    if (!(value instanceof List<Object>))
      return null;
    List<String> names = new List<String>();
    for (Object row : (List<Object>) value)
      names.add(stringValue(row));
    return String.join(names, ', ');
  }
  private static String descriptionValue(Object value) {
    if (value instanceof Map<String, Object>)
      return stringValue(((Map<String, Object>) value).get('value'));
    return stringValue(value);
  }
  private static String languageValue(Object value) {
    if (
      !(value instanceof List<Object>) &&
      !(value instanceof Map<String, Object>)
    )
      return null;
    String raw = JSON.serialize(value).toLowerCase();
    if (raw.contains('eng'))
      return 'English';
    if (raw.contains('hin'))
      return 'Hindi';
    return 'Other';
  }
  private static String coverValue(Object value) {
    if (!(value instanceof List<Object>))
      return null;
    List<Object> covers = (List<Object>) value;
    return covers.isEmpty()
      ? null
      : 'https://covers.openlibrary.org/b/id/' +
        String.valueOf(covers[0]) +
        '-M.jpg';
  }
  private static Integer yearValue(String value) {
    if (String.isBlank(value) || value.length() < 4)
      return null;
    try {
      return Integer.valueOf(value.substring(0, 4));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
  private static String trimValue(String value, Integer maxLength) {
    if (value == null)
      return null;
    String trimmed = value.trim();
    return trimmed.length() > maxLength
      ? trimmed.substring(0, maxLength)
      : trimmed;
  }
  private static String normalizeLanguage(String value) {
    if (String.isBlank(value))
      return 'Other';
    if (value.toLowerCase().contains('eng'))
      return 'English';
    if (value.toLowerCase().contains('hin'))
      return 'Hindi';
    return 'Other';
  }
}
