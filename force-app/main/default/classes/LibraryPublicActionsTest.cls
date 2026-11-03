@IsTest
private class LibraryPublicActionsTest {
  private static void seedBranchAndEvents() {
    insert new List<Library_Scan_Transaction__c>{
      new Library_Scan_Transaction__c(
        Idempotency_Key__c = 'BRANCH:TST1',
        Operation__c = 'Library Branch',
        Status__c = 'Active',
        Created_At__c = System.now(),
        Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'c' => 'TST1',
            'n' => 'Central Branch',
            'a' => '1 Main Street',
            't' => 'UTC'
          }
        )
      ),
      new Library_Scan_Transaction__c(
        Idempotency_Key__c = 'EVENT:FUTURE',
        Operation__c = 'Library Event',
        Status__c = 'Published',
        Created_At__c = System.now(),
        Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            't' => 'Story Hour',
            'd' => 'Kids stories',
            's' => String.valueOf(System.now().addDays(2)),
            'e' => String.valueOf(System.now().addDays(2).addHours(1)),
            'c' => 20,
            'l' => 'Central Branch'
          }
        )
      ),
      new Library_Scan_Transaction__c(
        Idempotency_Key__c = 'EVENT:PAST',
        Operation__c = 'Library Event',
        Status__c = 'Published',
        Created_At__c = System.now(),
        Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            't' => 'Old Event',
            's' => String.valueOf(System.now().addDays(-2)),
            'e' => String.valueOf(System.now().addDays(-2).addHours(1)),
            'c' => 20,
            'l' => 'Central Branch'
          }
        )
      )
    };
  }

  @IsTest
  static void branchInfoReturnsBranchesAndHoursNote() {
    seedBranchAndEvents();
    LibraryPublicBranchInfoAction.Request request = new LibraryPublicBranchInfoAction.Request();
    List<LibraryPublicBranchInfoAction.BranchResult> all = LibraryPublicBranchInfoAction.execute(
      new List<LibraryPublicBranchInfoAction.Request>{ request }
    );
    request.branch = 'central';
    List<LibraryPublicBranchInfoAction.BranchResult> filtered = LibraryPublicBranchInfoAction.execute(
      new List<LibraryPublicBranchInfoAction.Request>{ request }
    );
    request.branch = 'nowhere';
    List<LibraryPublicBranchInfoAction.BranchResult> none = LibraryPublicBranchInfoAction.execute(
      new List<LibraryPublicBranchInfoAction.Request>{ request }
    );
    System.assertEquals('Central Branch', all[0].name);
    System.assertEquals('Central Branch', filtered[0].name);
    System.assert(filtered[0].message.contains('not published'));
    System.assertEquals('No matching branch was found.', none[0].message);
  }

  @IsTest
  static void eventsReturnOnlyFutureEventsAndApplyFilters() {
    seedBranchAndEvents();
    LibraryPublicEventsAction.Request request = new LibraryPublicEventsAction.Request();
    List<LibraryPublicEventsAction.EventResult> upcoming = LibraryPublicEventsAction.execute(
      new List<LibraryPublicEventsAction.Request>{ request }
    );
    System.assertEquals(1, upcoming.size());
    System.assertEquals('Story Hour', upcoming[0].title);
    request.topic = 'chess';
    List<LibraryPublicEventsAction.EventResult> none = LibraryPublicEventsAction.execute(
      new List<LibraryPublicEventsAction.Request>{ request }
    );
    System.assert(none[0].message.contains('no upcoming events'));
    System.assertEquals(
      1,
      LibraryPublicEventsAction.execute(null).size(),
      'null input must not throw'
    );
  }

  @IsTest
  static void plansAndPoliciesExplainWhenNothingIsPublished() {
    List<LibraryPublicMembershipPlansAction.PlanResult> plans = LibraryPublicMembershipPlansAction.execute(
      new List<LibraryPublicMembershipPlansAction.Request>{
        new LibraryPublicMembershipPlansAction.Request()
      }
    );
    List<LibraryPublicPoliciesAction.PolicyResult> policies = LibraryPublicPoliciesAction.execute(
      new List<LibraryPublicPoliciesAction.Request>{
        new LibraryPublicPoliciesAction.Request()
      }
    );
    System.assert(plans[0].message.contains('No membership plans'));
    System.assert(policies[0].message.contains('not published'));
  }

  @IsTest
  static void plansAndPoliciesReadActivePlansOnly() {
    insert new List<Membership_Plan__c>{
      new Membership_Plan__c(
        Name = 'Standard',
        Active__c = true,
        Fee__c = 10,
        Duration_Days__c = 365,
        Borrow_Limit__c = 5,
        Loan_Duration_Days__c = 14,
        Renewal_Limit__c = 2,
        Reservation_Limit__c = 3,
        Fine_Per_Day__c = 0.5
      ),
      new Membership_Plan__c(Name = 'Retired', Active__c = false)
    };
    List<LibraryPublicMembershipPlansAction.PlanResult> plans = LibraryPublicMembershipPlansAction.execute(
      new List<LibraryPublicMembershipPlansAction.Request>{
        new LibraryPublicMembershipPlansAction.Request()
      }
    );
    List<LibraryPublicPoliciesAction.PolicyResult> policies = LibraryPublicPoliciesAction.execute(
      new List<LibraryPublicPoliciesAction.Request>{
        new LibraryPublicPoliciesAction.Request()
      }
    );
    System.assertEquals(1, plans.size());
    System.assertEquals('Standard', plans[0].planName);
    System.assertEquals(10, plans[0].fee);
    System.assertEquals(1, policies.size());
    System.assertEquals(14, policies[0].loanDurationDays);
    System.assertEquals(0.5, policies[0].finePerDay);
  }
}
