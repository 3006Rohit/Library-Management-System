public without sharing class LibraryAcquisitionInsightService {
  // A decision is kept for this long before the book is re-evaluated.
  private static final Integer DECISION_HOLD_DAYS = 30;
  // Collection-development rules of thumb used by public libraries.
  private static final Integer HOLD_RATIO_TARGET = 3; // holds per lendable copy
  private static final Integer MAX_WAIT_DAYS = 21; // longest acceptable hold wait
  private static final Integer BUSY_LOANS_PER_COPY = 4; // loans per copy per period
  private static final Integer RECENT_DAYS = 90; // demand window
  private static final Integer MAX_COPIES_PER_ORDER = 10;
  private static final Integer WEED_MIN_YEARS = 2; // never weed newer titles
  private static final String PROMPT_TEMPLATE = 'Library_Acquisition_Advisor';
  private static final Integer AI_MAX_BOOKS = 40; // books sent per refresh

  public class AcquisitionAdvisorException extends Exception {
  }

  @TestVisible
  private static String testAiResponse;

  public class RecommendationDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id bookId;
    @AuraEnabled
    public String bookTitle;
    @AuraEnabled
    public String recommendationType;
    @AuraEnabled
    public Decimal score;
    @AuraEnabled
    public String confidence;
    @AuraEnabled
    public String evidence;
    @AuraEnabled
    public Integer recommendedQuantity;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Date evidenceWindowStart;
    @AuraEnabled
    public Date evidenceWindowEnd;
    @AuraEnabled
    public Datetime refreshedAt;
    @AuraEnabled
    public Integer reservations;
    @AuraEnabled
    public Integer availableCopies;
    @AuraEnabled
    public Integer recentCheckouts;
    @AuraEnabled
    public Integer damagedCopies;
    @AuraEnabled
    public Integer agingCopies;
    @AuraEnabled
    public Boolean insufficientEvidence;
    @AuraEnabled
    public String decisionNotes;
    @AuraEnabled
    public Integer circulatingCopies;
    @AuraEnabled
    public Integer poorCopies;
    @AuraEnabled
    public Integer yearCheckouts;
    @AuraEnabled
    public Decimal holdRatio;
    @AuraEnabled
    public Integer longestWaitDays;
    @AuraEnabled
    public Decimal estimatedCost;
    @AuraEnabled
    public String generatedBy;
  }

  private class Signal {
    Integer reservations = 0; // holds still waiting for a copy
    Integer readyHolds = 0; // holds already filled and waiting for pickup
    Datetime oldestHold;
    Integer recentCheckouts = 0; // loans in the last 90 days
    Integer yearCheckouts = 0; // loans in the last 12 months
    Integer circulating = 0; // copies that can be lent (not lost/damaged/retired)
    Integer damagedCopies = 0; // damaged or lost
    Integer poorCopies = 0; // circulating but in poor condition
    Integer agingCopies = 0; // five years or older
    Decimal avgPrice;
    Date firstAcquired;
  }

  private class Decision {
    String type;
    Integer quantity;
    Integer score;
    String confidence;
    String evidence;
    Decimal estimatedCost;
    Decimal holdRatio;
    Integer longestWaitDays;
    String generatedBy = 'Rules';
  }

  public static List<RecommendationDTO> getRecommendations() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Date windowStart = Date.today().addDays(-RECENT_DAYS);
    Date windowEnd = Date.today();
    Datetime refreshedAt = System.now();
    Datetime recentStart = System.now().addDays(-RECENT_DAYS);
    Datetime yearStart = System.now().addDays(-365);
    List<Book__c> books = [
      SELECT Id, Name, Total_Copies__c, Available_Copies__c
      FROM Book__c
      WHERE Status__c != 'Archived'
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 500
    ];
    Map<Id, Signal> signals = new Map<Id, Signal>();
    for (Book__c book : books)
      signals.put(book.Id, new Signal());

    // Holds: waiting holds drive demand; filled holds only block weeding.
    for (AggregateResult row : [
      SELECT
        Book__c bookId,
        Status__c holdStatus,
        COUNT(Id) countValue,
        MIN(Reservation_Date__c) oldest
      FROM Reservation__c
      WHERE Book__c != NULL AND Status__c IN ('Pending', 'Ready')
      WITH SYSTEM_MODE
      GROUP BY Book__c, Status__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (!signals.containsKey(bookId))
        continue;
      Signal signal = signals.get(bookId);
      Integer count = Integer.valueOf(row.get('countValue'));
      if ((String) row.get('holdStatus') == 'Pending') {
        signal.reservations = count;
        signal.oldestHold = (Datetime) row.get('oldest');
      } else {
        signal.readyHolds = count;
      }
    }
    for (AggregateResult row : [
      SELECT Book_Copy__r.Book__c bookId, COUNT(Id) countValue
      FROM Borrow_Record__c
      WHERE Book_Copy__r.Book__c != NULL AND Borrow_Date__c >= :recentStart
      WITH SYSTEM_MODE
      GROUP BY Book_Copy__r.Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).recentCheckouts = Integer.valueOf(
          row.get('countValue')
        );
    }
    for (AggregateResult row : [
      SELECT Book_Copy__r.Book__c bookId, COUNT(Id) countValue
      FROM Borrow_Record__c
      WHERE Book_Copy__r.Book__c != NULL AND Borrow_Date__c >= :yearStart
      WITH SYSTEM_MODE
      GROUP BY Book_Copy__r.Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).yearCheckouts = Integer.valueOf(
          row.get('countValue')
        );
    }
    // Copies: split into lendable, worn out and gone.
    for (AggregateResult row : [
      SELECT
        Book__c bookId,
        Status__c copyStatus,
        Condition__c copyCondition,
        COUNT(Id) countValue
      FROM Book_Copy__c
      WHERE Book__c != NULL
      WITH SYSTEM_MODE
      GROUP BY Book__c, Status__c, Condition__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (!signals.containsKey(bookId))
        continue;
      Signal signal = signals.get(bookId);
      String copyStatus = (String) row.get('copyStatus');
      Integer count = Integer.valueOf(row.get('countValue'));
      if (copyStatus == 'Damaged' || copyStatus == 'Lost') {
        signal.damagedCopies += count;
      } else if (copyStatus != 'Retired') {
        signal.circulating += count;
        if ((String) row.get('copyCondition') == 'Poor')
          signal.poorCopies += count;
      }
    }
    Date agingCutoff = Date.today().addYears(-5);
    for (AggregateResult row : [
      SELECT
        Book__c bookId,
        AVG(Price__c) avgPrice,
        MIN(Acquisition_Date__c) firstAcquired,
        COUNT(Id) totalCopies
      FROM Book_Copy__c
      WHERE Book__c != NULL AND Status__c NOT IN ('Retired', 'Lost')
      WITH SYSTEM_MODE
      GROUP BY Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (!signals.containsKey(bookId))
        continue;
      Signal signal = signals.get(bookId);
      if (row.get('avgPrice') != null)
        signal.avgPrice = Decimal.valueOf(String.valueOf(row.get('avgPrice')));
      signal.firstAcquired = (Date) row.get('firstAcquired');
    }
    for (AggregateResult row : [
      SELECT Book__c bookId, COUNT(Id) countValue
      FROM Book_Copy__c
      WHERE
        Book__c != NULL
        AND Acquisition_Date__c <= :agingCutoff
        AND Status__c NOT IN ('Retired', 'Lost')
      WITH SYSTEM_MODE
      GROUP BY Book__c
    ]) {
      Id bookId = (Id) row.get('bookId');
      if (signals.containsKey(bookId))
        signals.get(bookId).agingCopies = Integer.valueOf(
          row.get('countValue')
        );
    }

    Set<Id> bookIds = new Set<Id>();
    for (Book__c book : books)
      bookIds.add(book.Id);
    // One record per book and type, reused across refreshes so decisions stick.
    Map<String, Acquisition_Recommendation__c> existing = new Map<String, Acquisition_Recommendation__c>();
    for (Acquisition_Recommendation__c record : [
      SELECT
        Id,
        Book__c,
        Recommendation_Type__c,
        Recommendation_Score__c,
        Recommended_Quantity__c,
        Confidence__c,
        Evidence__c,
        Status__c,
        Evidence_Window_Start__c,
        Evidence_Window_End__c,
        Refreshed_At__c,
        Decision_Notes__c,
        Decided_At__c,
        Snapshot_Key__c
      FROM Acquisition_Recommendation__c
      WHERE Book__c IN :bookIds
      WITH SYSTEM_MODE
      ORDER BY CreatedDate DESC
      LIMIT 5000
    ]) {
      String key =
        String.valueOf(record.Book__c) +
        '|' +
        record.Recommendation_Type__c;
      if (!existing.containsKey(key))
        existing.put(key, record);
    }

    Datetime decisionHoldCutoff = System.now().addDays(-DECISION_HOLD_DAYS);
    List<Acquisition_Recommendation__c> toInsert = new List<Acquisition_Recommendation__c>();
    List<Acquisition_Recommendation__c> toUpdate = new List<Acquisition_Recommendation__c>();
    List<Acquisition_Recommendation__c> records = new List<Acquisition_Recommendation__c>();
    List<Book__c> recordBooks = new List<Book__c>();
    List<Signal> recordSignals = new List<Signal>();
    List<Decision> recordDecisions = new List<Decision>();
    // Rules give every book a baseline; Agentforce then generates the
    // recommendation and rationale for the strongest candidates.
    Map<Id, Decision> baselines = new Map<Id, Decision>();
    for (Book__c book : books)
      baselines.put(book.Id, evaluate(signals.get(book.Id), availableOf(book)));
    Map<Id, Decision> generated = generateWithAgentforce(
      books,
      signals,
      baselines
    );
    for (Book__c book : books) {
      Signal signal = signals.get(book.Id);
      Decision decision = generated.containsKey(book.Id)
        ? generated.get(book.Id)
        : baselines.get(book.Id);
      if (decision == null)
        continue;
      String key = String.valueOf(book.Id) + '|' + decision.type;
      Acquisition_Recommendation__c record = existing.get(key);
      Boolean decided =
        record != null &&
        record.Status__c != 'Open' &&
        record.Decided_At__c != null &&
        record.Decided_At__c > decisionHoldCutoff;
      if (!decided) {
        Boolean isNew = record == null;
        if (isNew)
          record = new Acquisition_Recommendation__c(
            Book__c = book.Id,
            Recommendation_Type__c = decision.type
          );
        record.Recommendation_Score__c = decision.score;
        record.Recommended_Quantity__c = decision.quantity;
        record.Confidence__c = decision.confidence;
        record.Evidence__c = decision.evidence;
        record.Status__c = 'Open';
        record.Decision_Notes__c = null;
        record.Decided_At__c = null;
        record.Evidence_Window_Start__c = windowStart;
        record.Evidence_Window_End__c = windowEnd;
        record.Refreshed_At__c = refreshedAt;
        record.Snapshot_Key__c = key;
        if (isNew)
          toInsert.add(record);
        else
          toUpdate.add(record);
      }
      records.add(record);
      recordBooks.add(book);
      recordSignals.add(signal);
      recordDecisions.add(decision);
    }
    if (!toInsert.isEmpty())
      Database.insert(toInsert, AccessLevel.SYSTEM_MODE);
    if (!toUpdate.isEmpty())
      Database.update(toUpdate, AccessLevel.SYSTEM_MODE);

    List<RecommendationDTO> result = new List<RecommendationDTO>();
    for (Integer i = 0; i < records.size(); i++) {
      Book__c book = recordBooks[i];
      Integer available = book.Available_Copies__c == null
        ? 0
        : Integer.valueOf(book.Available_Copies__c);
      result.add(
        toDto(records[i], book, recordSignals[i], available, recordDecisions[i])
      );
    }
    return result;
  }

  // Standard collection-development rules, in priority order:
  //  1. Purchase: hold ratio above target, a patron waiting too long, or a
  //     popular title with an empty shelf.
  //  2. Replace: worn-out or lost copies, but only while the title is still wanted.
  //  3. Weed: established titles nobody has borrowed for a year.
  private static Decision evaluate(Signal signal, Integer available) {
    Integer circulating = signal.circulating;
    Integer copiesBase = Math.max(circulating, 1);
    Decimal holdRatio = Decimal.valueOf(signal.reservations)
      .divide(Decimal.valueOf(copiesBase), 1);
    Decimal turnover = Decimal.valueOf(signal.recentCheckouts)
      .divide(Decimal.valueOf(copiesBase), 1);
    Integer longestWait = signal.oldestHold == null
      ? 0
      : Math.max(signal.oldestHold.date().daysBetween(Date.today()), 0);
    Integer totalHolds = signal.reservations + signal.readyHolds;
    Decision decision = new Decision();
    decision.holdRatio = holdRatio;
    decision.longestWaitDays = longestWait;

    // 1. Purchase
    Integer byRatio = Math.max(
      ceilDiv(signal.reservations, HOLD_RATIO_TARGET) - circulating,
      0
    );
    Integer byWait = signal.reservations > 0 &&
      longestWait >= MAX_WAIT_DAYS
      ? 1
      : 0;
    Integer byTurnover = turnover >= BUSY_LOANS_PER_COPY &&
      available == 0
      ? 1
      : 0;
    // Worn-out or lost copies are replaced (below), not bought as new stock.
    Integer worn = signal.damagedCopies + signal.poorCopies;
    Integer shortfall = Math.max(byRatio, Math.max(byWait, byTurnover));
    Integer buy = Math.min(Math.max(shortfall - worn, 0), MAX_COPIES_PER_ORDER);
    if (buy > 0) {
      decision.type = 'Purchase';
      decision.quantity = buy;
      // Hold pressure first, then how long people have waited, then loan volume.
      decision.score = Math.max(
        1,
        Math.min(
          Math.min(Math.round(holdRatio * 15), 50) +
            Math.min(longestWait / 2, 20) +
            Math.min(Math.round(turnover * 5), 20) +
            (available == 0 ? 10 : 0),
          100
        )
      );
      Integer evidenceCount = signal.reservations + signal.recentCheckouts;
      decision.confidence = evidenceCount >= 8
        ? 'High'
        : evidenceCount >= 3 ? 'Medium' : 'Low';
      decision.estimatedCost = estimate(signal.avgPrice, buy);
      decision.evidence = String.format(
        '{0} holds waiting on {1} lendable {2} ({3}:1, target {4}:1). Longest wait {5} days. {6} loans in {7} days ({8} per copy). {9} on the shelf.{10}',
        new List<String>{
          String.valueOf(signal.reservations),
          String.valueOf(circulating),
          circulating == 1 ? 'copy' : 'copies',
          String.valueOf(holdRatio),
          String.valueOf(HOLD_RATIO_TARGET),
          String.valueOf(longestWait),
          String.valueOf(signal.recentCheckouts),
          String.valueOf(RECENT_DAYS),
          String.valueOf(turnover),
          String.valueOf(available),
          costNote(decision.estimatedCost)
        }
      );
      return decision;
    }

    // 2. Replace: only as many copies as current demand justifies.
    Boolean wanted = signal.reservations > 0 || signal.recentCheckouts > 0;
    if (worn > 0 && wanted) {
      Integer target = Math.max(
        1,
        Math.max(
          ceilDiv(signal.reservations, HOLD_RATIO_TARGET),
          ceilDiv(signal.recentCheckouts, BUSY_LOANS_PER_COPY)
        )
      );
      Integer replace = Math.min(
        worn,
        target - circulating + signal.poorCopies
      );
      if (replace > 0) {
        decision.type = 'Replace';
        decision.quantity = replace;
        decision.score = Math.max(
          1,
          Math.min(
            Math.min(signal.damagedCopies * 25, 50) +
              Math.min(signal.poorCopies * 15, 30) +
              Math.min(signal.reservations * 10, 20),
            100
          )
        );
        Integer evidenceCount =
          worn +
          signal.reservations +
          signal.recentCheckouts;
        decision.confidence = evidenceCount >= 6
          ? 'High'
          : evidenceCount >= 3 ? 'Medium' : 'Low';
        decision.estimatedCost = estimate(signal.avgPrice, replace);
        decision.evidence = String.format(
          '{0} damaged or lost and {1} in poor condition, with {2} lendable. Still in demand: {3} holds waiting, {4} loans in {5} days.{6}',
          new List<String>{
            String.valueOf(signal.damagedCopies),
            String.valueOf(signal.poorCopies),
            String.valueOf(circulating),
            String.valueOf(signal.reservations),
            String.valueOf(signal.recentCheckouts),
            String.valueOf(RECENT_DAYS),
            costNote(decision.estimatedCost)
          }
        );
        return decision;
      }
    }

    // 3. Weed: skip anything new, requested or recently borrowed.
    Boolean established =
      signal.firstAcquired != null &&
      signal.firstAcquired <= Date.today().addYears(-WEED_MIN_YEARS);
    if (
      circulating > 0 &&
      totalHolds == 0 &&
      signal.recentCheckouts == 0 &&
      established
    ) {
      Integer keep = Math.max(1, signal.yearCheckouts);
      Integer surplus = circulating > 1
        ? circulating - keep
        : (signal.yearCheckouts == 0 ? 1 : 0);
      if (surplus > 0) {
        decision.type = 'Weed';
        decision.quantity = surplus;
        decision.score = Math.max(
          1,
          Math.min(
            20 +
              (signal.yearCheckouts == 0 ? 30 : 0) +
              Math.min(surplus * 10, 30),
            100
          )
        );
        decision.confidence = signal.firstAcquired <= Date.today().addYears(-4)
          ? 'High'
          : 'Medium';
        decision.evidence = String.format(
          '{0} loans in 12 months across {1} {2}, none in the last {3} days, no holds. Held since {4}. Review condition before withdrawing {5}.',
          new List<String>{
            String.valueOf(signal.yearCheckouts),
            String.valueOf(circulating),
            circulating == 1 ? 'copy' : 'copies',
            String.valueOf(RECENT_DAYS),
            signal.firstAcquired.format(),
            surplus == 1 ? '1 copy' : String.valueOf(surplus) + ' copies'
          }
        );
        return decision;
      }
    }
    return null;
  }

  // ---- Agentforce generation -------------------------------------------
  // The prompt template reads each candidate's signals and returns the
  // decision and a written rationale. Hard rules below still apply to its
  // answer, and the rule-based evaluate() is the fallback for any book the
  // model skips or gets wrong, or for the whole run if the call fails.

  private static Integer availableOf(Book__c book) {
    return book.Available_Copies__c == null
      ? 0
      : Integer.valueOf(book.Available_Copies__c);
  }

  private static Boolean isEstablished(Signal signal) {
    return signal.firstAcquired != null &&
      signal.firstAcquired <= Date.today().addYears(-WEED_MIN_YEARS);
  }

  private static Map<Id, Decision> generateWithAgentforce(
    List<Book__c> books,
    Map<Id, Signal> signals,
    Map<Id, Decision> baselines
  ) {
    Map<Id, Decision> generated = new Map<Id, Decision>();
    if (Test.isRunningTest() && testAiResponse == null)
      return generated;
    // Send the strongest candidates only, to keep the prompt small.
    List<Book__c> candidates = new List<Book__c>();
    for (Book__c book : books) {
      Signal s = signals.get(book.Id);
      if (
        baselines.get(book.Id) != null ||
        s.reservations > 0 ||
        s.damagedCopies + s.poorCopies > 0 ||
        s.recentCheckouts >= BUSY_LOANS_PER_COPY
      )
        candidates.add(book);
    }
    if (candidates.isEmpty())
      return generated;
    candidates.sort(new CandidateOrder(baselines));
    while (candidates.size() > AI_MAX_BOOKS)
      candidates.remove(candidates.size() - 1);
    Map<Id, Book__c> byId = new Map<Id, Book__c>(candidates);

    List<Object> payload = new List<Object>();
    for (Book__c book : candidates) {
      Signal s = signals.get(book.Id);
      payload.add(
        new Map<String, Object>{
          'bookId' => book.Id,
          'title' => book.Name,
          'holdsWaiting' => s.reservations,
          'holdsReadyForPickup' => s.readyHolds,
          'longestWaitDays' => s.oldestHold == null
            ? 0
            : Math.max(s.oldestHold.date().daysBetween(Date.today()), 0),
          'lendableCopies' => s.circulating,
          'availableOnShelf' => availableOf(book),
          'loansLast90Days' => s.recentCheckouts,
          'loansLast12Months' => s.yearCheckouts,
          'damagedOrLostCopies' => s.damagedCopies,
          'poorConditionCopies' => s.poorCopies,
          'copiesOlderThan5Years' => s.agingCopies,
          'averageCopyPrice' => s.avgPrice,
          'firstAcquired' => s.firstAcquired == null
            ? null
            : String.valueOf(s.firstAcquired)
        }
      );
    }

    String raw;
    try {
      raw = callPromptTemplate(JSON.serialize(payload));
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'Agentforce acquisition advisor unavailable: ' + e.getMessage()
      );
      return generated;
    }
    for (Object item : parseAnswers(raw)) {
      if (!(item instanceof Map<String, Object>))
        continue;
      Map<String, Object> answer = (Map<String, Object>) item;
      Id bookId;
      try {
        bookId = (Id) String.valueOf(answer.get('bookId'));
      } catch (Exception e) {
        continue;
      }
      if (!byId.containsKey(bookId) || generated.containsKey(bookId))
        continue;
      String type = String.valueOf(answer.get('type'));
      if (type == 'None') {
        generated.put(bookId, null);
        continue;
      }
      Decision decision = validated(answer, type, signals.get(bookId));
      if (decision != null)
        generated.put(bookId, decision);
    }
    return generated;
  }

  private static String callPromptTemplate(String signalsJson) {
    if (testAiResponse != null)
      return testAiResponse;
    ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
    wrapped.value = signalsJson;
    ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    input.isPreview = false;
    input.inputParams = new Map<String, ConnectApi.WrappedValue>{
      'Input:signals' => wrapped
    };
    input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
    input.additionalConfig.applicationName = 'PromptBuilderPreview';
    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
      PROMPT_TEMPLATE,
      input
    );
    if (
      output == null ||
      output.generations == null ||
      output.generations.isEmpty()
    )
      throw new AcquisitionAdvisorException(
        'The prompt template returned nothing.'
      );
    return output.generations[0].text;
  }

  private static List<Object> parseAnswers(String raw) {
    if (String.isBlank(raw))
      return new List<Object>();
    String text = raw.trim();
    if (text.startsWith('```')) {
      text = text.substringAfter('\n');
      if (text.endsWith('```'))
        text = text.substringBeforeLast('```');
    }
    try {
      Object parsed = JSON.deserializeUntyped(text.trim());
      if (parsed instanceof List<Object>)
        return (List<Object>) parsed;
      if (parsed instanceof Map<String, Object>) {
        Object recs = ((Map<String, Object>) parsed).get('recommendations');
        if (recs instanceof List<Object>)
          return (List<Object>) recs;
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'Unreadable advisor output.');
    }
    return new List<Object>();
  }

  // Accept the model's answer only if it respects the library's hard rules.
  private static Decision validated(
    Map<String, Object> answer,
    String type,
    Signal signal
  ) {
    Integer quantity;
    Integer score;
    try {
      quantity = Integer.valueOf(answer.get('quantity'));
      score = Integer.valueOf(answer.get('score'));
    } catch (Exception e) {
      return null;
    }
    if (quantity == null || quantity < 1)
      return null;
    Integer worn = signal.damagedCopies + signal.poorCopies;
    Integer holds = signal.reservations + signal.readyHolds;
    Boolean wanted = signal.reservations > 0 || signal.recentCheckouts > 0;
    if (type == 'Purchase') {
      if (!wanted)
        return null;
      quantity = Math.min(quantity, MAX_COPIES_PER_ORDER);
    } else if (type == 'Replace') {
      if (worn == 0 || !wanted)
        return null;
      quantity = Math.min(quantity, worn);
    } else if (type == 'Weed') {
      if (
        signal.circulating == 0 ||
        holds > 0 ||
        signal.recentCheckouts > 0 ||
        !isEstablished(signal)
      )
        return null;
      quantity = Math.min(quantity, signal.circulating);
    } else {
      return null;
    }
    String confidence = String.valueOf(answer.get('confidence'));
    if (confidence != 'High' && confidence != 'Medium' && confidence != 'Low')
      confidence = 'Medium';
    String rationale = String.valueOf(answer.get('rationale'));
    if (String.isBlank(rationale) || rationale == 'null')
      return null;

    Decision decision = newDecision(signal);
    decision.type = type;
    decision.quantity = quantity;
    decision.score = Math.max(1, Math.min(score == null ? 50 : score, 100));
    decision.confidence = confidence;
    decision.estimatedCost = type == 'Weed'
      ? null
      : estimate(signal.avgPrice, quantity);
    decision.evidence =
      rationale.trim().left(1000) + costNote(decision.estimatedCost);
    decision.generatedBy = 'Agentforce';
    return decision;
  }

  private static Decision newDecision(Signal signal) {
    Decision decision = new Decision();
    decision.holdRatio = Decimal.valueOf(signal.reservations)
      .divide(Decimal.valueOf(Math.max(signal.circulating, 1)), 1);
    decision.longestWaitDays = signal.oldestHold == null
      ? 0
      : Math.max(signal.oldestHold.date().daysBetween(Date.today()), 0);
    decision.generatedBy = 'Rules';
    return decision;
  }

  private class CandidateOrder implements System.Comparator<Book__c> {
    private Map<Id, Decision> baselines;
    CandidateOrder(Map<Id, Decision> baselines) {
      this.baselines = baselines;
    }
    public Integer compare(Book__c a, Book__c b) {
      Decision da = baselines.get(a.Id);
      Decision db = baselines.get(b.Id);
      Integer sa = da == null ? 0 : da.score;
      Integer sb = db == null ? 0 : db.score;
      return sb - sa;
    }
  }

  private static Integer ceilDiv(Integer value, Integer divisor) {
    return (value + divisor - 1) / divisor;
  }

  private static Decimal estimate(Decimal unitPrice, Integer quantity) {
    return unitPrice == null ||
      unitPrice <= 0
      ? null
      : (unitPrice * quantity).setScale(2);
  }

  private static String costNote(Decimal cost) {
    return cost == null
      ? ''
      : ' Estimated cost about ' + String.valueOf(cost) + '.';
  }

  public static Acquisition_Recommendation__c decide(
    Id recommendationId,
    String status,
    String notes
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Set<String> allowed = new Set<String>{
      'Accepted',
      'Rejected',
      'Deferred',
      'Open'
    };
    if (recommendationId == null || !allowed.contains(status))
      throw new AuraHandledException(
        'A valid recommendation and decision are required.'
      );
    List<Acquisition_Recommendation__c> found = [
      SELECT Id, Status__c, Decision_Notes__c, Decided_At__c
      FROM Acquisition_Recommendation__c
      WHERE Id = :recommendationId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (found.isEmpty())
      throw new AuraHandledException('The recommendation could not be found.');
    Acquisition_Recommendation__c record = found[0];
    Boolean reopening = status == 'Open';
    record.Status__c = status;
    record.Decision_Notes__c = reopening || String.isBlank(notes)
      ? null
      : notes.trim().left(32768);
    record.Decided_At__c = reopening ? null : System.now();
    Database.update(record, AccessLevel.SYSTEM_MODE);
    return record;
  }

  public static void recordSearchTelemetry(
    String searchTerm,
    Integer resultCount,
    Id bookId
  ) {
    if (String.isBlank(searchTerm))
      return;
    String normalized = searchTerm.trim().toLowerCase();
    Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(normalized));
    String hash = EncodingUtil.convertToHex(digest);
    Search_Analytics__c event = new Search_Analytics__c(
      Search_Hash__c = hash,
      Search_Result_Count__c = resultCount == null ||
        resultCount < 0
        ? 0
        : resultCount,
      Search_Status__c = resultCount == null ||
        resultCount == 0
        ? 'Zero Results'
        : 'Results',
      Searched_At__c = System.now(),
      Book__c = bookId
    );
    Database.insert(event, AccessLevel.SYSTEM_MODE);
  }

  private static RecommendationDTO toDto(
    Acquisition_Recommendation__c record,
    Book__c book,
    Signal signal,
    Integer available,
    Decision decision
  ) {
    RecommendationDTO dto = new RecommendationDTO();
    dto.id = record.Id;
    dto.bookId = book.Id;
    dto.bookTitle = book.Name;
    dto.recommendationType = record.Recommendation_Type__c;
    dto.score = record.Recommendation_Score__c;
    dto.confidence = record.Confidence__c;
    dto.evidence = record.Evidence__c;
    dto.recommendedQuantity = record.Recommended_Quantity__c == null
      ? null
      : Integer.valueOf(record.Recommended_Quantity__c);
    dto.status = record.Status__c;
    dto.evidenceWindowStart = record.Evidence_Window_Start__c;
    dto.evidenceWindowEnd = record.Evidence_Window_End__c;
    dto.refreshedAt = record.Refreshed_At__c;
    dto.reservations = signal.reservations;
    dto.availableCopies = available;
    dto.recentCheckouts = signal.recentCheckouts;
    dto.damagedCopies = signal.damagedCopies;
    dto.agingCopies = signal.agingCopies;
    dto.insufficientEvidence = false;
    dto.decisionNotes = record.Decision_Notes__c;
    dto.circulatingCopies = signal.circulating;
    dto.poorCopies = signal.poorCopies;
    dto.yearCheckouts = signal.yearCheckouts;
    dto.holdRatio = decision.holdRatio;
    dto.longestWaitDays = decision.longestWaitDays;
    dto.estimatedCost = decision.estimatedCost;
    dto.generatedBy = decision.generatedBy;
    return dto;
  }
}
