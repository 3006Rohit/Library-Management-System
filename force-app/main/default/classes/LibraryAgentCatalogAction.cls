global with sharing class LibraryAgentCatalogAction {
  global class Request {
    @InvocableVariable
    public String title;
    @InvocableVariable
    public String author;
    @InvocableVariable
    public String category;
    @InvocableVariable
    public Boolean availableOnly;
  }
  global class BookResult {
    @InvocableVariable
    public String bookId;
    @InvocableVariable
    public String title;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public Decimal totalCopies;
    @InvocableVariable
    public Decimal availableCopies;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Search Library Catalog'
    description='Use this action for live catalog searches by title, author, category, or availability. Invoke it before answering current catalog facts; never returns member or authentication data.'
  )
  global static List<BookResult> execute(List<Request> requests) {
    try {
      // The agent runtime only surfaces the first row of a multi-row result.
      // The public assistant (identified by a custom permission on its agent
      // user) therefore gets ONE row that lists books with their details.
      // Member and librarian agents keep the one-row-per-book shape.
      Boolean publicAgent = FeatureManagement.checkPermission(
        'Library_Public_Agent'
      );
      if (
        publicAgent &&
        requests != null &&
        !requests.isEmpty() &&
        requests[0] != null &&
        requests[0].category == '*'
      ) {
        return new List<BookResult>{ genreSummary() };
      }
      List<BookResult> rows = executeInternal(requests);
      if (publicAgent) {
        return new List<BookResult>{ summarize(rows) };
      }
      return rows;
    } catch (Exception ex) {
      BookResult result = new BookResult();
      result.status = 'ERROR';
      result.message = 'The library catalog is temporarily unavailable.';
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_AGENT_CATALOG_FAILED: ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
      return new List<BookResult>{ result };
    }
  }

  @TestVisible
  private static final Integer SUMMARY_LIMIT = 8;

  @TestVisible
  private static final Integer DETAIL_LIMIT = 3;

  private static String availabilityText(Book__c book) {
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

  private static String joined(Map<Id, List<String>> byBook, Id bookId) {
    List<String> values = byBook.get(bookId);
    return values == null || values.isEmpty()
      ? null
      : String.join(values, ', ');
  }

  private static BookResult summarize(List<BookResult> rows) {
    BookResult out = new BookResult();
    if (rows.isEmpty()) {
      out.status = 'NONE';
      out.message = 'No books matched that search.';
      return out;
    }
    Integer shown = Math.min(rows.size(), SUMMARY_LIMIT);
    Set<Id> ids = new Set<Id>();
    for (Integer i = 0; i < shown; i++) {
      ids.add((Id) rows[i].bookId);
    }
    Map<Id, Book__c> books = new Map<Id, Book__c>(
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
    Map<Id, List<String>> authors = new Map<Id, List<String>>();
    for (Book_Author__c link : [
      SELECT Book__c, Author__r.Name
      FROM Book_Author__c
      WHERE Book__c IN :ids
      WITH SYSTEM_MODE
      ORDER BY Author_Order__c NULLS LAST
    ]) {
      if (!authors.containsKey(link.Book__c)) {
        authors.put(link.Book__c, new List<String>());
      }
      authors.get(link.Book__c).add(link.Author__r.Name);
    }
    Map<Id, List<String>> genres = new Map<Id, List<String>>();
    for (Book_Category_Link__c link : [
      SELECT Book__c, Book_Category__r.Name
      FROM Book_Category_Link__c
      WHERE Book__c IN :ids
      WITH SYSTEM_MODE
    ]) {
      if (!genres.containsKey(link.Book__c)) {
        genres.put(link.Book__c, new List<String>());
      }
      genres.get(link.Book__c).add(link.Book_Category__r.Name);
    }

    Boolean detailed = rows.size() <= DETAIL_LIMIT;
    List<String> lines = new List<String>();
    for (Integer i = 0; i < shown; i++) {
      Book__c book = books.get((Id) rows[i].bookId);
      if (book == null) {
        continue;
      }
      String authorText = joined(authors, book.Id);
      String genre = joined(genres, book.Id);
      String head =
        (i + 1) +
        '. ' +
        book.Name +
        (authorText == null ? '' : ' by ' + authorText) +
        ' - ' +
        availabilityText(book);
      if (!detailed) {
        lines.add(head + (genre == null ? '' : ' [' + genre + ']'));
        continue;
      }
      List<String> parts = new List<String>{ head };
      if (genre != null) {
        parts.add('   Genre: ' + genre);
      }
      List<String> published = new List<String>();
      if (!String.isBlank(book.Publisher__c)) {
        published.add(book.Publisher__c);
      }
      if (book.Publication_Year__c != null) {
        published.add(String.valueOf(book.Publication_Year__c.intValue()));
      }
      if (!published.isEmpty()) {
        parts.add('   Published: ' + String.join(published, ', '));
      }
      if (!String.isBlank(book.Edition__c)) {
        parts.add('   Edition: ' + book.Edition__c);
      }
      if (!String.isBlank(book.Language__c)) {
        parts.add('   Language: ' + book.Language__c);
      }
      if (!String.isBlank(book.ISBN__c)) {
        parts.add('   ISBN: ' + book.ISBN__c);
      }
      if (!String.isBlank(book.Description__c)) {
        parts.add('   About: ' + book.Description__c.abbreviate(350));
      }
      lines.add(String.join(parts, '\n'));
    }
    out.status = 'OK';
    out.title = String.join(lines, '\n');
    out.totalCopies = rows.size();
    out.message = rows.size() > SUMMARY_LIMIT
      ? 'Showing the first ' +
        SUMMARY_LIMIT +
        ' of ' +
        rows.size() +
        ' matching books. Ask the visitor to narrow by genre, author or title to see others.'
      : 'Showing all ' + rows.size() + ' matching books.';
    return out;
  }

  // Genres the library holds, with how many books each has. Triggered by the
  // public assistant passing category = '*'.
  private static BookResult genreSummary() {
    BookResult out = new BookResult();
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

  // Typo-tolerant fallback used only when the exact title search finds nothing,
  // e.g. "A Quite Season" for "A Quiet Season". Static SOQL on up to three
  // distinctive words, then ranked in Apex so the closest title comes first.
  private static final Set<String> STOP_WORDS = new Set<String>{
    'the',
    'and',
    'for',
    'with',
    'from',
    'book',
    'books'
  };

  private static List<Book__c> fuzzyTitleMatches(
    String rawTitle,
    Boolean availableOnly
  ) {
    List<String> words = new List<String>();
    for (String word : rawTitle.trim().toLowerCase().split('[^a-z0-9]+')) {
      if (word.length() >= 3 && !STOP_WORDS.contains(word)) {
        words.add(word);
      }
    }
    if (words.isEmpty()) {
      return new List<Book__c>();
    }
    String none = '%\u0001nomatch\u0001%';
    String w1 = '%' + words[0] + '%';
    String w2 = words.size() > 1 ? '%' + words[1] + '%' : none;
    String w3 = words.size() > 2 ? '%' + words[2] + '%' : none;
    List<Book__c> candidates = [
      SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
      FROM Book__c
      WHERE Name LIKE :w1 OR Name LIKE :w2 OR Name LIKE :w3
      WITH SYSTEM_MODE
      LIMIT 200
    ];
    String wanted = rawTitle.trim().toLowerCase();
    List<Book__c> kept = new List<Book__c>();
    Map<Id, Integer> score = new Map<Id, Integer>();
    for (Book__c book : candidates) {
      if (
        availableOnly &&
        (book.Available_Copies__c == null ||
        book.Available_Copies__c <= 0)
      ) {
        continue;
      }
      String name = book.Name == null ? '' : book.Name.toLowerCase();
      Integer hits = 0;
      for (String word : words) {
        if (name.contains(word)) {
          hits++;
        }
      }
      // More matching words first, then the smaller edit distance.
      score.put(book.Id, hits * 1000 - editDistance(wanted, name));
      kept.add(book);
    }
    for (Integer i = 1; i < kept.size(); i++) {
      Book__c current = kept[i];
      Integer j = i - 1;
      while (j >= 0 && score.get(kept[j].Id) < score.get(current.Id)) {
        kept[j + 1] = kept[j];
        j--;
      }
      kept[j + 1] = current;
    }
    List<Book__c> top = new List<Book__c>();
    for (Integer i = 0; i < kept.size() && i < 10; i++) {
      top.add(kept[i]);
    }
    return top;
  }

  private static Integer editDistance(String a, String b) {
    List<Integer> previous = new List<Integer>();
    for (Integer j = 0; j <= b.length(); j++) {
      previous.add(j);
    }
    for (Integer i = 1; i <= a.length(); i++) {
      List<Integer> row = new List<Integer>{ i };
      for (Integer j = 1; j <= b.length(); j++) {
        Integer cost = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
        row.add(
          Math.min(
            Math.min(previous[j] + 1, row[j - 1] + 1),
            previous[j - 1] + cost
          )
        );
      }
      previous = row;
    }
    return previous[b.length()];
  }

  private static List<BookResult> executeInternal(List<Request> requests) {
    Request request = requests == null || requests.isEmpty()
      ? new Request()
      : requests[0];
    String titleTerm = String.isBlank(request.title)
      ? null
      : '%' + request.title.trim() + '%';
    String authorTerm = String.isBlank(request.author)
      ? null
      : '%' + request.author.trim() + '%';
    String categoryTerm = String.isBlank(request.category)
      ? null
      : '%' + request.category.trim() + '%';
    Set<Id> bookIds = new Set<Id>();
    if (authorTerm != null) {
      Set<Id> authorIds = new Map<Id, Author__c>(
          [
            SELECT Id
            FROM Author__c
            WHERE Name LIKE :authorTerm
            WITH SYSTEM_MODE
            LIMIT 200
          ]
        )
        .keySet();
      if (!authorIds.isEmpty())
        for (Book_Author__c link : [
          SELECT Book__c
          FROM Book_Author__c
          WHERE Author__c IN :authorIds
          WITH SYSTEM_MODE
          LIMIT 200
        ])
          bookIds.add(link.Book__c);
    }
    if (categoryTerm != null) {
      Set<Id> categoryIds = new Map<Id, Book_Category__c>(
          [
            SELECT Id
            FROM Book_Category__c
            WHERE Name LIKE :categoryTerm
            WITH SYSTEM_MODE
            LIMIT 200
          ]
        )
        .keySet();
      if (!categoryIds.isEmpty())
        for (Book_Category_Link__c link : [
          SELECT Book__c
          FROM Book_Category_Link__c
          WHERE Book_Category__c IN :categoryIds
          WITH SYSTEM_MODE
          LIMIT 200
        ])
          bookIds.add(link.Book__c);
    }
    List<Book__c> books;
    // Keep this action on static SOQL. Agentforce executes invocable actions in
    // a separate action runtime where dynamic SOQL binds can fail with opaque
    // UNKNOWN_EXCEPTION/tmpVar errors even though the same query passes in Apex
    // tests. Static branches also keep the catalog query bounded and auditable.
    if (authorTerm != null || categoryTerm != null) {
      if (bookIds.isEmpty())
        return new List<BookResult>();
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Id IN :bookIds
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 50
      ];
      for (Integer index = books.size() - 1; index >= 0; index--) {
        Book__c book = books[index];
        if (
          titleTerm != null &&
          (book.Name == null ||
          !book.Name.toLowerCase().contains(request.title.trim().toLowerCase()))
        ) {
          books.remove(index);
        } else if (
          request.availableOnly == true &&
          (book.Available_Copies__c == null ||
          book.Available_Copies__c <= 0)
        ) {
          books.remove(index);
        }
      }
    } else if (titleTerm != null && request.availableOnly == true) {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Name LIKE :titleTerm AND Available_Copies__c > 0
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 50
      ];
    } else if (titleTerm != null) {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Name LIKE :titleTerm
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 50
      ];
    } else if (request.availableOnly == true) {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WHERE Available_Copies__c > 0
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 50
      ];
    } else {
      books = [
        SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
        FROM Book__c
        WITH SYSTEM_MODE
        ORDER BY Name
        LIMIT 50
      ];
    }
    if (
      books.isEmpty() &&
      titleTerm != null &&
      authorTerm == null &&
      categoryTerm == null
    ) {
      books = fuzzyTitleMatches(request.title, request.availableOnly == true);
    }
    List<BookResult> output = new List<BookResult>();
    for (Book__c book : books) {
      BookResult result = new BookResult();
      result.bookId = String.valueOf(book.Id);
      result.title = book.Name;
      result.status = book.Status__c;
      result.totalCopies = book.Total_Copies__c;
      result.availableCopies = book.Available_Copies__c;
      output.add(result);
    }
    return output;
  }
}
