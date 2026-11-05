/**
 * Builds the single-row catalog answers returned to the signed-out public
 * assistant.
 *
 * The agent runtime only surfaces the first row of a multi-row action result,
 * so the public assistant gets ONE row whose title field holds a readable
 * list. Member and librarian agents never reach this class; they keep the
 * one-row-per-book shape (see LibraryAgentCatalogAction).
 */
public with sharing class LibraryPublicCatalogSummary {
  private static final Integer MAX_BOOKS = 8;
  // At or below this many matches, each book gets its full detail block.
  private static final Integer DETAIL_THRESHOLD = 3;
  private static final Integer DESCRIPTION_LENGTH = 350;
  private static final String DETAIL_INDENT = '   ';

  /** One result describing up to MAX_BOOKS of the matched books. */
  public static LibraryAgentCatalogAction.BookResult forBooks(
    List<LibraryAgentCatalogAction.BookResult> matches
  ) {
    LibraryAgentCatalogAction.BookResult out = new LibraryAgentCatalogAction.BookResult();
    if (matches.isEmpty()) {
      out.status = 'NONE';
      out.message = 'No books matched that search.';
      return out;
    }
    Integer shown = Math.min(matches.size(), MAX_BOOKS);
    Set<Id> ids = new Set<Id>();
    for (Integer i = 0; i < shown; i++) {
      ids.add((Id) matches[i].bookId);
    }
    Map<Id, Book__c> books = loadBooks(ids);
    Map<Id, List<String>> authors = loadAuthors(ids);
    Map<Id, List<String>> genres = loadGenres(ids);
    Boolean detailed = matches.size() <= DETAIL_THRESHOLD;

    List<String> entries = new List<String>();
    for (Integer i = 0; i < shown; i++) {
      Book__c book = books.get((Id) matches[i].bookId);
      if (book == null) {
        continue;
      }
      String heading = heading(i + 1, book, join(authors, book.Id));
      String genre = join(genres, book.Id);
      entries.add(
        detailed
          ? detailBlock(heading, book, genre)
          : heading + (genre == null ? '' : ' [' + genre + ']')
      );
    }
    out.status = 'OK';
    out.title = String.join(entries, '\n');
    out.totalCopies = matches.size();
    out.message = matches.size() > MAX_BOOKS
      ? 'Showing the first ' +
        MAX_BOOKS +
        ' of ' +
        matches.size() +
        ' matching books. Ask the visitor to narrow by genre, author or title to see others.'
      : 'Showing all ' + matches.size() + ' matching books.';
    return out;
  }

  /** One result listing every genre with its number of books. */
  public static LibraryAgentCatalogAction.BookResult forGenres() {
    LibraryAgentCatalogAction.BookResult out = new LibraryAgentCatalogAction.BookResult();
    Map<Id, Integer> counts = new Map<Id, Integer>();
    for (AggregateResult row : [
      SELECT Book_Category__c category, COUNT(Id) total
      FROM Book_Category_Link__c
      WITH SYSTEM_MODE
      GROUP BY Book_Category__c
    ]) {
      counts.put((Id) row.get('category'), Integer.valueOf(row.get('total')));
    }
    List<String> names = new List<String>();
    for (Book_Category__c category : [
      SELECT Id, Name
      FROM Book_Category__c
      WHERE Id IN :counts.keySet()
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 100
    ]) {
      names.add(category.Name + ' (' + counts.get(category.Id) + ' books)');
    }
    if (names.isEmpty()) {
      out.status = 'NONE';
      out.message = 'No genres are published yet.';
      return out;
    }
    out.status = 'OK';
    out.title = String.join(names, '\n');
    out.totalCopies = names.size();
    out.message = 'The library holds ' + names.size() + ' genres.';
    return out;
  }

  // ---- formatting ---------------------------------------------------------

  private static String heading(
    Integer position,
    Book__c book,
    String authors
  ) {
    return position +
      '. ' +
      book.Name +
      (authors == null ? '' : ' by ' + authors) +
      ' - ' +
      availability(book);
  }

  private static String availability(Book__c book) {
    Decimal available = book.Available_Copies__c == null
      ? 0
      : book.Available_Copies__c;
    Decimal total = book.Total_Copies__c == null ? 0 : book.Total_Copies__c;
    return available > 0
      ? 'Available (' +
        available.intValue() +
        ' of ' +
        total.intValue() +
        ' copies)'
      : 'All copies on loan';
  }

  /** Heading plus every detail the catalog holds; blank fields are skipped. */
  private static String detailBlock(
    String heading,
    Book__c book,
    String genre
  ) {
    List<String> lines = new List<String>{ heading };
    addLine(lines, 'Genre', genre);
    addLine(lines, 'Published', publication(book));
    addLine(lines, 'Edition', book.Edition__c);
    addLine(lines, 'Language', book.Language__c);
    addLine(lines, 'ISBN', book.ISBN__c);
    addLine(
      lines,
      'About',
      book.Description__c == null
        ? null
        : book.Description__c.abbreviate(DESCRIPTION_LENGTH)
    );
    return String.join(lines, '\n');
  }

  private static void addLine(List<String> lines, String label, String value) {
    if (!String.isBlank(value)) {
      lines.add(DETAIL_INDENT + label + ': ' + value);
    }
  }

  private static String publication(Book__c book) {
    List<String> parts = new List<String>();
    if (!String.isBlank(book.Publisher__c)) {
      parts.add(book.Publisher__c);
    }
    if (book.Publication_Year__c != null) {
      parts.add(String.valueOf(book.Publication_Year__c.intValue()));
    }
    return parts.isEmpty() ? null : String.join(parts, ', ');
  }

  private static String join(Map<Id, List<String>> valuesByBook, Id bookId) {
    List<String> values = valuesByBook.get(bookId);
    return values == null || values.isEmpty()
      ? null
      : String.join(values, ', ');
  }

  // ---- data loading -------------------------------------------------------

  private static Map<Id, Book__c> loadBooks(Set<Id> ids) {
    return new Map<Id, Book__c>(
      [
        SELECT
          Id,
          Name,
          ISBN__c,
          Publisher__c,
          Publication_Year__c,
          Edition__c,
          Language__c,
          Description__c,
          Total_Copies__c,
          Available_Copies__c
        FROM Book__c
        WHERE Id IN :ids
        WITH SYSTEM_MODE
      ]
    );
  }

  private static Map<Id, List<String>> loadAuthors(Set<Id> ids) {
    Map<Id, List<String>> authors = new Map<Id, List<String>>();
    for (Book_Author__c link : [
      SELECT Book__c, Author__r.Name
      FROM Book_Author__c
      WHERE Book__c IN :ids
      WITH SYSTEM_MODE
      ORDER BY Author_Order__c NULLS LAST
    ]) {
      append(authors, link.Book__c, link.Author__r.Name);
    }
    return authors;
  }

  private static Map<Id, List<String>> loadGenres(Set<Id> ids) {
    Map<Id, List<String>> genres = new Map<Id, List<String>>();
    for (Book_Category_Link__c link : [
      SELECT Book__c, Book_Category__r.Name
      FROM Book_Category_Link__c
      WHERE Book__c IN :ids
      WITH SYSTEM_MODE
    ]) {
      append(genres, link.Book__c, link.Book_Category__r.Name);
    }
    return genres;
  }

  private static void append(
    Map<Id, List<String>> valuesByBook,
    Id bookId,
    String value
  ) {
    if (!valuesByBook.containsKey(bookId)) {
      valuesByBook.put(bookId, new List<String>());
    }
    valuesByBook.get(bookId).add(value);
  }
}
