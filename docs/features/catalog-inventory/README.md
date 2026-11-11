# Catalog & inventory

## What it does

Manage books, copies, authors and categories; keep availability counts correct; import in bulk; enrich metadata from an ISBN; track damaged/lost copies; audit shelves; move copies between branches.

## Data

`Book__c`, `Book_Copy__c` (master-detail), `Author__c`/`Book_Author__c`, `Book_Category__c`/`Book_Category_Link__c`; ledger operations for imports, stocktakes, repairs, branches.

## Sub-features

### Catalog CRUD

`LibraryCatalogService` — `addBook`, `addCopy`, `retireCopy`, `updateBook`, `updateCopy`; permission `Manage_Library_Catalog`. UI: books/copies tabs in `libraryLibrarianWorkspace`.

### Availability counts

`BookCopyInventoryTrigger` → `LibraryBookInventoryService.recalculate(bookIds)`: `Total_Copies__c` = all non-deleted copies, `Available_Copies__c` = copies with status `Available`. Triggered on insert/update/delete/undelete and handles a copy moving between books.

### Search

Member/public: `LibraryMemberSessionController.searchCatalog`, `LibraryRegistrationGuestController.searchPublicCatalog` (≤50 results). `LibraryCatalogFuzzySearch.findByTitle` handles typos for the assistant. Searches may log a one-way SHA-256 hash to `Search_Analytics__c` (no raw text).

### Bulk CSV import (`libraryCatalogImport`)

`LibraryCatalogImportService.preview(csv)`: header must contain `title` and `isbn`; up to **200 rows**; row-level errors for missing, duplicate-in-file, or already-cataloged ISBNs. `executeImport(importKey, csv)` commits only if **every** row is valid; the stable `importKey` makes a retry a no-op; audited.

### ISBN enrichment (`libraryIsbnMetadata`)

`LibraryMetadataService.normalize/isValid` (checksum) → `lookup(isbn)` via Named Credential `Library_Metadata` (OpenLibrary) → preview with missing-field and possible-duplicate warnings → `apply(...)` writes **only selected fields**, rejects duplicate ISBNs, audits the field set. Provider failure leaves the catalog untouched.

### Repair lifecycle (`libraryRepairCases`)

`LibraryRepairService.open/openByBarcode` allowed only for copies `Damaged`, `Lost` or `Maintenance` (borrowed copies must be returned first) → copy becomes `Maintenance`. `resolve` once: **Repaired** → `Available`/`Good`; **Unrepairable** → `Retired`/`Poor`. Idempotent and audited. Member-side defect reports use `reportDefectiveLoan` and `libraryDamageReplacementPanel` (replacement days/required fields on `Borrow_Record__c`).

### Stocktake (`libraryStocktake`)

`start(name, scope)` → `scan(auditId, barcode, …)` records expected vs observed status and notes per barcode (idempotent per audit) → `close(auditId, summary)`. Never changes copy status automatically; reconciliation is a separate reasoned action.

### Branches & transfers

`LibraryBranchService`: `createBranch`, `assignCopy`, `requestTransfer` → `shipTransfer` → `receiveTransfer` (destination assignment changes only on receipt; one active transfer per copy).

## Tests

`LibraryBookInventoryServiceTest`, `LibraryCatalogImportServiceTest`, `LibraryMetadataServiceTest`, `LibraryRepairServiceTest`, `LibraryStocktakeServiceTest`, `LibraryBranchServiceTest`, `LibraryAgentCatalogFuzzyTest`.
