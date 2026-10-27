public with sharing class LibraryAccessibilityService {
  public class PreferenceDTO {
    @AuraEnabled
    public String preferredLanguage;
    @AuraEnabled
    public String timezone;
    @AuraEnabled
    public Boolean highContrast;
    @AuraEnabled
    public Boolean largeText;
    @AuraEnabled
    public Boolean reducedMotion;
    @AuraEnabled
    public Boolean screenReader;
  }

  public static PreferenceDTO get(String sessionToken) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    return toDto(member);
  }

  public static PreferenceDTO save(
    String sessionToken,
    String preferredLanguage,
    String timezone,
    Boolean highContrast,
    Boolean largeText,
    Boolean reducedMotion,
    Boolean screenReader
  ) {
    Member__c member = LibraryMemberSessionService.getCurrentMember(
      sessionToken
    );
    String language = String.isBlank(preferredLanguage)
      ? 'English'
      : preferredLanguage.trim();
    if (!new Set<String>{ 'English', 'Hindi', 'Other' }.contains(language))
      throw new AuraHandledException('Choose a supported language.');
    if (
      String.isBlank(timezone) ||
      timezone.trim().length() > 80 ||
      timezone.contains('\n') ||
      timezone.contains('\r')
    )
      throw new AuraHandledException('Enter a valid timezone.');
    update new Member__c(
      Id = member.Id,
      Preferred_Language__c = language,
      Timezone__c = timezone.trim(),
      High_Contrast__c = highContrast == true,
      Large_Text__c = largeText == true,
      Reduced_Motion__c = reducedMotion == true,
      Screen_Reader__c = screenReader == true
    );
    member.Preferred_Language__c = language;
    member.Timezone__c = timezone.trim();
    member.High_Contrast__c = highContrast == true;
    member.Large_Text__c = largeText == true;
    member.Reduced_Motion__c = reducedMotion == true;
    member.Screen_Reader__c = screenReader == true;
    return toDto(member);
  }

  private static PreferenceDTO toDto(Member__c member) {
    PreferenceDTO dto = new PreferenceDTO();
    dto.preferredLanguage = String.isBlank(member.Preferred_Language__c)
      ? 'English'
      : member.Preferred_Language__c;
    dto.timezone = String.isBlank(member.Timezone__c)
      ? UserInfo.getTimeZone().getID()
      : member.Timezone__c;
    dto.highContrast = member.High_Contrast__c == true;
    dto.largeText = member.Large_Text__c == true;
    dto.reducedMotion = member.Reduced_Motion__c == true;
    dto.screenReader = member.Screen_Reader__c == true;
    return dto;
  }
}
