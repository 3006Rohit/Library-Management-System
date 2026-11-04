public without sharing class LibraryAgentConfirmationService {
  // Confirmation records bind a one-time token to the authenticated member,
  // the action and its exact details. Nothing is written until the member
  // confirms and the token is presented in a separate step.
  public static final String RENEW_LOAN = 'RENEW_LOAN';
  public static final String CANCEL_RESERVATION = 'CANCEL_RESERVATION';
  public static final String BORROW_BOOK = 'BORROW_BOOK';
  public static final String RESERVE_BOOK = 'RESERVE_BOOK';
  public static final String BOOK_ROOM = 'BOOK_ROOM';
  private static final Set<String> SUPPORTED = new Set<String>{
    RENEW_LOAN,
    CANCEL_RESERVATION,
    BORROW_BOOK,
    RESERVE_BOOK,
    BOOK_ROOM
  };
  private static final String SCRIPT_THROWN = 'Script-thrown exception';

  // A commit is refused for the first seconds after the preview so the
  // assistant cannot preview and confirm in the same breath; the member must
  // answer in a separate message.
  @TestVisible
  private static Integer minConfirmDelaySeconds = Test.isRunningTest() ? 0 : 3;

  public class PreviewDTO {
    @AuraEnabled
    public String token;
    @AuraEnabled
    public String action;
    @AuraEnabled
    public Id targetId;
    @AuraEnabled
    public String preview;
    @AuraEnabled
    public Datetime expiresAt;
  }

  public class PreviewRequest {
    public String sessionToken;
    public String action;
    public Id targetId;
    public String targetName;
    public Integer seatNumber;
    public String startTime;
    public Integer durationHours;
    public String purpose;
  }

  public class CommitResult {
    public Id recordId;
    public String message;
  }

  public static PreviewDTO preview(
    String sessionToken,
    String action,
    Id targetId
  ) {
    PreviewRequest request = new PreviewRequest();
    request.sessionToken = sessionToken;
    request.action = action;
    request.targetId = targetId;
    return preview(request);
  }

  public static PreviewDTO preview(PreviewRequest request) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      request.sessionToken
    );
    String normalizedAction = normalizeAction(request.action);
    Id targetId = request.targetId;
    String previewText;
    String extra;
    if (
      normalizedAction == RENEW_LOAN ||
      normalizedAction == CANCEL_RESERVATION
    ) {
      if (targetId == null)
        throw fail('A target record is required.');
      previewText = normalizedAction == RENEW_LOAN
        ? previewRenewal(targetId, member)
        : previewCancellation(targetId, member);
    } else if (
      normalizedAction == BORROW_BOOK ||
      normalizedAction == RESERVE_BOOK
    ) {
      Book__c book = resolveBook(request.targetId, request.targetName);
      targetId = book.Id;
      previewText = normalizedAction == BORROW_BOOK
        ? previewBorrow(book, member)
        : previewReservation(book, member);
    } else {
      Map<String, Object> room = previewRoom(request);
      targetId = (Id) room.get('roomId');
      previewText = (String) room.get('text');
      extra = JSON.serialize(room.get('booking'));
    }

    String rawToken = EncodingUtil.convertToHex(
      Crypto.generateDigest(
        'SHA-256',
        Blob.valueOf(
          UserInfo.getOrganizationId() +
            ':' +
            member.Id +
            ':' +
            Datetime.now().getTime() +
            ':' +
            Crypto.getRandomInteger()
        )
      )
    );
    String encodedExtra = extra == null
      ? null
      : EncodingUtil.base64Encode(Blob.valueOf(extra));
    Datetime expires = System.now().addMinutes(5);
    Library_Scan_Transaction__c confirmation = new Library_Scan_Transaction__c(
      Member__c = member.Id,
      Operation__c = normalizedAction,
      Borrow_Record__c = normalizedAction == RENEW_LOAN ? targetId : null,
      Idempotency_Key__c = hash(rawToken),
      Status__c = 'Pending',
      Result_Message__c = bindingHash(
          normalizedAction,
          String.valueOf(targetId),
          member.Id,
          encodedExtra
        ) +
        '|' +
        String.valueOf(targetId) +
        (encodedExtra == null ? '' : '|' + encodedExtra),
      Created_At__c = System.now()
    );
    Database.insert(confirmation, AccessLevel.SYSTEM_MODE);
    PreviewDTO result = new PreviewDTO();
    result.token = rawToken;
    result.action = normalizedAction;
    result.targetId = targetId;
    result.preview = previewText;
    result.expiresAt = expires;
    return result;
  }

  public static Id confirm(String sessionToken, String token) {
    return commitConfirmed(sessionToken, token).recordId;
  }

  public static CommitResult commitConfirmed(
    String sessionToken,
    String token
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<Library_Scan_Transaction__c> candidates;
    if (String.isBlank(token)) {
      // No code to carry between messages: confirm the member's most recent
      // preview that is still waiting, if it has not expired.
      Datetime freshAfter = System.now().addMinutes(-5);
      List<Library_Scan_Transaction__c> latest = [
        SELECT Id
        FROM Library_Scan_Transaction__c
        WHERE
          Member__c = :member.Id
          AND Operation__c IN :SUPPORTED
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
      Id latestId = latest[0].Id;
      // Lock the chosen row (a locking query cannot also be ordered).
      candidates = [
        SELECT
          Id,
          Operation__c,
          Borrow_Record__c,
          Result_Message__c,
          Status__c,
          Created_At__c
        FROM Library_Scan_Transaction__c
        WHERE Id = :latestId
        WITH SYSTEM_MODE
        LIMIT 1
        FOR UPDATE
      ];
    } else {
      String tokenHash = hash(token.trim());
      candidates = [
        SELECT
          Id,
          Operation__c,
          Borrow_Record__c,
          Result_Message__c,
          Status__c,
          Created_At__c
        FROM Library_Scan_Transaction__c
        WHERE
          Idempotency_Key__c = :tokenHash
          AND Member__c = :member.Id
          AND Operation__c IN :SUPPORTED
        WITH SYSTEM_MODE
        LIMIT 1
        FOR UPDATE
      ];
      if (candidates.isEmpty())
        throw fail('That confirmation was not found. Prepare it again.');
    }
    Library_Scan_Transaction__c confirmation = candidates[0];
    List<String> binding = confirmation.Result_Message__c == null
      ? new List<String>()
      : confirmation.Result_Message__c.split('\\|');
    if (
      (binding.size() != 2 && binding.size() != 3) ||
      binding[0] !=
      bindingHash(
        confirmation.Operation__c,
        binding[1],
        member.Id,
        binding.size() == 3 ? binding[2] : null
      )
    )
      throw fail(
        'This confirmation does not belong to the authenticated member.'
      );
    if (
      confirmation.Status__c != 'Pending' ||
      confirmation.Created_At__c == null ||
      confirmation.Created_At__c.addMinutes(5) <= System.now()
    )
      throw fail('This confirmation has expired or was already used.');
    if (
      confirmation.Created_At__c.addSeconds(minConfirmDelaySeconds) >
      System.now()
    )
      throw fail(
        'Please wait for the member to confirm in their own message before committing.'
      );

    Savepoint checkpoint = Database.setSavepoint();
    try {
      confirmation.Status__c = 'Used';
      Database.update(confirmation, AccessLevel.SYSTEM_MODE);
      Id targetId = (Id) binding[1];
      CommitResult result = new CommitResult();
      result.recordId = targetId;
      result.message = 'The requested transaction was committed.';
      String operation = confirmation.Operation__c;
      if (operation == RENEW_LOAN) {
        LibraryCirculationService.renewLoanForMember(targetId, member.Id);
        result.message = 'The loan was renewed.';
      } else if (operation == CANCEL_RESERVATION) {
        LibraryCirculationService.cancelReservationForMember(
          targetId,
          member.Id
        );
        result.message = 'The reservation was cancelled.';
      } else if (operation == BORROW_BOOK) {
        result.recordId = LibraryMemberSessionController.borrowBook(
          sessionToken,
          targetId
        );
        result.message = 'The borrow request was submitted and is awaiting librarian approval. The member will be notified.';
      } else if (operation == RESERVE_BOOK) {
        result.recordId = LibraryMemberSessionController.reserveBook(
          sessionToken,
          targetId
        );
        result.message = 'The reservation was placed and the member is in the queue.';
      } else {
        Map<String, Object> booking = (Map<String, Object>) JSON.deserializeUntyped(
          EncodingUtil.base64Decode(binding[2]).toString()
        );
        LibraryRoomBookingService.BookingDTO booked = LibraryRoomBookingService.book(
          sessionToken,
          targetId,
          Integer.valueOf(booking.get('k')),
          Datetime.newInstance(Long.valueOf(String.valueOf(booking.get('s')))),
          Datetime.newInstance(Long.valueOf(String.valueOf(booking.get('e')))),
          (String) booking.get('p')
        );
        result.recordId = booked.id;
        result.message = 'The seat was booked.';
      }
      return result;
    } catch (Exception error) {
      // Leave the confirmation usable until it expires if the commit failed.
      Database.rollback(checkpoint);
      String reason = readable(error);
      throw fail(
        reason == null
          ? 'That could not be completed right now. It may no longer be available, so prepare it again.'
          : reason
      );
    }
  }

  // ---- previews ----

  private static String previewRenewal(Id targetId, Member__c member) {
    Borrow_Record__c loan = [
      SELECT
        Id,
        Member__c,
        Book_Copy__r.Book__r.Name,
        Due_Date__c,
        Renewal_Count__c
      FROM Borrow_Record__c
      WHERE Id = :targetId AND Member__c = :member.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return 'Renew ' +
      loan.Book_Copy__r.Book__r.Name +
      ' through the member renewal policy. Current due date: ' +
      String.valueOf(loan.Due_Date__c) +
      '.';
  }

  private static String previewCancellation(Id targetId, Member__c member) {
    Reservation__c reservation = [
      SELECT Id, Member__c, Book__r.Name, Status__c
      FROM Reservation__c
      WHERE Id = :targetId AND Member__c = :member.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return 'Cancel the ' +
      reservation.Status__c.toLowerCase() +
      ' reservation for ' +
      reservation.Book__r.Name +
      '.';
  }

  private static String previewBorrow(Book__c book, Member__c member) {
    if (member.Status__c != 'Active')
      throw fail('The membership must be active to request a book.');
    Integer pending = [
      SELECT COUNT()
      FROM Borrow_Record__c
      WHERE Member__c = :member.Id AND Status__c = 'Pending'
      WITH SYSTEM_MODE
    ];
    if (pending > 0)
      throw fail(
        'There is already a borrowing request awaiting librarian approval.'
      );
    if (book.Available_Copies__c == null || book.Available_Copies__c < 1)
      throw fail(
        'No copy of "' +
          book.Name +
          '" is available right now. It can be reserved instead to join the queue.'
      );
    return 'Request to borrow "' +
      book.Name +
      '". A copy will be held and a librarian must approve the request before the book can be collected.';
  }

  private static String previewReservation(Book__c book, Member__c member) {
    Integer existing = [
      SELECT COUNT()
      FROM Reservation__c
      WHERE
        Member__c = :member.Id
        AND Book__c = :book.Id
        AND Status__c IN ('Pending', 'Ready')
      WITH SYSTEM_MODE
    ];
    if (existing > 0)
      throw fail('"' + book.Name + '" is already reserved by this member.');
    String note = book.Available_Copies__c != null &&
      book.Available_Copies__c > 0
      ? ' A copy is available now, so requesting to borrow it may be quicker.'
      : '';
    return 'Reserve "' + book.Name + '" and join the queue.' + note;
  }

  private static Map<String, Object> previewRoom(PreviewRequest request) {
    Datetime startAt = LibraryAgentTimeParser.parse(request.startTime);
    if (startAt == null)
      throw fail(
        'A start date and time is required, for example 2026-11-04 15:00.'
      );
    if (startAt < System.now().addMinutes(-5))
      throw fail('That time has already passed.');
    Integer hours = request.durationHours == null ||
      request.durationHours < 1
      ? 1
      : Math.min(request.durationHours, 8);
    Datetime endAt = startAt.addHours(hours);
    LibraryRoomBookingService.RoomDTO room = resolveRoom(
      LibraryRoomBookingService.getAvailability(startAt, endAt, null),
      request.targetId,
      request.targetName
    );
    Integer seat;
    if (room.isPrivate == true) {
      if (room.available != true)
        throw fail(room.name + ' is already booked for that time.');
      seat = 1;
    } else {
      List<LibraryRoomBookingService.SeatDTO> seats = LibraryRoomBookingService.getSeats(
        request.sessionToken,
        room.id,
        startAt,
        endAt
      );
      if (request.seatNumber != null) {
        Boolean found = false;
        for (LibraryRoomBookingService.SeatDTO candidate : seats) {
          if (candidate.seatNo != request.seatNumber)
            continue;
          found = true;
          if (candidate.taken == true)
            throw fail(
              'Seat ' +
                request.seatNumber +
                ' in ' +
                room.name +
                ' is already taken for that time.'
            );
        }
        if (!found)
          throw fail(
            'Seat ' +
              request.seatNumber +
              ' does not exist in ' +
              room.name +
              '.'
          );
        seat = request.seatNumber;
      } else {
        for (LibraryRoomBookingService.SeatDTO candidate : seats) {
          if (candidate.taken != true) {
            seat = candidate.seatNo;
            break;
          }
        }
        if (seat == null)
          throw fail(room.name + ' is fully booked for that time.');
      }
    }
    String purpose = String.isBlank(request.purpose)
      ? null
      : request.purpose.trim().left(120);
    String place = String.isBlank(room.location)
      ? ''
      : ' (' + room.location + ')';
    String text =
      (room.isPrivate == true
        ? 'Book the private room ' + room.name
        : 'Book seat ' + seat + ' in ' + room.name) +
      place +
      ' on ' +
      startAt.format('EEE d MMM yyyy, h:mm a') +
      ' to ' +
      endAt.format('h:mm a') +
      (purpose == null ? '' : ' for "' + purpose + '"') +
      '.';
    return new Map<String, Object>{
      'roomId' => room.id,
      'text' => text,
      'booking' => new Map<String, Object>{
        'k' => seat,
        's' => String.valueOf(startAt.getTime()),
        'e' => String.valueOf(endAt.getTime()),
        'p' => purpose
      }
    };
  }

  // ---- lookups by id or by the name the member used ----

  private static Book__c resolveBook(Id bookId, String title) {
    if (bookId != null) {
      List<Book__c> byId = [
        SELECT Id, Name, Available_Copies__c
        FROM Book__c
        WHERE Id = :bookId
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (!byId.isEmpty())
        return byId[0];
    }
    if (String.isBlank(title))
      throw fail('Which book? A title is required.');
    String needle = title.trim();
    String pattern = '%' + String.escapeSingleQuotes(needle) + '%';
    List<Book__c> matches = [
      SELECT Id, Name, Available_Copies__c
      FROM Book__c
      WHERE Name = :needle OR Name LIKE :pattern
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 6
    ];
    if (matches.isEmpty())
      throw fail('No book in the catalog matches "' + needle + '".');
    for (Book__c candidate : matches) {
      if (candidate.Name.equalsIgnoreCase(needle))
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

  private static LibraryRoomBookingService.RoomDTO resolveRoom(
    List<LibraryRoomBookingService.RoomDTO> rooms,
    Id roomId,
    String name
  ) {
    if (roomId != null) {
      for (LibraryRoomBookingService.RoomDTO room : rooms) {
        if (room.id == roomId)
          return room;
      }
    }
    if (String.isBlank(name))
      throw fail('Which room? A room name is required.');
    String needle = name.trim().toLowerCase();
    List<LibraryRoomBookingService.RoomDTO> matches = new List<LibraryRoomBookingService.RoomDTO>();
    for (LibraryRoomBookingService.RoomDTO room : rooms) {
      String candidate = room.name == null ? '' : room.name.toLowerCase();
      if (candidate == needle)
        return room;
      if (candidate.contains(needle))
        matches.add(room);
    }
    if (matches.size() == 1)
      return matches[0];
    if (matches.isEmpty())
      throw fail('No study room matches "' + name.trim() + '".');
    List<String> names = new List<String>();
    for (LibraryRoomBookingService.RoomDTO room : matches)
      names.add(room.name);
    throw fail(
      'Several rooms match: ' + String.join(names, ', ') + '. Ask which one.'
    );
  }

  // ---- helpers ----

  private static String normalizeAction(String action) {
    String value = action == null ? '' : action.trim().toUpperCase();
    if (!SUPPORTED.contains(value))
      throw fail('That assistant action is not enabled.');
    return value;
  }

  private static String bindingHash(
    String action,
    String target,
    Id memberId,
    String extra
  ) {
    return hash(
      action +
        ':' +
        target +
        ':' +
        memberId +
        (String.isBlank(extra) ? '' : ':' + extra)
    );
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
