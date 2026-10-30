public without sharing class LibraryNotificationPreferenceService {
  private static final List<String> DEFAULT_CHANNELS = new List<String>{
    'In-App',
    'Email'
  };
  private static final List<String> DEFAULT_TYPES = new List<String>{
    'New Book',
    'Book Available',
    'Reservation Ready',
    'Reservation Cancelled',
    'Reservation Expired',
    'Loan Due',
    'Loan Overdue',
    'Membership',
    'Payment'
  };
  private static final Set<String> ALLOWED_CHANNELS = new Set<String>{
    'In-App',
    'Email',
    'SMS',
    'WhatsApp',
    'Push'
  };
  private static final Set<String> ALLOWED_FREQUENCIES = new Set<String>{
    'Instant',
    'Daily',
    'Weekly'
  };

  public class PreferenceDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String channel;
    @AuraEnabled
    public String notificationType;
    @AuraEnabled
    public Boolean enabled;
    @AuraEnabled
    public String digestFrequency;
    @AuraEnabled
    public String quietHoursStart;
    @AuraEnabled
    public String quietHoursEnd;
    @AuraEnabled
    public String timezone;
  }

  public class PreferenceInput {
    @AuraEnabled
    public String channel;
    @AuraEnabled
    public String notificationType;
    @AuraEnabled
    public Boolean enabled;
    @AuraEnabled
    public String digestFrequency;
    @AuraEnabled
    public String quietHoursStart;
    @AuraEnabled
    public String quietHoursEnd;
    @AuraEnabled
    public String timezone;
  }

  public static List<PreferenceDTO> getForMember(Id memberId) {
    if (memberId == null)
      return new List<PreferenceDTO>();
    ensureDefaults(memberId);
    List<PreferenceDTO> results = new List<PreferenceDTO>();
    for (Notification_Preference__c row : [
      SELECT
        Id,
        Channel__c,
        Notification_Type__c,
        Enabled__c,
        Digest_Frequency__c,
        Quiet_Hours_Start__c,
        Quiet_Hours_End__c,
        Timezone__c
      FROM Notification_Preference__c
      WHERE Member__c = :memberId
      WITH SYSTEM_MODE
      ORDER BY Notification_Type__c ASC, Channel__c ASC
    ]) {
      results.add(toDto(row));
    }
    return results;
  }

  public static void saveForMember(Id memberId, List<PreferenceInput> inputs) {
    if (memberId == null || inputs == null || inputs.isEmpty())
      return;
    if (inputs.size() > 100)
      throw new AuraHandledException('Too many notification preferences.');

    Set<String> keys = new Set<String>();
    for (PreferenceInput input : inputs) {
      validate(input);
      keys.add(key(memberId, input.channel, input.notificationType));
    }
    Map<String, Notification_Preference__c> existing = new Map<String, Notification_Preference__c>();
    for (Notification_Preference__c row : [
      SELECT
        Id,
        Member__c,
        Channel__c,
        Notification_Type__c,
        Enabled__c,
        Digest_Frequency__c,
        Quiet_Hours_Start__c,
        Quiet_Hours_End__c,
        Timezone__c,
        Preference_Key__c
      FROM Notification_Preference__c
      WHERE Member__c = :memberId
      WITH SYSTEM_MODE
    ]) {
      String rowKey = String.isBlank(row.Preference_Key__c)
        ? key(memberId, row.Channel__c, row.Notification_Type__c)
        : row.Preference_Key__c;
      if (keys.contains(rowKey))
        existing.put(rowKey, row);
    }

    List<Notification_Preference__c> changes = new List<Notification_Preference__c>();
    for (PreferenceInput input : inputs) {
      String rowKey = key(memberId, input.channel, input.notificationType);
      Notification_Preference__c row = existing.get(rowKey);
      if (row == null) {
        row = new Notification_Preference__c(
          Member__c = memberId,
          Channel__c = input.channel,
          Notification_Type__c = input.notificationType,
          Preference_Key__c = rowKey
        );
      }
      row.Enabled__c = input.enabled == null ? true : input.enabled;
      row.Digest_Frequency__c = String.isBlank(input.digestFrequency)
        ? 'Instant'
        : input.digestFrequency;
      row.Quiet_Hours_Start__c = input.quietHoursStart;
      row.Quiet_Hours_End__c = input.quietHoursEnd;
      row.Timezone__c = String.isBlank(input.timezone)
        ? UserInfo.getTimeZone().getID()
        : input.timezone;
      row.Last_Updated__c = System.now();
      changes.add(row);
    }
    if (!changes.isEmpty())
      Database.upsert(changes, AccessLevel.SYSTEM_MODE);
  }

  public static Boolean shouldDeliver(
    Id memberId,
    String channel,
    String notificationType
  ) {
    if (memberId == null || String.isBlank(channel) || channel == 'In-App')
      return true;
    List<Notification_Preference__c> rows = [
      SELECT Enabled__c
      FROM Notification_Preference__c
      WHERE
        Member__c = :memberId
        AND Channel__c = :channel
        AND Notification_Type__c = :notificationType
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return rows.isEmpty() || rows[0].Enabled__c;
  }

  public static Map<String, Boolean> emailDecisions(
    Set<Id> memberIds,
    Set<String> notificationTypes
  ) {
    Map<String, Boolean> decisions = new Map<String, Boolean>();
    if (
      memberIds == null ||
      memberIds.isEmpty() ||
      notificationTypes == null ||
      notificationTypes.isEmpty()
    )
      return decisions;
    for (Notification_Preference__c row : [
      SELECT Member__c, Notification_Type__c, Enabled__c
      FROM Notification_Preference__c
      WHERE
        Member__c IN :memberIds
        AND Channel__c = 'Email'
        AND Notification_Type__c IN :notificationTypes
      WITH SYSTEM_MODE
    ]) {
      decisions.put(
        key(row.Member__c, 'Email', row.Notification_Type__c),
        row.Enabled__c
      );
    }
    return decisions;
  }

  private static void ensureDefaults(Id memberId) {
    Set<String> existingKeys = new Set<String>();
    for (Notification_Preference__c row : [
      SELECT Channel__c, Notification_Type__c, Preference_Key__c
      FROM Notification_Preference__c
      WHERE Member__c = :memberId
      WITH SYSTEM_MODE
    ]) {
      existingKeys.add(
        String.isBlank(row.Preference_Key__c)
          ? key(memberId, row.Channel__c, row.Notification_Type__c)
          : row.Preference_Key__c
      );
    }
    List<Notification_Preference__c> defaults = new List<Notification_Preference__c>();
    for (String type : DEFAULT_TYPES) {
      for (String channel : DEFAULT_CHANNELS) {
        String rowKey = key(memberId, channel, type);
        if (existingKeys.contains(rowKey))
          continue;
        defaults.add(
          new Notification_Preference__c(
            Member__c = memberId,
            Channel__c = channel,
            Notification_Type__c = type,
            Enabled__c = true,
            Digest_Frequency__c = 'Instant',
            Timezone__c = UserInfo.getTimeZone().getID(),
            Preference_Key__c = rowKey,
            Last_Updated__c = System.now()
          )
        );
      }
    }
    if (!defaults.isEmpty())
      Database.insert(defaults, AccessLevel.SYSTEM_MODE);
  }

  private static void validate(PreferenceInput input) {
    if (
      input == null ||
      !ALLOWED_CHANNELS.contains(input.channel) ||
      String.isBlank(input.notificationType)
    )
      throw new AuraHandledException('Unsupported notification preference.');
    if (
      !String.isBlank(input.digestFrequency) &&
      !ALLOWED_FREQUENCIES.contains(input.digestFrequency)
    )
      throw new AuraHandledException('Unsupported digest frequency.');
    if (
      (!String.isBlank(input.quietHoursStart) &&
      !Pattern.matches('^([01]\\d|2[0-3]):[0-5]\\d$', input.quietHoursStart)) ||
      (!String.isBlank(input.quietHoursEnd) &&
      !Pattern.matches('^([01]\\d|2[0-3]):[0-5]\\d$', input.quietHoursEnd))
    )
      throw new AuraHandledException('Quiet hours must use HH:mm format.');
  }

  private static String key(Id memberId, String channel, String type) {
    return String.valueOf(memberId) + '|' + channel + '|' + type;
  }

  private static PreferenceDTO toDto(Notification_Preference__c row) {
    PreferenceDTO result = new PreferenceDTO();
    result.id = row.Id;
    result.channel = row.Channel__c;
    result.notificationType = row.Notification_Type__c;
    result.enabled = row.Enabled__c;
    result.digestFrequency = row.Digest_Frequency__c;
    result.quietHoursStart = row.Quiet_Hours_Start__c;
    result.quietHoursEnd = row.Quiet_Hours_End__c;
    result.timezone = row.Timezone__c;
    return result;
  }
}
