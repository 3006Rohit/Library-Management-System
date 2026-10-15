@IsTest
private class LibraryAgentActionsTest {
  private class Fixture {
    Member__c memberA;
    Member__c memberB;
    Book__c bookA;
    Book__c bookB;
  }

  @TestSetup
  static void setupFixtures() {
    List<Member__c> members = new List<Member__c>{
      new Member__c(
        First_Name__c = 'Agent',
        Last_Name__c = 'Alpha',
        Email__c = 'agent-alpha@example.com',
        Normalized_Email__c = 'agent-alpha@example.com',
        Status__c = 'Active',
        Account_Status__c = 'Active'
      ),
      new Member__c(
        First_Name__c = 'Agent',
        Last_Name__c = 'Beta',
        Email__c = 'agent-beta@example.com',
        Normalized_Email__c = 'agent-beta@example.com',
        Status__c = 'Active',
        Account_Status__c = 'Active'
      )
    };
    insert members;
    List<Book__c> books = new List<Book__c>{
      new Book__c(
        Name = 'Agent Alpha Book',
        ISBN__c = 'AGENT-ALPHA',
        Status__c = 'Active',
        Total_Copies__c = 2,
        Available_Copies__c = 1
      ),
      new Book__c(
        Name = 'Agent Beta Book',
        ISBN__c = 'AGENT-BETA',
        Status__c = 'Active',
        Total_Copies__c = 1,
        Available_Copies__c = 0
      )
    };
    insert books;
    List<Book_Copy__c> copies = new List<Book_Copy__c>{
      new Book_Copy__c(
        Book__c = books[0].Id,
        Barcode__c = 'AGENT-ALPHA-COPY',
        Status__c = 'Borrowed',
        Condition__c = 'Good'
      ),
      new Book_Copy__c(
        Book__c = books[1].Id,
        Barcode__c = 'AGENT-BETA-COPY',
        Status__c = 'Borrowed',
        Condition__c = 'Good'
      )
    };
    insert copies;
    insert new List<Borrow_Record__c>{
      new Borrow_Record__c(
        Member__c = members[0].Id,
        Book_Copy__c = copies[0].Id,
        Borrow_Date__c = System.now().addDays(-2),
        Due_Date__c = System.now().addDays(12),
        Status__c = 'Active',
        Renewal_Count__c = 0
      ),
      new Borrow_Record__c(
        Member__c = members[1].Id,
        Book_Copy__c = copies[1].Id,
        Borrow_Date__c = System.now().addDays(-1),
        Due_Date__c = System.now().addDays(13),
        Status__c = 'Active',
        Renewal_Count__c = 1
      )
    };
    insert new List<Reservation__c>{
      new Reservation__c(
        Member__c = members[0].Id,
        Book__c = books[0].Id,
        Reservation_Date__c = System.now().addDays(-1),
        Status__c = 'Pending',
        Queue_Position__c = 1
      ),
      new Reservation__c(
        Member__c = members[1].Id,
        Book__c = books[1].Id,
        Reservation_Date__c = System.now(),
        Status__c = 'Pending',
        Queue_Position__c = 2
      )
    };
  }

  private static Fixture fixture() {
    Fixture value = new Fixture();
    value.memberA = [
      SELECT Id, Name, Email__c
      FROM Member__c
      WHERE Email__c = 'agent-alpha@example.com'
      LIMIT 1
    ];
    value.memberB = [
      SELECT Id, Name, Email__c
      FROM Member__c
      WHERE Email__c = 'agent-beta@example.com'
      LIMIT 1
    ];
    value.bookA = [
      SELECT Id, Name
      FROM Book__c
      WHERE ISBN__c = 'AGENT-ALPHA'
      LIMIT 1
    ];
    value.bookB = [
      SELECT Id, Name
      FROM Book__c
      WHERE ISBN__c = 'AGENT-BETA'
      LIMIT 1
    ];
    return value;
  }

  private static String sessionFor(Member__c member) {
    return LibraryMemberSessionService.create(member, null, 'Agentforce test');
  }

  private static void resetTestState() {
    LibraryPolicyService.testGrantedPermissions.clear();
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>();
    LibraryDataCloudService.forceFailure = false;
  }

  @IsTest
  static void librarianAnalyticsMapsSuccessAndHandlesDataCloudFailure() {
    resetTestState();
    LibraryAgentAnalyticsAction.Response denied = LibraryAgentAnalyticsAction.execute(
      new List<LibraryAgentAnalyticsAction.Request>{
        new LibraryAgentAnalyticsAction.Request()
      }
    )[0];
    System.assertEquals(
      false,
      denied.available,
      'Analytics must require the librarian permission.'
    );
    System.assert(
      !String.isBlank(denied.message),
      'The action must return a diagnostic instead of throwing a generic failure.'
    );

    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Copy_Availability__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_copy_count__c' => 2,
          'available_copy_count__c' => 1,
          'borrowed_copy_count__c' => 1
        }
      },
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_loan_count__c' => 2,
          'active_loan_count__c' => 1,
          'returned_loan_count__c' => 1
        }
      },
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_reservation_count__c' => 2,
          'pending_reservation_count__c' => 1
        }
      },
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_fine_count__c' => 1,
          'unpaid_fine_count__c' => 1
        }
      },
      'Library_Book_Popularity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'book_id__c' => '001000000000001',
          'borrow_count__c' => 2
        }
      },
      'Library_Reservation_Demand__cio' => new List<Map<String, Object>>()
    };
    LibraryAgentAnalyticsAction.Response success = LibraryAgentAnalyticsAction.execute(
      new List<LibraryAgentAnalyticsAction.Request>{
        new LibraryAgentAnalyticsAction.Request()
      }
    )[0];
    System.assertEquals(true, success.available);
    System.assertEquals(2, success.totalCopies);
    System.assertEquals(1, success.activeLoans);
    System.assert(success.topBorrowedBooksJson != null);

    LibraryDataCloudService.forceFailure = true;
    LibraryAgentAnalyticsAction.Response unavailable = LibraryAgentAnalyticsAction.execute(
      new List<LibraryAgentAnalyticsAction.Request>{
        new LibraryAgentAnalyticsAction.Request()
      }
    )[0];
    System.assertEquals(false, unavailable.available);
    System.assertEquals(
      false,
      unavailable.message.contains('TEST_DATA_CLOUD_FAILURE')
    );
  }

  @IsTest
  static void catalogAndLibrarianSummaryHappyPathsAreBounded() {
    resetTestState();
    LibraryPolicyService.testGrantedPermissions.add(
      'Manage_Library_Circulation'
    );
    LibraryAgentCatalogAction.Request catalog = new LibraryAgentCatalogAction.Request();
    catalog.title = 'Alpha';
    catalog.availableOnly = false;
    List<LibraryAgentCatalogAction.BookResult> books = LibraryAgentCatalogAction.execute(
      new List<LibraryAgentCatalogAction.Request>{ catalog }
    );
    System.assertEquals(1, books.size());
    System.assertEquals('Agent Alpha Book', books[0].title);

    LibraryAgentCatalogAction.Request noResult = new LibraryAgentCatalogAction.Request();
    noResult.author = 'does-not-exist';
    System.assertEquals(
      0,
      LibraryAgentCatalogAction.execute(
          new List<LibraryAgentCatalogAction.Request>{ noResult }
        )
        .size()
    );

    LibraryAgentCatalogAction.Request available = new LibraryAgentCatalogAction.Request();
    available.availableOnly = true;
    System.assertEquals(
      0,
      LibraryAgentCatalogAction.execute(
          new List<LibraryAgentCatalogAction.Request>{ available }
        )
        .size()
    );

    LibraryAgentCatalogAction.Request category = new LibraryAgentCatalogAction.Request();
    category.category = 'does-not-exist';
    System.assertEquals(
      0,
      LibraryAgentCatalogAction.execute(
          new List<LibraryAgentCatalogAction.Request>{ category }
        )
        .size()
    );

    List<LibraryAgentCatalogAction.BookResult> allBooks = LibraryAgentCatalogAction.execute(
      null
    );
    System.assertEquals(2, allBooks.size());

    Fixture data = fixture();
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_loan_count__c' => 3,
          'active_loan_count__c' => 1
        }
      },
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_reservation_count__c' => 2,
          'pending_reservation_count__c' => 1
        }
      },
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_fine_count__c' => 1,
          'unpaid_fine_count__c' => 1
        }
      }
    };
    LibraryAgentMemberSummaryAction.Request summaryRequest = new LibraryAgentMemberSummaryAction.Request();
    summaryRequest.memberLookup = String.valueOf(data.memberA.Id);
    LibraryAgentMemberSummaryAction.Response summary = LibraryAgentMemberSummaryAction.execute(
      new List<LibraryAgentMemberSummaryAction.Request>{ summaryRequest }
    )[0];
    System.assertEquals(true, summary.found);
    System.assertEquals(3, summary.totalLoans);
    System.assertEquals(data.memberA.Email__c, summary.memberEmail);

    summaryRequest.memberLookup = 'missing@example.invalid';
    System.assertEquals(
      false,
      LibraryAgentMemberSummaryAction.execute(
          new List<LibraryAgentMemberSummaryAction.Request>{ summaryRequest }
        )[0]
        .found
    );
  }

  @IsTest
  static void memberActionsRequireValidSessionAndReturnOnlyAuthenticatedRecords() {
    resetTestState();
    Fixture data = fixture();
    String tokenA = sessionFor(data.memberA);
    String tokenB = sessionFor(data.memberB);
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_loan_count__c' => 1,
          'active_loan_count__c' => 1
        }
      },
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_reservation_count__c' => 1,
          'pending_reservation_count__c' => 1
        }
      },
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_fine_count__c' => 0,
          'unpaid_fine_count__c' => 0
        }
      }
    };

    LibraryAgentMyActivityAction.Request activityRequest = new LibraryAgentMyActivityAction.Request();
    activityRequest.sessionToken = tokenA;
    System.assertEquals(
      1,
      LibraryAgentMyActivityAction.execute(
          new List<LibraryAgentMyActivityAction.Request>{ activityRequest }
        )[0]
        .totalLoans
    );
    activityRequest.sessionToken = tokenB;
    System.assertEquals(
      1,
      LibraryAgentMyActivityAction.execute(
          new List<LibraryAgentMyActivityAction.Request>{ activityRequest }
        )[0]
        .totalLoans
    );

    LibraryAgentMyLoansAction.Request loansRequest = new LibraryAgentMyLoansAction.Request();
    loansRequest.sessionToken = tokenA;
    List<LibraryAgentMyLoansAction.LoanResult> loansA = LibraryAgentMyLoansAction.execute(
      new List<LibraryAgentMyLoansAction.Request>{ loansRequest }
    );
    System.assertEquals(1, loansA.size());
    System.assertEquals('Agent Alpha Book', loansA[0].bookTitle);
    loansRequest.sessionToken = tokenB;
    System.assertEquals(
      'Agent Beta Book',
      LibraryAgentMyLoansAction.execute(
          new List<LibraryAgentMyLoansAction.Request>{ loansRequest }
        )[0]
        .bookTitle
    );

    LibraryAgentMyReservationsAction.Request reservationsRequest = new LibraryAgentMyReservationsAction.Request();
    reservationsRequest.sessionToken = tokenA;
    List<LibraryAgentMyReservationsAction.ReservationResult> reservationsA = LibraryAgentMyReservationsAction.execute(
      new List<LibraryAgentMyReservationsAction.Request>{ reservationsRequest }
    );
    System.assertEquals(1, reservationsA.size());
    System.assertEquals('Agent Alpha Book', reservationsA[0].bookTitle);
    reservationsRequest.sessionToken = tokenB;
    System.assertEquals(
      'Agent Beta Book',
      LibraryAgentMyReservationsAction.execute(
          new List<LibraryAgentMyReservationsAction.Request>{
            reservationsRequest
          }
        )[0]
        .bookTitle
    );

    for (String invalid : new List<String>{ null, '', 'not-a-session-token' }) {
      activityRequest.sessionToken = invalid;
      Boolean rejected = false;
      try {
        LibraryAgentMyActivityAction.execute(
          new List<LibraryAgentMyActivityAction.Request>{ activityRequest }
        );
      } catch (Exception ex) {
        rejected = true;
        System.assert(!ex.getMessage().contains('Token_Hash__c'));
      }
      System.assertEquals(true, rejected);
    }
  }
}
