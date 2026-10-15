public without sharing class LibraryMemberPasswordService {
  public static void validate(String password, String confirmation) {
    if (
      String.isBlank(password) ||
      password != confirmation ||
      password.length() < 10 ||
      password.length() > 128 ||
      !Pattern.matches('.*[A-Z].*', password) ||
      !Pattern.matches('.*[a-z].*', password) ||
      !Pattern.matches('.*[0-9].*', password)
    ) {
      throw new AuraHandledException(
        'Password must match and contain at least 10 characters, one uppercase letter, one lowercase letter, and one number.'
      );
    }
  }
  public static String newSalt() {
    return EncodingUtil.base64Encode(Crypto.generateAesKey(256));
  }
  public static String hash(String salt, String password) {
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(salt + ':' + password))
      )
      .toLowerCase();
  }
  public static Boolean matches(Member__c member, String password) {
    return member != null &&
      !String.isBlank(member.Password_Salt__c) &&
      !String.isBlank(member.Password_Hash__c) &&
      constantTimeEqual(
        member.Password_Hash__c,
        hash(member.Password_Salt__c, password)
      );
  }
  public static String token() {
    return EncodingUtil.base64Encode(Crypto.generateAesKey(256));
  }
  public static String tokenHash(String value) {
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(value))
      )
      .toLowerCase();
  }
  private static Boolean constantTimeEqual(String left, String right) {
    if (left == null || right == null || left.length() != right.length())
      return false;
    Integer difference = 0;
    for (Integer i = 0; i < left.length(); i++)
      difference |= left.charAt(i) ^ right.charAt(i);
    return difference == 0;
  }
}
