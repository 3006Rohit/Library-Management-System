public without sharing class LibraryChallengeService {
  private static final String CHALLENGE_OPERATION = 'Reading Challenge';
  private static final String ENROLLMENT_OPERATION = 'Challenge Enrollment';
  private static final String ACHIEVEMENT_OPERATION = 'Challenge Achievement';
  private static final String PREFERENCE_OPERATION = 'Challenge Preference';

  public class ChallengeDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Datetime startAt;
    @AuraEnabled
    public Datetime endAt;
    @AuraEnabled
    public Integer goalCount;
    @AuraEnabled
    public Integer progressCount;
    @AuraEnabled
    public String enrollmentStatus;
    @AuraEnabled
    public Integer streakCount;
    @AuraEnabled
    public String badgeName;
    @AuraEnabled
    public String certificateUrl;
    @AuraEnabled
    public Boolean leaderboardOptedIn;
  }

  public class AchievementDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id challengeId;
    @AuraEnabled
    public String challengeName;
    @AuraEnabled
    public String badgeCode;
    @AuraEnabled
    public String badgeName;
    @AuraEnabled
    public Datetime earnedAt;
    @AuraEnabled
    public String certificateUrl;
  }

  public class LeaderboardDTO {
    @AuraEnabled
    public Integer rank;
    @AuraEnabled
    public String alias;
    @AuraEnabled
    public Integer progressCount;
  }

  private class LeaderboardEntry implements Comparable {
    String alias;
    Integer progressCount;
    public Integer compareTo(Object other) {
      LeaderboardEntry value = (LeaderboardEntry) other;
      Integer left = progressCount == null ? 0 : progressCount;
      Integer right = value.progressCount == null ? 0 : value.progressCount;
      if (left == right)
        return alias.compareTo(value.alias);
      return left > right ? -1 : 1;
    }
  }

  public static Id create(
    String name,
    String description,
    Datetime startAt,
    Datetime endAt,
    Integer goalCount
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (
      String.isBlank(name) ||
      startAt == null ||
      endAt == null ||
      endAt <= startAt ||
      goalCount == null ||
      goalCount <= 0
    )
      throw new AuraHandledException(
        'Name, valid dates and a positive reading goal are required.'
      );
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'CHALLENGE:' +
        String.valueOf(Crypto.getRandomLong()).replace('-', '0'),
      Operation__c = CHALLENGE_OPERATION,
      Status__c = 'Published',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'n' => name.trim().left(80),
            'd' => String.isBlank(description)
              ? null
              : description.trim().left(100),
            's' => String.valueOf(startAt),
            'e' => String.valueOf(endAt),
            'g' => goalCount
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return row.Id;
  }

  public static List<ChallengeDTO> getAvailable(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Map<Id, String> enrollments = new Map<Id, String>();
    for (Library_Scan_Transaction__c row : [
      SELECT Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :ENROLLMENT_OPERATION
      WITH SYSTEM_MODE
      LIMIT 200
    ])
      enrollments.put(
        parseId(parse(row.Result_Message__c).get('c')),
        row.Status__c
      );
    List<ChallengeDTO> result = new List<ChallengeDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :CHALLENGE_OPERATION AND Status__c = 'Published'
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 200
    ]) {
      ChallengeDTO dto = toDto(row);
      if (dto.endAt == null || dto.endAt < System.now())
        continue;
      dto.enrollmentStatus = enrollments.get(row.Id);
      dto.progressCount = progress(member.Id, dto.startAt, dto.endAt);
      dto.streakCount = streak(member.Id, dto.startAt, dto.endAt);
      dto.leaderboardOptedIn = leaderboardOptIn(member.Id);
      if (
        dto.progressCount >= dto.goalCount &&
        dto.enrollmentStatus == 'Enrolled'
      )
        dto.enrollmentStatus = 'Completed';
      AchievementDTO achievement = achievementFor(member.Id, row.Id);
      if (achievement != null) {
        dto.badgeName = achievement.badgeName;
        dto.certificateUrl = achievement.certificateUrl;
      }
      result.add(dto);
    }
    return result;
  }

  public static ChallengeDTO enroll(String sessionToken, Id challengeId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    Library_Scan_Transaction__c challenge = challengeRow(challengeId);
    ChallengeDTO dto = toDto(challenge);
    if (dto.endAt == null || dto.endAt < System.now())
      throw new AuraHandledException('This challenge has ended.');
    String key =
      'CHALLENGE_ENROLL:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(challengeId);
    List<Library_Scan_Transaction__c> existing = [
      SELECT Id, Status__c
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      Database.insert(
        new Library_Scan_Transaction__c(
          Idempotency_Key__c = key,
          Operation__c = ENROLLMENT_OPERATION,
          Member__c = member.Id,
          Status__c = 'Enrolled',
          Created_At__c = System.now(),
          Result_Message__c = JSON.serialize(
              new Map<String, Object>{ 'c' => String.valueOf(challengeId) }
            )
            .left(255)
        ),
        AccessLevel.SYSTEM_MODE
      );
      dto.enrollmentStatus = 'Enrolled';
    } else
      dto.enrollmentStatus = existing[0].Status__c;
    dto.progressCount = progress(member.Id, dto.startAt, dto.endAt);
    dto.streakCount = streak(member.Id, dto.startAt, dto.endAt);
    dto.leaderboardOptedIn = leaderboardOptIn(member.Id);
    if (
      dto.progressCount >= dto.goalCount &&
      dto.enrollmentStatus == 'Enrolled'
    ) {
      dto.enrollmentStatus = 'Completed';
      AchievementDTO achievement = ensureAchievement(member.Id, challenge, dto);
      dto.badgeName = achievement.badgeName;
      dto.certificateUrl = achievement.certificateUrl;
    }
    return dto;
  }

  public static List<AchievementDTO> syncAchievements(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<AchievementDTO> result = new List<AchievementDTO>();
    for (Library_Scan_Transaction__c enrollment : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Member__c = :member.Id
        AND Operation__c = :ENROLLMENT_OPERATION
        AND Status__c IN ('Enrolled', 'Completed')
      WITH SYSTEM_MODE
      LIMIT 200
    ]) {
      Id challengeId = parseId(parse(enrollment.Result_Message__c).get('c'));
      if (challengeId == null)
        continue;
      List<Library_Scan_Transaction__c> challenges = [
        SELECT Id, Result_Message__c
        FROM Library_Scan_Transaction__c
        WHERE Id = :challengeId AND Operation__c = :CHALLENGE_OPERATION
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (challenges.isEmpty())
        continue;
      ChallengeDTO challenge = toDto(challenges[0]);
      if (
        progress(member.Id, challenge.startAt, challenge.endAt) <
        challenge.goalCount
      )
        continue;
      result.add(ensureAchievement(member.Id, challenges[0], challenge));
    }
    return result;
  }

  public static List<AchievementDTO> getAchievements(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    List<AchievementDTO> result = new List<AchievementDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :member.Id AND Operation__c = :ACHIEVEMENT_OPERATION
      WITH SYSTEM_MODE
      ORDER BY Created_At__c DESC
      LIMIT 200
    ])
      result.add(toAchievement(row));
    return result;
  }

  public static void setLeaderboardOptIn(String sessionToken, Boolean optIn) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String key = 'CHALLENGE_LEADERBOARD:' + String.valueOf(member.Id);
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE
        Member__c = :member.Id
        AND Operation__c = :PREFERENCE_OPERATION
        AND Idempotency_Key__c = :key
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Library_Scan_Transaction__c row = rows.isEmpty()
      ? new Library_Scan_Transaction__c(
          Idempotency_Key__c = key,
          Operation__c = PREFERENCE_OPERATION,
          Member__c = member.Id,
          Created_At__c = System.now()
        )
      : rows[0];
    row.Status__c = optIn == true ? 'OptedIn' : 'OptedOut';
    row.Result_Message__c = JSON.serialize(
        new Map<String, Object>{ 'o' => optIn == true }
      )
      .left(255);
    if (rows.isEmpty())
      Database.insert(row, AccessLevel.SYSTEM_MODE);
    else
      Database.update(row, AccessLevel.SYSTEM_MODE);
  }

  public static List<LeaderboardDTO> getLeaderboard(
    String sessionToken,
    Id challengeId
  ) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    Library_Scan_Transaction__c challenge = challengeRow(challengeId);
    ChallengeDTO challengeDto = toDto(challenge);
    Set<Id> optedIn = new Set<Id>();
    for (Library_Scan_Transaction__c preference : [
      SELECT Member__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :PREFERENCE_OPERATION AND Status__c = 'OptedIn'
      WITH SYSTEM_MODE
      LIMIT 500
    ])
      if (parse(preference.Result_Message__c).get('o') == true)
        optedIn.add(preference.Member__c);
    List<LeaderboardEntry> entries = new List<LeaderboardEntry>();
    for (Library_Scan_Transaction__c enrollment : [
      SELECT Member__c, Member__r.Name, Result_Message__c, Status__c
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = :ENROLLMENT_OPERATION
        AND Status__c IN ('Enrolled', 'Completed')
        AND Member__c != NULL
      WITH SYSTEM_MODE
      LIMIT 500
    ]) {
      if (
        !optedIn.contains(enrollment.Member__c) ||
        parseId(parse(enrollment.Result_Message__c).get('c')) != challengeId
      )
        continue;
      LeaderboardEntry entry = new LeaderboardEntry();
      entry.alias = 'Reader ' + String.valueOf(enrollment.Member__c).right(4);
      entry.progressCount = progress(
        enrollment.Member__c,
        challengeDto.startAt,
        challengeDto.endAt
      );
      entries.add(entry);
    }
    entries.sort();
    List<LeaderboardDTO> result = new List<LeaderboardDTO>();
    Integer rank = 1;
    for (LeaderboardEntry entry : entries) {
      if (result.size() >= 20)
        break;
      LeaderboardDTO dto = new LeaderboardDTO();
      dto.rank = rank++;
      dto.alias = entry.alias;
      dto.progressCount = entry.progressCount;
      result.add(dto);
    }
    return result;
  }

  public static void leave(String sessionToken, Id challengeId) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String key =
      'CHALLENGE_ENROLL:' +
      String.valueOf(member.Id) +
      ':' +
      String.valueOf(challengeId);
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Member__c = :member.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (!rows.isEmpty())
      Database.delete(rows[0], AccessLevel.SYSTEM_MODE);
  }

  private static Integer progress(
    Id memberId,
    Datetime startAt,
    Datetime endAt
  ) {
    Integer count = 0;
    for (Borrow_Record__c loan : [
      SELECT Borrow_Date__c
      FROM Borrow_Record__c
      WHERE Member__c = :memberId
      WITH SYSTEM_MODE
      LIMIT 500
    ])
      if (
        loan.Borrow_Date__c != null &&
        (startAt == null ||
        loan.Borrow_Date__c >= startAt) &&
        (endAt == null ||
        loan.Borrow_Date__c <= endAt)
      )
        count++;
    return count;
  }
  private static Integer streak(Id memberId, Datetime startAt, Datetime endAt) {
    Set<Date> days = new Set<Date>();
    for (Borrow_Record__c loan : [
      SELECT Borrow_Date__c
      FROM Borrow_Record__c
      WHERE Member__c = :memberId
      WITH SYSTEM_MODE
      LIMIT 500
    ]) {
      if (loan.Borrow_Date__c == null)
        continue;
      Date day = loan.Borrow_Date__c.date();
      if (
        (startAt == null || loan.Borrow_Date__c >= startAt) &&
        (endAt == null ||
        loan.Borrow_Date__c <= endAt)
      )
        days.add(day);
    }
    Date cursor = endAt == null ||
      endAt.date() > Date.today()
      ? Date.today()
      : endAt.date();
    Integer count = 0;
    while (days.contains(cursor) && count < 365) {
      count++;
      cursor = cursor.addDays(-1);
    }
    return count;
  }
  private static Boolean leaderboardOptIn(Id memberId) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Status__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :memberId AND Operation__c = :PREFERENCE_OPERATION
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return !rows.isEmpty() && rows[0].Status__c == 'OptedIn';
  }
  private static AchievementDTO achievementFor(Id memberId, Id challengeId) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c, Created_At__c
      FROM Library_Scan_Transaction__c
      WHERE Member__c = :memberId AND Operation__c = :ACHIEVEMENT_OPERATION
      WITH SYSTEM_MODE
      LIMIT 200
    ];
    for (Library_Scan_Transaction__c row : rows)
      if (parseId(parse(row.Result_Message__c).get('c')) == challengeId)
        return toAchievement(row);
    return null;
  }
  private static AchievementDTO ensureAchievement(
    Id memberId,
    Library_Scan_Transaction__c challengeRowValue,
    ChallengeDTO challenge
  ) {
    AchievementDTO existing = achievementFor(memberId, challengeRowValue.Id);
    if (existing != null)
      return existing;
    ContentVersion certificate = new ContentVersion(
      Title = 'reading-certificate-' + String.valueOf(challengeRowValue.Id),
      PathOnClient = 'reading-certificate.txt',
      VersionData = Blob.valueOf(
        'Reading Challenge Certificate\n\nThis certifies that the member completed: ' +
          challenge.name +
          '\nCompleted: ' +
          String.valueOf(System.now())
      ),
      IsMajorVersion = true
    );
    Database.insert(certificate, AccessLevel.SYSTEM_MODE);
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'ACHIEVEMENT:' +
        String.valueOf(memberId) +
        ':' +
        String.valueOf(challengeRowValue.Id),
      Operation__c = ACHIEVEMENT_OPERATION,
      Member__c = memberId,
      Status__c = 'Earned',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'c' => challengeRowValue.Id,
            'b' => 'CHALLENGE_FINISHER',
            'n' => 'Challenge Finisher',
            'cv' => certificate.Id
          }
        )
        .left(255)
    );
    Database.insert(row, AccessLevel.SYSTEM_MODE);
    return toAchievement(row);
  }
  private static AchievementDTO toAchievement(Library_Scan_Transaction__c row) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    AchievementDTO dto = new AchievementDTO();
    dto.id = row.Id;
    dto.challengeId = parseId(payload.get('c'));
    dto.badgeCode = stringValue(payload.get('b'));
    dto.badgeName = stringValue(payload.get('n'));
    dto.earnedAt = row.Created_At__c;
    String cv = stringValue(payload.get('cv'));
    dto.certificateUrl = String.isBlank(cv)
      ? null
      : '/sfc/servlet.shepherd/version/download/' + cv;
    return dto;
  }
  private static Library_Scan_Transaction__c challengeRow(Id challengeId) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Id = :challengeId
        AND Operation__c = :CHALLENGE_OPERATION
        AND Status__c = 'Published'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The challenge could not be found.');
    return rows[0];
  }
  private static ChallengeDTO toDto(Library_Scan_Transaction__c row) {
    Map<String, Object> payload = parse(row.Result_Message__c);
    ChallengeDTO dto = new ChallengeDTO();
    dto.id = row.Id;
    dto.name = stringValue(payload.get('n'));
    dto.description = stringValue(payload.get('d'));
    dto.startAt = parseDate(payload.get('s'));
    dto.endAt = parseDate(payload.get('e'));
    dto.goalCount = integerValue(payload.get('g'));
    dto.progressCount = 0;
    return dto;
  }
  private static Map<String, Object> parse(String raw) {
    if (String.isBlank(raw))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }
  private static Id parseId(Object value) {
    try {
      return value == null ? null : Id.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static Datetime parseDate(Object value) {
    if (value == null || String.isBlank(String.valueOf(value)))
      return null;
    String raw = String.valueOf(value).replace('T', ' ');
    Integer dot = raw.indexOf('.');
    if (dot > 0)
      raw = raw.substring(0, dot);
    Integer plus = raw.indexOf('+');
    if (plus > 0)
      raw = raw.substring(0, plus);
    if (raw.endsWith('Z'))
      raw = raw.left(raw.length() - 1).trim();
    try {
      return Datetime.valueOf(raw);
    } catch (Exception ignored) {
      return null;
    }
  }
  private static Integer integerValue(Object value) {
    try {
      return value == null ? null : Integer.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
