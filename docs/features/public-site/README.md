# Public website & Experience site

## What visitors see

Landing page (hero, live stats, membership plans with display currency, catalog search, AI chat), Explore Books, Contact, Register, Login / Forgot / Reset / Activate, Logged-out screen. After login the member lands on `/member` (`libraryMemberPage` → `libraryMemberShell`).

## Implementation

- Site: LWR "Build Your Own LWR" digital experience `Library1` → [digitalExperiences README](../../../force-app/main/default/digitalExperiences/README.md) (route/view/component table).
- Guest-facing Apex: `LibraryRegistrationGuestController` (`getActivePlans`, `getInterestOptions`, `getLibraryStats`, `getDisplayCurrency`, `getPaymentQuote`, `searchPublicCatalog`, `submitRegistrationWithPayment`), `LibraryContactController` (`getBranches`, `submitMessage`), `LibraryPublicAgentController`.
- Guest data access: sharing rules grant guest user `Library` read on **active books** and **plans** only ([sharingRules README](../../../force-app/main/default/sharingRules/README.md)); everything else is exposed through narrow Apex DTOs.
- Branding: static resource `LibraryAuthHero`, shared CSS in site `styles_css`, components `libraryAuthHero`, `libraryAuthNav`, `libraryLoginHeading`, `librarySignupLink`.
- Member session: token kept client-side by the shell; protected calls pass it to `LibraryMemberSessionController`.

## Go-live checklist

1. Deploy core package. 2. Activate the _Library_ network and site. 3. **Publish** the site in Experience Builder (LWC changes aren't live until published). 4. Verify guest sharing (books/plans visible signed out). 5. Publish/activate the public agent and set label `Library_Public_Agent_Id`. 6. Load demo data if needed.

## Tests

Jest: `libraryLandingPage`, `libraryPublicCatalog`, `libraryRegistration`, `libraryRegistrationRedirect`, `libraryContact`, `libraryMemberLogin`, `libraryMemberAuthFlow`, `libraryAuthHero`, `libraryAuthState`, `libraryLoginHeading`, `libraryLogoutState`, `librarySignupLink`, `libraryMemberPage`, `libraryMemberShell`.
