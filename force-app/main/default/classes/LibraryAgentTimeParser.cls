// Parses date-times supplied by the assistants. A value with a zone (Z or an
// offset) is an exact instant; a value without one is read as the running
// user's local time, which is the library's time, so "3 PM" means 3 PM there.
public with sharing class LibraryAgentTimeParser {
  public static Datetime parse(String raw) {
    if (String.isBlank(raw))
      return null;
    String value = raw.trim().replace('T', ' ');
    try {
      if (
        value.endsWithIgnoreCase('Z') ||
        Pattern.matches('.*\\d[+-]\\d{2}:?\\d{2}$', value)
      ) {
        return (Datetime) JSON.deserialize(
          '"' + value.replace(' ', 'T') + '"',
          Datetime.class
        );
      }
      if (Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', value))
        value += ' 00:00:00';
      if (Pattern.matches('^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$', value))
        value += ':00';
      // Drop fractional seconds before the local read.
      value = value.replaceAll('\\.\\d+$', '');
      return Datetime.valueOf(value);
    } catch (Exception ex) {
      return null;
    }
  }
}
