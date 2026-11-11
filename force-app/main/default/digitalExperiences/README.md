# `digitalExperiences/` — Experience Cloud (LWR) site

`site/Library1/` is a **DigitalExperienceBundle** for an Enhanced-LWR ("Build Your Own LWR") site. Each sub-folder is one content item with `_meta.json` and `content.json`. The site is served through the `Library` network (`networks/Library.network-meta.xml`) and the `Library` Salesforce site (`sites/`).

## Content types in the bundle

| Folder                                                                                           | Purpose                                                             |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| `sfdc_cms__site/Library1`                                                                        | Site-level settings.                                                |
| `sfdc_cms__theme/Build_Your_Own_LWR`, `sfdc_cms__brandingSet/Build_Your_Own_LWR`                 | Theme + brand tokens.                                               |
| `sfdc_cms__themeLayout/scopedHeaderAndFooter`, `…/snaThemeLayout`                                | Layouts that wrap pages.                                            |
| `sfdc_cms__styles/styles_css`, `print_css`                                                       | Site CSS (with `.css` source files).                                |
| `sfdc_cms__appPage/mainAppPage`, `sfdc_cms__languageSettings`, `sfdc_cms__mobilePublisherConfig` | App shell, language, mobile config.                                 |
| `sfdc_cms__route/*`                                                                              | URL → view mapping (18 routes).                                     |
| `sfdc_cms__view/*`                                                                               | Page definitions: the component tree (which LWCs sit on each page). |

## Routes → views → components (verified from `route` and `view` content)

| Route folder                                          | URL prefix                 | View                      | LWC placed on the view                     |
| ----------------------------------------------------- | -------------------------- | ------------------------- | ------------------------------------------ |
| `Home`                                                | `/`                        | `home`                    | `libraryLandingPage`                       |
| `Public_Explore_Books__c`                             | `/explore-books`           | `publicExploreBooks`      | `libraryPublicCatalog`                     |
| `Library_Registration__c`                             | `/register`                | `libraryRegistrationPage` | `libraryRegistration`                      |
| `Register`                                            | `/SelfRegister`            | `register`                | `libraryRegistration`                      |
| `Login`                                               | `/login`                   | `login`                   | `libraryMemberLogin`                       |
| `Forgot_Password`                                     | `/ForgotPassword`          | `forgotPassword`          | `libraryMemberAuthFlow`                    |
| `Check_Password`                                      | `/CheckPasswordResetEmail` | `checkPasswordResetEmail` | `libraryCheckEmail`                        |
| `Reset_Password__c`                                   | `/reset-password`          | `resetPassword`           | `libraryMemberAuthFlow`                    |
| `Activate__c`                                         | `/activate`                | `activate`                | `libraryMemberAuthFlow`                    |
| `Member_Portal__c`                                    | `/member`                  | `memberPortal`            | `libraryMemberPage` → `libraryMemberShell` |
| `Contact__c`                                          | `/contact`                 | `contact`                 | `libraryContact`                           |
| `Logged_Out__c`                                       | `/logout`                  | `loggedOut`               | `libraryLogoutState`                       |
| `News_Detail__c`                                      | `/news`                    | `newsDetail`              | standard CMS news component                |
| `Error`, `Service_Not_Available`, `Too_Many_Requests` | `/error`, …                | system views              | platform components                        |

## Working with it

- **Retrieve** after Experience Builder edits: `./scripts/retrieve-experience-site.ps1` (note: it expects an `ExperienceBundle`; for LWR digital experiences use `sf project retrieve start --metadata DigitalExperienceBundle:site/Library1`).
- **Publish** the site after every deploy for LWC changes to go live (Experience Builder → Publish, or `sf community publish --name Library`).
- Guest access: the public pages call `*GuestController` methods; guest/permission requirements are in `permissionsets/`.
- Do not hand-edit `content.json` unless you know the LWR schema; prefer Builder + retrieve.
