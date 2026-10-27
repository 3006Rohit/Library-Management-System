# Graph Report - Library Management System  (2026-10-27)

## Corpus Check
- 370 files · ~377,766 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 456 file(s) not represented in the graph (top: .xml 393, .css 38, .apex 14)

## Summary
- 2216 nodes · 2699 edges · 235 communities (87 shown, 148 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 293 edges (avg confidence: 0.56)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Circulation
- Member & Auth
- Catalog & Books
- Community 10
- Catalog & Books
- Member & Auth
- Community 14
- Circulation
- Community 16
- Community 17
- Community 18
- Member & Auth
- Tests
- Community 21
- Notifications
- Community 23
- Community 24
- Community 25
- Catalog & Books
- Community 28
- Payments & Fines
- Payments & Fines
- Community 31
- Catalog & Books
- Catalog & Books
- Member & Auth
- Member & Auth
- Member & Auth
- Community 37
- Payments & Fines
- Member & Auth
- Member & Auth
- Community 41
- Circulation
- Member & Auth
- Member & Auth
- Community 45
- Member & Auth
- Catalog & Books
- Member & Auth
- Notifications
- Catalog & Books
- Member & Auth
- Member & Auth
- Community 53
- Community 54
- Community 55
- Circulation
- Community 57
- Member & Auth
- Notifications
- Payments & Fines
- Community 61
- Member & Auth
- Community 63
- Notifications
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Community 70
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Tests
- Community 77
- Member & Auth
- Member & Auth
- Payments & Fines
- Catalog & Books
- Member & Auth
- Community 83
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Community 89
- Tests
- Tests
- Catalog & Books
- Community 93
- Community 94
- Catalog & Books
- Tests
- Member & Auth
- Community 99
- Tests
- Member & Auth
- Tests
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Community 107
- Catalog & Books
- Catalog & Books
- Community 110
- Community 111
- Member & Auth
- Catalog & Books
- Community 116
- Community 118
- Member & Auth
- Catalog & Books
- Community 121
- Member & Auth
- Notifications
- Notifications
- Notifications
- Community 126
- Community 127
- Tests
- Catalog & Books
- Tests
- Circulation
- Community 132
- Member & Auth
- Community 134
- Member & Auth
- Member & Auth
- Community 137
- Community 138
- Community 139
- Member & Auth
- Community 141
- Community 142
- Community 143
- Notifications
- Member & Auth
- Member & Auth
- Catalog & Books
- Catalog & Books
- Tests
- Member & Auth
- Member & Auth
- Member & Auth
- Member & Auth
- Tests
- Tests
- Catalog & Books
- Circulation
- Tests
- Community 159
- Member & Auth
- Tests
- Member & Auth
- Notifications
- Notifications
- Notifications
- Payments & Fines
- Community 167
- Tests
- Catalog & Books
- Community 170
- Tests
- Community 176
- Community 177
- Member & Auth
- Circulation
- Member & Auth
- Member & Auth
- Catalog & Books
- Tests
- Tests
- Tests
- Payments & Fines
- Payments & Fines
- Community 188
- Community 194
- Member & Auth
- Catalog & Books
- Circulation
- Payments & Fines
- Member & Auth
- Member & Auth
- Member & Auth
- Community 211
- Workflows
- Community 213
- Member & Auth
- Community 215
- Member & Auth
- Community 220
- Payments & Fines

## God Nodes (most connected - your core abstractions)
1. `LibraryLibrarianWorkspace` - 238 edges
2. `LibraryMemberShell` - 185 edges
3. `PaymentRow` - 47 edges
4. `RankedBook` - 33 edges
5. `LibraryCirculationService` - 29 edges
6. `DashboardData` - 27 edges
7. `LibraryIsbnMetadata` - 22 edges
8. `LibraryScanner` - 22 edges
9. `Fixture` - 21 edges
10. `Member__c` - 21 edges

## Surprising Connections (you probably didn't know these)
- `Reservations` --conceptually_related_to--> `Book_Copy__c`  [INFERRED]
  WORKFLOWS.md → DATA_MODEL.md
- `ISBN Metadata and Catalog-Quality Review` --conceptually_related_to--> `Book__c`  [INFERRED]
  WORKFLOWS.md → DATA_MODEL.md
- `Checkout` --conceptually_related_to--> `Book_Copy__c`  [INFERRED]
  WORKFLOWS.md → DATA_MODEL.md
- `Copy Repair and Missing-Book Condition Lifecycle` --conceptually_related_to--> `Book_Copy__c`  [INFERRED]
  WORKFLOWS.md → DATA_MODEL.md
- `Checkout` --conceptually_related_to--> `Member__c`  [INFERRED]
  WORKFLOWS.md → DATA_MODEL.md

## Import Cycles
- None detected.

## Communities (235 total, 148 thin omitted)

### Community 2 - "Member & Auth"
Cohesion: 0.07
Nodes (6): Author__c, Member__c, DashboardData, LibraryLibrarianController, MemberDetail, PaymentRow

### Community 4 - "Member & Auth"
Cohesion: 0.08
Nodes (7): Comparable, update, DashboardData, LibraryMemberSessionController, LoanDTO, RankedBook, ReservationDTO

### Community 6 - "Circulation"
Cohesion: 0.07
Nodes (4): delete, insert, update, LibraryCirculationService

### Community 7 - "Member & Auth"
Cohesion: 0.11
Nodes (3): update, DashboardData, LibraryMemberController

### Community 9 - "Catalog & Books"
Cohesion: 0.07
Nodes (10): BookPopularityDTO, Book__c, CopyMetrics, FineMetrics, LibrarianAnalyticsDTO, LibraryDataCloudService, LoanMetrics, MemberAnalyticsDTO (+2 more)

### Community 10 - "Community 10"
Cohesion: 0.08
Nodes (6): AchievementDTO, ChallengeDTO, Comparable, LeaderboardDTO, LeaderboardEntry, LibraryChallengeService

### Community 12 - "Catalog & Books"
Cohesion: 0.09
Nodes (9): Book_Copy__c, Borrow_Record__c, insert, update, Fine__c, Member__c, Reservation__c, Fixture (+1 more)

### Community 13 - "Member & Auth"
Cohesion: 0.10
Nodes (22): SFDX_AUTH_URL, VALIDATION_ORG, runs-on, steps, jobs, javascript, salesforce, name (+14 more)

### Community 16 - "Community 16"
Cohesion: 0.13
Nodes (21): description, devDependencies, eslint-plugin-import@^2.31.0, husky@^9.1.7, lint-staged@^16.1.2, @lwc/eslint-plugin-lwc@^3.1.0, prettier@^3.5.3, prettier-plugin-apex@^2.2.6 (+13 more)

### Community 17 - "Community 17"
Cohesion: 0.14
Nodes (21): Apex API Version 64.0, Apex API Version 65.0, Apex API Version 67.0, Apex API Version 68.0, force-app Directory, LibraryAgentApiController Apex Class, LibraryCatalogService Apex Class, LibraryCirculationService Apex Class (+13 more)

### Community 18 - "Community 18"
Cohesion: 0.10
Nodes (3): BranchDTO, LibraryBranchService, TransferDTO

### Community 19 - "Member & Auth"
Cohesion: 0.10
Nodes (8): Contact, Book__c, Borrow_Record__c, insert, update, Member_Notification__c, Reservation__c, LibraryMemberControllerTest

### Community 20 - "Tests"
Cohesion: 0.11
Nodes (4): insert, update, Library_Registration__c, LibraryRegistrationLifecycleTest

### Community 22 - "Notifications"
Cohesion: 0.11
Nodes (9): Agent_Confirmation__c, Library_Event__c, Library_Operation_Audit__c, Library_Risk_Alert__c, Library_Room__c, Member__c, Membership_Hold__c, Privacy_Request__c (+1 more)

### Community 23 - "Community 23"
Cohesion: 0.11
Nodes (3): CheckInDTO, EventDTO, LibraryEventService

### Community 24 - "Community 24"
Cohesion: 0.11
Nodes (3): update, LibraryMetadataService, MetadataDTO

### Community 25 - "Community 25"
Cohesion: 0.12
Nodes (5): Exception, insert, update, LibraryRegistrationService, RegistrationException

### Community 26 - "Catalog & Books"
Cohesion: 0.12
Nodes (3): BookingDTO, LibraryRoomBookingService, RoomDTO

### Community 28 - "Community 28"
Cohesion: 0.12
Nodes (4): AuditDTO, update, LibraryStocktakeService, LineDTO

### Community 29 - "Payments & Fines"
Cohesion: 0.13
Nodes (12): auraConfig, { defineConfig }, eslintJs, globals, jestPlugin, lwcConfig, eslint@^9.29.0, @salesforce/eslint-config-lwc@^4.0.0 (+4 more)

### Community 30 - "Payments & Fines"
Cohesion: 0.13
Nodes (6): update, ConfigurationDTO, LibraryPaymentGatewayService, PaymentDTO, RefundDTO, WebhookDTO

### Community 32 - "Catalog & Books"
Cohesion: 0.16
Nodes (8): Acquisition_Recommendation__c, Book__c, Book_Category__c, Book_Copy__c, Book_Review__c, BookCopyInventoryTrigger, Library_Branch__c, Search_Analytics__c

### Community 33 - "Catalog & Books"
Cohesion: 0.14
Nodes (5): Book__c, ImportDTO, LibraryCatalogImportService, ParsedRow, RowDTO

### Community 34 - "Member & Auth"
Cohesion: 0.20
Nodes (3): AuthResult, update, LibraryMemberAuthController

### Community 35 - "Member & Auth"
Cohesion: 0.14
Nodes (3): HoldDTO, LibraryMembershipHoldService, MembershipStatusDTO

### Community 38 - "Payments & Fines"
Cohesion: 0.17
Nodes (3): AppealDTO, Fine__c, LibraryFineAppealService

### Community 39 - "Member & Auth"
Cohesion: 0.17
Nodes (3): insert, update, LibraryMemberAuthControllerTest

### Community 40 - "Member & Auth"
Cohesion: 0.17
Nodes (3): update, LibraryPrivacyService, RequestDTO

### Community 41 - "Community 41"
Cohesion: 0.17
Nodes (3): update, LibraryScanService, ScanResult

### Community 42 - "Circulation"
Cohesion: 0.17
Nodes (7): Borrow_Record__c, insert, update, Fine__c, Member__c, Reservation__c, LibraryTransactionContactServiceTest

### Community 45 - "Community 45"
Cohesion: 0.18
Nodes (10): agentType, companyDescription, companyName, enrichLogs, maxTopics, role, tone, topics (+2 more)

### Community 46 - "Member & Auth"
Cohesion: 0.18
Nodes (10): agentType, companyDescription, companyName, enrichLogs, maxTopics, role, tone, topics (+2 more)

### Community 47 - "Catalog & Books"
Cohesion: 0.18
Nodes (3): insert, Fixture, LibraryAgentActionsTest

### Community 48 - "Member & Auth"
Cohesion: 0.18
Nodes (5): insert, Library_Registration__c, Member__c, User, LibraryMemberProvisioningQueueableTest

### Community 49 - "Notifications"
Cohesion: 0.18
Nodes (5): AlertDTO, Candidate, Member__c, LibraryRiskInsightService, RunDTO

### Community 50 - "Catalog & Books"
Cohesion: 0.18
Nodes (5): Book_Copy__c, Borrow_Record__c, insert, Fixture, LibraryScanServiceTest

### Community 54 - "Community 54"
Cohesion: 0.18
Nodes (11): scripts, lint, precommit, prepare, prettier, prettier:verify, test, test:unit (+3 more)

### Community 55 - "Community 55"
Cohesion: 0.24
Nodes (3): header(), rect(), textbox()

### Community 56 - "Circulation"
Cohesion: 0.24
Nodes (4): Borrow_Record__c, Fine__c, Fine_Appeal__c, Reservation__c

### Community 58 - "Member & Auth"
Cohesion: 0.20
Nodes (3): Book__c, LibraryMemberReviewService, ReviewDTO

### Community 59 - "Notifications"
Cohesion: 0.20
Nodes (3): LibraryNotificationPreferenceService, PreferenceDTO, PreferenceInput

### Community 60 - "Payments & Fines"
Cohesion: 0.20
Nodes (4): update, LibraryPaymentOperationsService, ReceiptDTO, ReconciliationDTO

### Community 61 - "Community 61"
Cohesion: 0.20
Nodes (4): insert, update, Queueable, LibraryRegistrationProvisioningQueueable

### Community 62 - "Member & Auth"
Cohesion: 0.20
Nodes (4): insert, Queueable, User, LibraryRegistrationUserQueueable

### Community 63 - "Community 63"
Cohesion: 0.20
Nodes (3): update, LibraryRepairService, RepairDTO

### Community 69 - "Member & Auth"
Cohesion: 0.22
Nodes (6): Book_Author__c, Book_Category_Link__c, Book__c, insert, update, LibraryCatalogService

### Community 70 - "Community 70"
Cohesion: 0.28
Nodes (3): LibraryAgentApiController, MessageResponse, SessionResponse

### Community 72 - "Member & Auth"
Cohesion: 0.22
Nodes (4): CardDTO, insert, update, LibraryDigitalMemberCardService

### Community 74 - "Member & Auth"
Cohesion: 0.22
Nodes (4): insert, update, Fixture, LibraryMembershipHoldServiceTest

### Community 76 - "Tests"
Cohesion: 0.22
Nodes (4): insert, HttpCalloutMock, LibraryMetadataServiceTest, MetadataMock

### Community 81 - "Catalog & Books"
Cohesion: 0.25
Nodes (6): undelete, Book__c, delete, insert, update, LibraryBookInventoryServiceTest

### Community 82 - "Member & Auth"
Cohesion: 0.25
Nodes (4): Member__c, InsightDTO, LibraryDataCloudReadinessService, StatusDTO

### Community 83 - "Community 83"
Cohesion: 0.25
Nodes (4): Library_Scan_Transaction__c, LibraryLedgerMigrationReadinessService, OperationDTO, StatusDTO

### Community 84 - "Member & Auth"
Cohesion: 0.25
Nodes (3): Author__c, FollowDTO, LibraryMemberAuthorFollowService

### Community 85 - "Member & Auth"
Cohesion: 0.25
Nodes (3): insert, update, LibraryMemberSessionService

### Community 86 - "Member & Auth"
Cohesion: 0.25
Nodes (4): insert, Member__c, Membership_Payment__c, LibraryMembershipPaymentServiceTest

### Community 87 - "Member & Auth"
Cohesion: 0.25
Nodes (3): insert, Membership_Payment__c, LibraryPaymentGatewayServiceTest

### Community 88 - "Member & Auth"
Cohesion: 0.25
Nodes (3): insert, Fixture, LibraryPrivacyServiceTest

### Community 89 - "Community 89"
Cohesion: 0.25
Nodes (3): update, Queueable, LibraryRegistrationFailureQueueable

### Community 90 - "Tests"
Cohesion: 0.25
Nodes (3): insert, Fixture, LibraryReservationEtaServiceTest

### Community 94 - "Community 94"
Cohesion: 0.25
Nodes (3): NAV, PAGE_COPY, LibraryRegistrationRedirect

### Community 96 - "Catalog & Books"
Cohesion: 0.29
Nodes (3): insert, Fixture, LibraryAcquisitionInsightServiceTest

### Community 97 - "Tests"
Cohesion: 0.29
Nodes (3): AgentApiMock, HttpCalloutMock, LibraryAgentApiControllerTest

### Community 98 - "Member & Auth"
Cohesion: 0.29
Nodes (4): BookResult, Author__c, LibraryAgentCatalogAction, Request

### Community 99 - "Community 99"
Cohesion: 0.29
Nodes (3): update, LibraryAgentConfirmationService, PreviewDTO

### Community 100 - "Tests"
Cohesion: 0.29
Nodes (3): insert, Fixture, LibraryAgentConfirmationServiceTest

### Community 101 - "Member & Auth"
Cohesion: 0.29
Nodes (3): insert, update, LibraryDigitalMemberCardServiceTest

### Community 103 - "Member & Auth"
Cohesion: 0.29
Nodes (3): insert, update, LibraryMemberBorrowService

### Community 105 - "Member & Auth"
Cohesion: 0.29
Nodes (3): insert, Fixture, LibraryMemberEngagementServiceTest

### Community 118 - "Community 118"
Cohesion: 0.33
Nodes (3): update, LibraryAccessibilityService, PreferenceDTO

### Community 120 - "Catalog & Books"
Cohesion: 0.33
Nodes (4): update, LibraryAcquisitionInsightService, RecommendationDTO, Signal

### Community 122 - "Member & Auth"
Cohesion: 0.33
Nodes (3): insert, Fixture, LibraryMemberAuthorFollowServiceTest

### Community 124 - "Notifications"
Cohesion: 0.33
Nodes (3): DeliveryDTO, LibraryNotificationDeliveryService, SummaryDTO

### Community 127 - "Community 127"
Cohesion: 0.33
Nodes (3): update, Queueable, LibraryRegistrationFinalizeQueueable

### Community 128 - "Tests"
Cohesion: 0.33
Nodes (5): insert, update, Library_Registration__c, LibraryRegistrationServiceTest, Membership_Plan__c

### Community 138 - "Community 138"
Cohesion: 0.40
Nodes (3): LibraryAgentAnalyticsAction, Request, Response

### Community 139 - "Community 139"
Cohesion: 0.40
Nodes (3): LibraryAgentConfirmationAction, Request, Response

### Community 140 - "Member & Auth"
Cohesion: 0.40
Nodes (3): LibraryAgentMemberSummaryAction, Request, Response

### Community 141 - "Community 141"
Cohesion: 0.40
Nodes (3): LibraryAgentMyActivityAction, Request, Response

### Community 142 - "Community 142"
Cohesion: 0.40
Nodes (3): LibraryAgentMyLoansAction, LoanResult, Request

### Community 143 - "Community 143"
Cohesion: 0.40
Nodes (3): LibraryAgentMyReservationsAction, Request, ReservationResult

### Community 148 - "Catalog & Books"
Cohesion: 0.40
Nodes (3): Book_Copy__c, insert, LibraryRepairServiceTest

### Community 149 - "Tests"
Cohesion: 0.40
Nodes (3): insert, Library_Scan_Transaction__c, LibraryStocktakeServiceTest

### Community 175 - "Tests"
Cohesion: 0.50
Nodes (4): Build Artifacts & Test Output, Dependency Management Patterns, .gitignore Configuration, Salesforce Cache Patterns

### Community 176 - "Community 176"
Cohesion: 0.50
Nodes (3): { jestConfig }, @salesforce/sfdx-lwc-jest@^7.0.2, @salesforce/sfdx-lwc-jest

### Community 177 - "Community 177"
Cohesion: 0.50
Nodes (4): lint-staged, **/{aura,lwc}/**/*.js, **/*.{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}, **/lwc/**

### Community 212 - "Workflows"
Cohesion: 0.67
Nodes (3): force-app/main/default/, Salesforce DX Project, Workflows

## Knowledge Gaps
- **158 isolated node(s):** `update`, `insert`, `update`, `insert`, `insert` (+153 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1419 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **148 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `LibraryLibrarianWorkspace` connect `Member & Auth` to `Community 192`, `Circulation`, `Member & Auth`, `Payments & Fines`, `Catalog & Books`, `Community 112`, `Catalog & Books`, `Member & Auth`, `Community 94`, `Payments & Fines`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `PaymentRow` (e.g. with `Author__c` and `Member__c`) actually correct?**
  _`PaymentRow` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `update`, `insert`, `update` to the rest of the system?**
  _158 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Member & Auth` be split into smaller, more focused modules?**
  _Cohesion score 0.014265470004723665 - nodes in this community are weakly interconnected._
- **Why does `LibraryMemberShell` connect `Member & Auth` to `Catalog & Books`, `Community 27`, `Catalog & Books`, `Member & Auth`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Should `Member & Auth` be split into smaller, more focused modules?**
  _Cohesion score 0.015267175572519083 - nodes in this community are weakly interconnected._
- **Why does `LibraryMemberAccessibility` connect `Member & Auth` to `Member & Auth`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._