public without sharing class LibraryAgentLibrarianWriteService {
  // Librarian writes made through the agent are always two steps. prepare()
  // resolves and validates everything, saves nothing except a short-lived
  // confirmation row, and returns a preview. commit() only runs the exact
  // payload that was previewed, once, after the librarian answered separately.
  public static final String UPDATE_MEMBER = 'UPDATE_MEMBER';
  public static final String UPDATE_BOOK = 'UPDATE_BOOK';
  public static final String BORROW_FOR_MEMBER = 'BORROW_FOR_MEMBER';
  public static final String RESERVE_FOR_MEMBER = 'RESERVE_FOR_MEMBER';
  public static final String APPROVE_BORROW = 'APPROVE_BORROW';
  private static final String PREFIX = 'LIB_';
  private static final Set<String> SUPPORTED = new Set<String>{
    UPDATE_MEMBER,
    UPDATE_BOOK,
    BORROW_FOR_MEMBER,
    RESERVE_FOR_MEMBER,
    APPROVE_BORROW
  };
  private static final String SCRIPT_THROWN = 'Script-thrown exception';

  @TestVisible
  private static Integer minConfirmDelaySeconds = Test.isRunningTest() ? 0 : 3;

  public class WriteRequest {
    public String action;
    public String memberLookup;
    public String bookLookup;
    public String loanId;
    public String firstName;
    public String lastName;
    public String email;
    public String phone;
    public String title;
    public String publisher;
    public String edition;
    public String language;
    public String description;
  }

  public class PreviewResult {
    public String token;
    public String preview;
  }

  public class CommitResult {
    public Id recordId;
    public String message;
  }

  // ---- step 1 ----

  public static PreviewResult prepare(WriteRequest request) {
    String operation = normalize(request == null ? null : request.action);
    LibraryPolicyService.require('Manage_Library_Circulation');
    if (operation == UPDATE_BOOK)
      LibraryPolicyService.require('Manage_Library_Catalog');

    Map<String, Object> payload = new Map<String, Object>();
    String previewText;
    Id memberId;
    Id targetId;
    if (operation == UPDATE_MEMBER) {
      Member__c member = resolveMember(request.memberLookup);
      memberId = member.Id;
      targetId = member.Id;
      previewText = previewMemberEdit(request, member, payload);
    } else if (operation == UPDATE_BOOK) {
      Book__c book = resolveBook(request.bookLookup);
      targetId = book.Id;
      previewText = previewBookEdit(request, book, payload);
    } else if (operation == BORROW_FOR_MEMBER) {
      Member__c member = resolveMember(request.memberLookup);
      Book__c book = resolveBook(request.bookLookup);
      memberId = member.Id;
      targetId = book.Id;
      previewText = previewBorrow(member, book, payload);
    } else if (operation == RESERVE_FOR_MEMBER) {
      Member__c member = resolveMember(request.memberLookup);
      Book__c book = resolveBook(request.bookLookup);
      memberId = member.Id;
      targetId = book.Id;
      previewText = previewReservation(member, book, payload);
    } else {
      Borrow_Record__c loan = resolvePendingLoan(request);
      memberId = loan.Member__c;
      targetId = loan.Id;
      previewText =
        'Approve the borrowing request from ' +
        displayName(loan.Member__r) +
        ' for "' +
        loan.Book_Copy__r.Book__r.Name +
        '". The book will be checked out to them and they will be notified.';
      payload.put('loanId', loan.Id);
    }

    String rawToken = EncodingUtil.convertToHex(
      Crypto.generateDigest(
        'SHA-256',
        Blob.valueOf(
          UserInfo.getOrganizationId() +
            ':' +
            UserInfo.getUserId() +
            ':' +
            Datetime.now().getTime() +
            ':' +
            Crypto.getRandomInteger()
        )
      )
    );
    String json = JSON.serialize(payload);
    Datetime now = System.now();
    Database.insert(
      new Agent_Confirmation__c(
        Action__c = PREFIX + operation,
        Token_Hash__c = hash(rawToken),
        Parameter_Hash__c = binding(operation, json),
        Idempotency_Key__c = String.valueOf(UserInfo.getUserId()),
        Status__c = 'Pending',
        Member__c = memberId,
        Target_Record__c = String.valueOf(targetId),
        Preview__c = previewText,
        Payload__c = json,
        Created_At__c = now,
        Expires_At__c = now.addMinutes(5)
      ),
      AccessLevel.SYSTEM_MODE
    );
    PreviewResult result = new PreviewResult();
    result.token = rawToken;
    result.preview = previewText;
    return result;
  }

  // ---- step 2 ----

  public static CommitResult commitChange(String token) {
    LibraryPolicyService.require('Manage_Library_Circulation');
    Agent_Confirmation__c confirmation = loadConfirmation(token);
    String operation = confirmation.Action__c.removeStart(PREFIX);
    if (
      !SUPPORTED.contains(operation) ||
      confirmation.Parameter_Hash__c !=
      binding(operation, confirmation.Payload__c)
    )
      throw fail('This confirmation is not valid. Prepare it again.');
    if (operation == UPDATE_BOOK)
      LibraryPolicyService.require('Manage_Library_Catalog');
    if (
      confirmation.Status__c != 'Pending' ||
      confirmation.Expires_At__c == null ||
      confirmation.Expires_At__c <= System.now()
    )
      throw fail('This confirmation has expired or was already used.');
    if (
      confirmation.Created_At__c.addSeconds(minConfirmDelaySeconds) >
      System.now()
    )
      throw fail(
        'Please wait for the librarian to confirm in their own message before committing.'
      );

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      confirmation.Payload__c
    );
    Savepoint checkpoint = Database.setSavepoint();
    try {
      confirmation.Status__c = 'Used';
      confirmation.Used_At__c = System.now();
      Database.update(confirmation, AccessLevel.SYSTEM_MODE);
      CommitResult result = new CommitResult();
      if (operation == UPDATE_MEMBER) {
        Id memberId = (Id) payload.get('memberId');
        LibraryLibrarianController.updateMember(
          memberId,
          (String) payload.get('firstName'),
          (String) payload.get('lastName'),
          (String) payload.get('email'),
          (String) payload.get('phone'),
          (Id) payload.get('planId')
        );
        result.recordId = memberId;
        result.message = 'The member details were updated.';
      } else if (operation == UPDATE_BOOK) {
        Id bookId = (Id) payload.get('bookId');
        LibraryCatalogService.updateBook(
          bookId,
          (String) payload.get('title'),
          (String) payload.get('isbn'),
          (String) payload.get('publisher'),
          (Decimal) decimalOrNull(payload.get('publicationYear')),
          (String) payload.get('edition'),
          (String) payload.get('language'),
          (String) payload.get('description'),
          (String) payload.get('coverUrl'),
          idList(payload.get('authorIds')),
          idList(payload.get('categoryIds'))
        );
        result.recordId = bookId;
        result.message = 'The book details were updated.';
      } else if (operation == BORROW_FOR_MEMBER) {
        Id copyId = firstAvailableCopy((Id) payload.get('bookId'));
        result.recordId = LibraryCirculationService.checkout(
          (Id) payload.get('memberId'),
          copyId
        );
        result.message = 'The book was checked out to the member.';
      } else if (operation == RESERVE_FOR_MEMBER) {
        result.recordId = LibraryLibrarianController.createReservation(
          (Id) payload.get('memberId'),
          (Id) payload.get('bookId')
        );
        result.message = 'The reservation was placed and the member is in the queue.';
      } else {
        Id loanId = (Id) payload.get('loanId');
        LibraryCirculationService.approveBorrowRequest(loanId);
        result.recordId = loanId;
        result.message = 'The borrowing request was approved and the book is checked out to the member.';
      }
      return result;
    } catch (Exception error) {
      // Leave the confirmation usable until it expires if the write failed.
      Database.rollback(checkpoint);
      String reason = readable(error);
      throw fail(
        reason == null
          ? 'That could not be completed right now. It may no longer be possible, so prepare it again.'
          : reason
      );
    }
  }

  // ---- previews ----

  private static String previewMemberEdit(
    WriteRequest request,
    Member__c member,
    Map<String, Object> payload
  ) {
    String firstName = pick(request.firstName, member.First_Name__c);
    String lastName = pick(request.lastName, member.Last_Name__c);
    String email = pick(request.email, member.Email__c);
    String phone = pick(request.phone, member.Phone__c);
    if (String.isBlank(firstName) || String.isBlank(lastName))
      throw fail('A member needs a first and last name.');
    if (String.isBlank(email) || !email.contains('@'))
      throw fail('A valid email address is required.');
    if (member.Membership_Plan__c == null)
      throw fail(
        'This member has no membership plan, so edit it in the workspace.'
      );
    List<String> changes = new List<String>();
    addChange(changes, 'first name', member.First_Name__c, firstName);
    addChange(changes, 'last name', member.Last_Name__c, lastName);
    addChange(changes, 'email', member.Email__c, email);
    addChange(changes, 'phone', member.Phone__c, phone);
    if (changes.isEmpty())
      throw fail('Nothing would change. Those details already match.');
    payload.put('memberId', member.Id);
    payload.put('firstName', firstName);
    payload.put('lastName', lastName);
    payload.put('email', email);
    payload.put('phone', phone);
    payload.put('planId', member.Membership_Plan__c);
    return 'Update ' +
      displayName(member) +
      ': ' +
      String.join(changes, '; ') +
      '.';
  }

  private static String previewBookEdit(
    WriteRequest request,
    Book__c book,
    Map<String, Object> payload
  ) {
    String title = pick(request.title, book.Name);
    String publisher = pick(request.publisher, book.Publisher__c);
    String edition = pick(request.edition, book.Edition__c);
    String language = pick(request.language, book.Language__c);
    String description = pick(request.description, book.Description__c);
    List<String> changes = new List<String>();
    addChange(changes, 'title', book.Name, title);
    addChange(changes, 'publisher', book.Publisher__c, publisher);
    addChange(changes, 'edition', book.Edition__c, edition);
    addChange(changes, 'language', book.Language__c, language);
    addChange(changes, 'description', book.Description__c, description);
    if (changes.isEmpty())
      throw fail('Nothing would change. Those details already match.');
    List<Id> authorIds = new List<Id>();
    for (Book_Author__c link : [
      SELECT Author__c
      FROM Book_Author__c
      WHERE Book__c = :book.Id
      WITH SYSTEM_MODE
    ])
      authorIds.add(link.Author__c);
    List<Id> categoryIds = new List<Id>();
    for (Book_Category_Link__c link : [
      SELECT Book_Category__c
      FROM Book_Category_Link__c
      WHERE Book__c = :book.Id
      WITH SYSTEM_MODE
    ])
      categoryIds.add(link.Book_Category__c);
    payload.put('bookId', book.Id);
    payload.put('title', title);
    payload.put('isbn', book.ISBN__c);
    payload.put('publisher', publisher);
    payload.put('publicationYear', book.Publication_Year__c);
    payload.put('edition', edition);
    payload.put('language', language);
    payload.put('description', description);
    payload.put('coverUrl', book.Cover_Image_URL__c);
    payload.put('authorIds', authorIds);
    payload.put('categoryIds', categoryIds);
    return 'Update the book "' +
      book.Name +
      '": ' +
      String.join(changes, '; ') +
      '. Authors, categories and ISBN stay as they are.';
  }

  private static String previewBorrow(
    Member__c member,
    Book__c book,
    Map<String, Object> payload
  ) {
    if (member.Status__c != 'Active')
      throw fail(displayName(member) + ' does not have an active membership.');
    if (firstAvailableCopyOrNull(book.Id) == null)
      throw fail(
        'No copy of "' +
          book.Name +
          '" is available to check out right now. It can be reserved for the member instead.'
      );
    payload.put('memberId', member.Id);
    payload.put('bookId', book.Id);
    return 'Check out "' +
      book.Name +
      '" to ' +
      displayName(member) +
      ' now, using the loan period of their membership plan. This is an immediate checkout, with no separate approval step.';
  }

  private static String previewReservation(
    Member__c member,
    Book__c book,
    Map<String, Object> payload
  ) {
    if (member.Status__c != 'Active')
      throw fail(displayName(member) + ' does not have an active membership.');
    if (
      [
        SELECT COUNT()
        FROM Reservation__c
        WHERE
          Member__c = :member.Id
          AND Book__c = :book.Id
          AND Status__c IN ('Pending', 'Ready')
        WITH SYSTEM_MODE
      ] > 0
    )
      throw fail(
        displayName(member) +
          ' already has a reservation for "' +
          book.Name +
          '".'
      );
    payload.put('memberId', member.Id);
    payload.put('bookId', book.Id);
    return 'Reserve "' +
      book.Name +
      '" for ' +
      displayName(member) +
      ' and add them to the queue.';
  }

  // ---- lookups ----

  private static Member__c resolveMember(String lookup) {
    if (String.isBlank(lookup))
      throw fail('Which member? A name, member number or email is required.');
    String needle = lookup.trim();
    Id memberId;
    try {
      memberId = (Id) needle;
    } catch (Exception ignored) {
    }
    List<Member__c> found;
    if (
      memberId != null &&
      memberId.getSobjectType() == Member__c.SObjectType
    ) {
      found = [
        SELECT
          Id,
          Name,
          First_Name__c,
          Last_Name__c,
          Email__c,
          Phone__c,
          Status__c,
          Membership_Plan__c
        FROM Member__c
        WHERE Id = :memberId
        WITH SYSTEM_MODE
        LIMIT 1
      ];
    } else {
      List<String> parts = needle.split('\\s+');
      String first = parts[0];
      String last = parts[parts.size() - 1];
      String normalized = needle.toLowerCase();
      if (parts.size() > 1) {
        found = [
          SELECT
            Id,
            Name,
            First_Name__c,
            Last_Name__c,
            Email__c,
            Phone__c,
            Status__c,
            Membership_Plan__c
          FROM Member__c
          WHERE
            Name = :needle
            OR Normalized_Email__c = :normalized
            OR (First_Name__c = :first
            AND Last_Name__c = :last)
          WITH SYSTEM_MODE
          ORDER BY Name
          LIMIT 6
        ];
      } else {
        found = [
          SELECT
            Id,
            Name,
            First_Name__c,
            Last_Name__c,
            Email__c,
            Phone__c,
            Status__c,
            Membership_Plan__c
          FROM Member__c
          WHERE
            Name = :needle
            OR Normalized_Email__c = :normalized
            OR First_Name__c = :needle
            OR Last_Name__c = :needle
          WITH SYSTEM_MODE
          ORDER BY Name
          LIMIT 6
        ];
      }
    }
    if (found.isEmpty())
      throw fail('No member matches "' + needle + '".');
    if (found.size() > 1) {
      List<String> names = new List<String>();
      for (Member__c candidate : found)
        names.add(displayName(candidate) + ' <' + candidate.Email__c + '>');
      throw fail(
        'Several members match: ' +
          String.join(names, ', ') +
          '. Ask which one.'
      );
    }
    return found[0];
  }

  private static Book__c resolveBook(String lookup) {
    if (String.isBlank(lookup))
      throw fail('Which book? A title or ISBN is required.');
    String needle = lookup.trim();
    Id bookId;
    try {
      bookId = (Id) needle;
    } catch (Exception ignored) {
    }
    String pattern = '%' + String.escapeSingleQuotes(needle) + '%';
    List<Book__c> matches = [
      SELECT
        Id,
        Name,
        ISBN__c,
        Publisher__c,
        Publication_Year__c,
        Edition__c,
        Language__c,
        Description__c,
        Cover_Image_URL__c
      FROM Book__c
      WHERE
        Id = :bookId
        OR Name = :needle
        OR ISBN__c = :needle
        OR Name LIKE :pattern
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 6
    ];
    if (matches.isEmpty())
      throw fail('No book in the catalog matches "' + needle + '".');
    for (Book__c candidate : matches) {
      if (candidate.Id == bookId || candidate.Name.equalsIgnoreCase(needle))
        return candidate;
    }
    if (matches.size() == 1)
      return matches[0];
    List<String> names = new List<String>();
    for (Book__c candidate : matches)
      names.add('"' + candidate.Name + '"');
    throw fail(
      'Several books match: ' + String.join(names, ', ') + '. Ask which one.'
    );
  }

  private static Borrow_Record__c resolvePendingLoan(WriteRequest request) {
    List<Borrow_Record__c> pending;
    Id loanId;
    if (!String.isBlank(request.loanId)) {
      try {
        loanId = (Id) request.loanId.trim();
      } catch (Exception ignored) {
        throw fail('That is not a valid borrowing request id.');
      }
    }
    Id memberId = String.isBlank(request.memberLookup)
      ? null
      : resolveMember(request.memberLookup).Id;
    String needle = String.isBlank(request.bookLookup)
      ? null
      : request.bookLookup.trim();
    pending = new List<Borrow_Record__c>();
    for (Borrow_Record__c row : [
      SELECT
        Id,
        Member__c,
        Member__r.Name,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Book_Copy__r.Book__r.Name
      FROM Borrow_Record__c
      WHERE Status__c = 'Pending'
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
      LIMIT 200
    ]) {
      if (loanId != null && row.Id != loanId)
        continue;
      if (memberId != null && row.Member__c != memberId)
        continue;
      if (
        needle != null &&
        !row.Book_Copy__r.Book__r.Name.containsIgnoreCase(needle)
      )
        continue;
      pending.add(row);
    }
    if (pending.size() == 1)
      return pending[0];
    if (pending.isEmpty())
      throw fail('No pending borrowing request matches.');
    List<String> rows = new List<String>();
    for (Borrow_Record__c row : pending)
      rows.add(
        displayName(row.Member__r) +
          ' - "' +
          row.Book_Copy__r.Book__r.Name +
          '"'
      );
    throw fail(
      'Several borrowing requests are pending: ' +
        String.join(rows, ', ') +
        '. Ask which member and book.'
    );
  }

  private static Id firstAvailableCopy(Id bookId) {
    Id copyId = firstAvailableCopyOrNull(bookId);
    if (copyId == null)
      throw fail('No copy is available to check out right now.');
    return copyId;
  }

  private static Id firstAvailableCopyOrNull(Id bookId) {
    List<Book_Copy__c> copies = [
      SELECT Id
      FROM Book_Copy__c
      WHERE Book__c = :bookId AND Status__c = 'Available'
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 1
    ];
    return copies.isEmpty() ? null : copies[0].Id;
  }

  private static Agent_Confirmation__c loadConfirmation(String token) {
    String owner = String.valueOf(UserInfo.getUserId());
    List<String> actionNames = new List<String>();
    for (String name : SUPPORTED)
      actionNames.add(PREFIX + name);
    List<Agent_Confirmation__c> latest;
    if (String.isBlank(token)) {
      Datetime freshAfter = System.now().addMinutes(-5);
      latest = [
        SELECT Id
        FROM Agent_Confirmation__c
        WHERE
          Idempotency_Key__c = :owner
          AND Action__c IN :actionNames
          AND Status__c = 'Pending'
          AND Created_At__c > :freshAfter
        WITH SYSTEM_MODE
        ORDER BY Created_At__c DESC, Id DESC
        LIMIT 1
      ];
      if (latest.isEmpty())
        throw fail(
          'Nothing is waiting for confirmation. Prepare the request again first.'
        );
    } else {
      String tokenHash = hash(token.trim());
      latest = [
        SELECT Id
        FROM Agent_Confirmation__c
        WHERE
          Token_Hash__c = :tokenHash
          AND Idempotency_Key__c = :owner
          AND Action__c IN :actionNames
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (latest.isEmpty())
        throw fail('That confirmation was not found. Prepare it again.');
    }
    Id rowId = latest[0].Id;
    return [
      SELECT
        Id,
        Action__c,
        Status__c,
        Parameter_Hash__c,
        Payload__c,
        Created_At__c,
        Expires_At__c,
        Used_At__c
      FROM Agent_Confirmation__c
      WHERE Id = :rowId
      WITH SYSTEM_MODE
      LIMIT 1
      FOR UPDATE
    ];
  }

  // ---- helpers ----

  private static String normalize(String action) {
    String value = action == null ? '' : action.trim().toUpperCase();
    if (!SUPPORTED.contains(value))
      throw fail(
        'That librarian action is not enabled. Supported: UPDATE_MEMBER, UPDATE_BOOK, BORROW_FOR_MEMBER, RESERVE_FOR_MEMBER, APPROVE_BORROW.'
      );
    return value;
  }

  private static String pick(String requested, String current) {
    return String.isBlank(requested) ? current : requested.trim();
  }

  private static void addChange(
    List<String> changes,
    String label,
    String before,
    String after
  ) {
    String left = before == null ? '' : before;
    String right = after == null ? '' : after;
    if (left == right)
      return;
    changes.add(
      label +
        ' from "' +
        (left == '' ? 'blank' : left.abbreviate(80)) +
        '" to "' +
        (right == '' ? 'blank' : right.abbreviate(80)) +
        '"'
    );
  }

  private static String displayName(Member__c member) {
    if (member == null)
      return 'the member';
    String full = ((member.First_Name__c == null ? '' : member.First_Name__c) +
      ' ' +
      (member.Last_Name__c == null ? '' : member.Last_Name__c))
      .trim();
    return String.isBlank(full) ? member.Name : full + ' (' + member.Name + ')';
  }

  private static Decimal decimalOrNull(Object value) {
    return value == null ? null : Decimal.valueOf(String.valueOf(value));
  }

  private static List<Id> idList(Object value) {
    List<Id> ids = new List<Id>();
    if (value == null)
      return ids;
    for (Object item : (List<Object>) value)
      ids.add((Id) String.valueOf(item));
    return ids;
  }

  private static String binding(String operation, String json) {
    return hash(UserInfo.getUserId() + ':' + operation + ':' + json);
  }

  private static String hash(String value) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(value))
    );
  }

  // AuraHandledException hides its text unless setMessage is called.
  private static AuraHandledException fail(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }

  private static String readable(Exception error) {
    String message = error.getMessage();
    return String.isBlank(message) || message == SCRIPT_THROWN ? null : message;
  }
}
