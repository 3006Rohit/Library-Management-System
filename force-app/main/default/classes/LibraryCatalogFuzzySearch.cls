/**
 * Typo-tolerant title lookup used when an exact catalog title search finds
 * nothing, e.g. "A Quite Season" for "A Quiet Season".
 *
 * Strategy: query on up to three distinctive words, then rank the candidates
 * by how many words they contain and, as a tiebreaker, how close the whole
 * title is (edit distance). Static SOQL only, because dynamic binds can fail
 * in the Agentforce action runtime, so LIMIT values are literals.
 */
public with sharing class LibraryCatalogFuzzySearch {
  private static final Integer MIN_WORD_LENGTH = 3;
  private static final Integer MAX_WORDS = 3;
  private static final Integer MAX_RESULTS = 10;
  private static final Integer WORD_HIT_WEIGHT = 1000;
  // A pattern that cannot match a book title, used to fill unused LIKE slots.
  private static final String NO_MATCH_PATTERN = '%\u0001nomatch\u0001%';
  private static final Set<String> STOP_WORDS = new Set<String>{
    'the',
    'and',
    'for',
    'with',
    'from',
    'book',
    'books'
  };

  public static List<Book__c> findByTitle(
    String rawTitle,
    Boolean availableOnly
  ) {
    List<String> words = distinctiveWords(rawTitle);
    if (words.isEmpty()) {
      return new List<Book__c>();
    }
    String first = pattern(words, 0);
    String second = pattern(words, 1);
    String third = pattern(words, 2);
    List<Book__c> candidates = [
      SELECT Id, Name, Status__c, Total_Copies__c, Available_Copies__c
      FROM Book__c
      WHERE Name LIKE :first OR Name LIKE :second OR Name LIKE :third
      WITH SYSTEM_MODE
      LIMIT 200
    ];
    return rank(
      candidates,
      words,
      rawTitle.trim().toLowerCase(),
      availableOnly
    );
  }

  private static List<String> distinctiveWords(String rawTitle) {
    List<String> words = new List<String>();
    for (String word : rawTitle.trim().toLowerCase().split('[^a-z0-9]+')) {
      if (word.length() >= MIN_WORD_LENGTH && !STOP_WORDS.contains(word)) {
        words.add(word);
      }
    }
    return words;
  }

  private static String pattern(List<String> words, Integer index) {
    return index < words.size() &&
      index < MAX_WORDS
      ? '%' + words[index] + '%'
      : NO_MATCH_PATTERN;
  }

  private static List<Book__c> rank(
    List<Book__c> candidates,
    List<String> words,
    String wantedTitle,
    Boolean availableOnly
  ) {
    List<Candidate> scored = new List<Candidate>();
    for (Book__c book : candidates) {
      if (availableOnly && !hasAvailableCopy(book)) {
        continue;
      }
      String name = book.Name == null ? '' : book.Name.toLowerCase();
      Integer hits = 0;
      for (String word : words) {
        if (name.contains(word)) {
          hits++;
        }
      }
      scored.add(
        new Candidate(
          book,
          hits * WORD_HIT_WEIGHT - editDistance(wantedTitle, name)
        )
      );
    }
    scored.sort();
    List<Book__c> top = new List<Book__c>();
    for (Integer i = 0; i < scored.size() && i < MAX_RESULTS; i++) {
      top.add(scored[i].book);
    }
    return top;
  }

  private static Boolean hasAvailableCopy(Book__c book) {
    return book.Available_Copies__c != null && book.Available_Copies__c > 0;
  }

  /** Classic Levenshtein distance using two rolling rows. */
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

  /** A book with its relevance score; sorts best match first. */
  private class Candidate implements Comparable {
    private final Book__c book;
    private final Integer score;

    private Candidate(Book__c book, Integer score) {
      this.book = book;
      this.score = score;
    }

    public Integer compareTo(Object other) {
      return ((Candidate) other).score - score;
    }
  }
}
