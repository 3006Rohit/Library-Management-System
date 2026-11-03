public without sharing class LibraryContactController {
  private static final Integer MAX_FIELD = 255;
  private static final Integer MAX_MESSAGE = 4000;
  private static final Pattern EMAIL_PATTERN = Pattern.compile(
    '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$'
  );

  public class BranchSummary {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String address;
    @AuraEnabled
    public String openingHours;
  }

  @AuraEnabled(cacheable=true)
  public static List<BranchSummary> getBranches() {
    List<BranchSummary> branches = new List<BranchSummary>();
    for (
      LibraryPublicBranchInfoAction.BranchResult row : LibraryPublicBranchInfoAction.execute(
        new List<LibraryPublicBranchInfoAction.Request>{
          new LibraryPublicBranchInfoAction.Request()
        }
      )
    ) {
      if (String.isBlank(row.name) && String.isBlank(row.address)) {
        continue;
      }
      BranchSummary summary = new BranchSummary();
      summary.name = row.name;
      summary.address = row.address;
      summary.openingHours = row.openingHours;
      branches.add(summary);
    }
    return branches;
  }

  @AuraEnabled
  public static void submitMessage(
    String firstName,
    String lastName,
    String email,
    String phone,
    String subject,
    String message
  ) {
    String first = clean(firstName);
    String last = clean(lastName);
    String mail = clean(email);
    String body = message == null ? '' : message.trim();
    if (String.isBlank(first) || String.isBlank(last)) {
      throw new AuraHandledException('Enter your first and last name.');
    }
    if (String.isBlank(mail) || !EMAIL_PATTERN.matcher(mail).matches()) {
      throw new AuraHandledException('Enter a valid email address.');
    }
    if (String.isBlank(body)) {
      throw new AuraHandledException('Enter a message.');
    }
    if (body.length() > MAX_MESSAGE) {
      throw new AuraHandledException(
        'Please keep your message under ' + MAX_MESSAGE + ' characters.'
      );
    }
    String topic = clean(subject);
    Case request = new Case(
      Origin = 'Web',
      Subject = String.isBlank(topic) ? 'Library website enquiry' : topic,
      Description = body,
      SuppliedName = (first + ' ' + last).abbreviate(80),
      SuppliedEmail = mail,
      SuppliedPhone = clean(phone)
    );
    Database.DMLOptions options = new Database.DMLOptions();
    options.assignmentRuleHeader.useDefaultRule = true;
    request.setOptions(options);
    try {
      insert request;
    } catch (DmlException ex) {
      System.debug(
        LoggingLevel.ERROR,
        'LIBRARY_CONTACT_FAILED: ' + ex.getMessage()
      );
      throw new AuraHandledException(
        'We could not send your message. Please try again later.'
      );
    }
  }

  private static String clean(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String trimmed = value.trim();
    return trimmed.length() > MAX_FIELD
      ? trimmed.substring(0, MAX_FIELD)
      : trimmed;
  }
}
