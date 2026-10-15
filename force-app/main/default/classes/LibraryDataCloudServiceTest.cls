@IsTest
private class LibraryDataCloudServiceTest {
  private static Id testBookId;
  private static Id testMemberId;

  private static Id analyticsBookId() {
    if (testBookId == null) {
      Book__c book = new Book__c(
        Name = 'Analytics Test Book',
        ISBN__c = 'ANALYTICS-TEST',
        Status__c = 'Active',
        Total_Copies__c = 1,
        Available_Copies__c = 1
      );
      insert book;
      testBookId = book.Id;
    }
    return testBookId;
  }

  private static Id analyticsMemberId() {
    if (testMemberId == null) {
      Membership_Plan__c plan = LibraryTestDataFactory.plan('Analytics Test Plan');
      Account account = LibraryTestDataFactory.communityAccount();
      Contact contact = LibraryTestDataFactory.contact(
        account,
        'analytics-member@example.com'
      );
      Member__c member = LibraryTestDataFactory.member(
        contact,
        plan,
        'analytics-member@example.com'
      );
      member.Account_Status__c = 'Active';
      update member;
      testMemberId = member.Id;
    }
    return testMemberId;
  }
  @IsTest
  static void mapsLibrarianInsightsAndMissingRowsSafely() {
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Copy_Availability__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_copy_count__c' => 10,
          'available_copy_count__c' => 7,
          'borrowed_copy_count__c' => 2,
          'reserved_copy_count__c' => 1,
          'lost_copy_count__c' => 0
        }
      },
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_loan_count__c' => 4,
          'active_loan_count__c' => 1,
          'returned_loan_count__c' => 3,
          'overdue_loan_count__c' => 0
        }
      },
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_reservation_count__c' => 2,
          'fulfilled_reservation_count__c' => 1,
          'cancelled_reservation_count__c' => 1,
          'pending_reservation_count__c' => 0,
          'ready_reservation_count__c' => 0,
          'expired_reservation_count__c' => 0
        }
      },
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_fine_count__c' => 1,
          'paid_fine_count__c' => 1,
          'unpaid_fine_count__c' => 0
        }
      },
      'Library_Book_Popularity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'book_id__c' => String.valueOf(analyticsBookId()),
          'total_borrow_count__c' => 3,
          'active_borrow_count__c' => 1,
          'returned_borrow_count__c' => 2
        }
      },
      'Library_Reservation_Demand__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'book_id__c' => String.valueOf(analyticsBookId()),
          'total_reservation_count__c' => 2,
          'fulfilled_reservation_count__c' => 1,
          'cancelled_reservation_count__c' => 1,
          'pending_reservation_count__c' => 0,
          'ready_reservation_count__c' => 0,
          'expired_reservation_count__c' => 0
        }
      }
    };
    Test.startTest();
    LibraryDataCloudService.LibrarianAnalyticsDTO result = LibraryDataCloudService.getLibrarianAnalytics();
    Test.stopTest();
    System.assertEquals(true, result.available);
    System.assertEquals(10, result.copyMetrics.totalCopies);
    System.assertEquals(4, result.loanMetrics.totalLoans);
    System.assertEquals(2, result.reservationMetrics.totalReservations);
    System.assertEquals(1, result.fineMetrics.totalFineCount);
    System.assertEquals(1, result.topBorrowedBooks.size());
    System.assertEquals(1, result.reservationDemand.size());
  }

  @IsTest
  static void mapsMemberInsightRowsAndDefaultsMissingRows() {
    Id memberId = analyticsMemberId();
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_loan_count__c' => 5,
          'active_loan_count__c' => 2,
          'returned_loan_count__c' => 3,
          'overdue_loan_count__c' => 0
        }
      },
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>(),
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>()
    };
    LibraryDataCloudService.MemberAnalyticsDTO result = LibraryDataCloudService.getMemberAnalytics(
      memberId
    );
    System.assertEquals(true, result.available);
    System.assertEquals(5, result.totalLoans);
    System.assertEquals(2, result.activeLoans);
    System.assertEquals(0, result.totalReservations);
    System.assertEquals(0, result.totalFineCount);
  }

  @IsTest
  static void mapsMemberReservationAndFineRows() {
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>(),
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_reservation_count__c' => 3,
          'fulfilled_reservation_count__c' => 1,
          'pending_reservation_count__c' => 1,
          'ready_reservation_count__c' => 1
        }
      },
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'total_fine_count__c' => 2,
          'unpaid_fine_count__c' => 1
        }
      }
    };
    LibraryDataCloudService.MemberAnalyticsDTO result = LibraryDataCloudService.getMemberAnalytics(
      String.valueOf(analyticsMemberId())
    );
    System.assertEquals(3, result.totalReservations);
    System.assertEquals(2, result.activeReservationCount);
    System.assertEquals(2, result.totalFineCount);
    System.assertEquals(1, result.unpaidFineCount);
  }

  @IsTest
  static void memberAnalyticsDtoSerializesMetricsForAura() {
    LibraryDataCloudService.MemberAnalyticsDTO result = new LibraryDataCloudService.MemberAnalyticsDTO();
    result.available = true;
    result.totalLoans = 4;
    result.activeLoans = 2;
    result.totalReservations = 3;

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      JSON.serialize(result)
    );
    System.assertEquals(true, payload.get('available'));
    System.assertEquals(4, payload.get('totalLoans'));
    System.assertEquals(2, payload.get('activeLoans'));
    System.assertEquals(3, payload.get('totalReservations'));
  }

  @IsTest
  static void returnsSafeFailureState() {
    LibraryDataCloudService.forceFailure = true;
    Test.startTest();
    LibraryDataCloudService.LibrarianAnalyticsDTO result = LibraryDataCloudService.getLibrarianAnalytics();
    Test.stopTest();
    System.assertEquals(false, result.available);
    System.assert(result.message.contains('temporarily unavailable'));
    LibraryDataCloudService.forceFailure = false;
  }

  @IsTest
  static void returnsSafeMemberFailureState() {
    LibraryDataCloudService.forceFailure = true;
    LibraryDataCloudService.MemberAnalyticsDTO result = LibraryDataCloudService.getMemberAnalytics(
      String.valueOf(analyticsMemberId())
    );
    System.assertEquals(false, result.available);
    System.assert(result.message.contains('temporarily unavailable'));
    LibraryDataCloudService.forceFailure = false;
  }

  @IsTest
  static void sortsAndTrimsTopListsAfterLoadingAllRows() {
    List<Map<String, Object>> popularity = new List<Map<String, Object>>();
    List<Map<String, Object>> demand = new List<Map<String, Object>>();
    for (Integer index = 0; index < 11; index++) {
      popularity.add(
        new Map<String, Object>{
          'book_id__c' => String.valueOf(analyticsBookId()),
          'total_borrow_count__c' => index,
          'active_borrow_count__c' => 0,
          'returned_borrow_count__c' => index
        }
      );
      demand.add(
        new Map<String, Object>{
          'book_id__c' => String.valueOf(analyticsBookId()),
          'total_reservation_count__c' => index,
          'fulfilled_reservation_count__c' => 0,
          'cancelled_reservation_count__c' => index,
          'pending_reservation_count__c' => 0,
          'ready_reservation_count__c' => 0,
          'expired_reservation_count__c' => 0
        }
      );
    }
    LibraryDataCloudService.testRows = new Map<String, List<Map<String, Object>>>{
      'Library_Copy_Availability__cio' => new List<Map<String, Object>>(),
      'Library_Member_Loan_Activity__cio' => new List<Map<String, Object>>(),
      'Library_Member_Reservation_Activity__cio' => new List<Map<String, Object>>(),
      'Library_Member_Fine_Activity__cio' => new List<Map<String, Object>>(),
      'Library_Book_Popularity__cio' => popularity,
      'Library_Reservation_Demand__cio' => demand
    };
    LibraryDataCloudService.LibrarianAnalyticsDTO result = LibraryDataCloudService.getLibrarianAnalytics();
    System.assertEquals(10, result.topBorrowedBooks.size());
    System.assertEquals(10, result.reservationDemand.size());
    System.assertEquals(10, result.topBorrowedBooks[0].borrowCount);
    System.assertEquals(10, result.reservationDemand[0].totalReservations);
  }
}
