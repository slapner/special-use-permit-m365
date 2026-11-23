## Changes in this rewrite

This file records what changed against `docs/build-guide.md`, which validator item each change resolves, what was not adopted, problems found in the kit, and what still needs a tenant.

### Counts

| Group | Total | Resolved in the text | Carried as "Test in your tenant" | Not adopted |
| --- | --- | --- | --- | --- |
| WRONG rows | 33 | 33 | 0 | 0 |
| INCOMPLETE rows | 66 | 66 | 0 | 0 |
| VERIFY rows | 11 | 0 | 11 | 0 |
| Missing steps M1–M14 | 14 | 14 | 0 | 0 |
| Contradictions C1–C17 | 17 | 17 | 0 | 0 |
| Sequence problems | 8 | 8 | 0 | 0 |

Every non-OK row is resolved or carried. In 10 places the row is resolved with the kit's design instead of the validator's exact fix. Those are listed under "Validator fixes not adopted as written".

The guide holds 40 "Test in your tenant" notes in all. They cover the 11 VERIFY rows, the validator's "Could not verify" list, the kit's own "verify" marks, and the points this rewrite could not confirm. Step 9.1 lists them as one checklist.

### Structure changes

- **Flow IDs.** "Flow 1" to "Flow 8" are gone. The guide uses the kit's IDs. One count, 13 flows, is stated in Step 4.1 with its rule.
- **Delivery order.** The overview adds six delivery stages. Stage 1 is a minimum working system on standard licences.
- **Phase 0** gains "Who needs Premium", the government table, the IT request list and the steps to create the solution.
- **Phase 1** leads with the test site and the setup script. Groups and permissions moved here from Phase 8, as Step 1.6.
- **Phase 4** opens with the flow table, one-time setup, how to read the action tables and the rules for every flow. Each flow is a table of action, rename-to, field and value, with long expressions in labelled blocks after it.
- **Phase 4 flow order** is the build order: F7a, F1b, F1a, F7b, F5, F8, F2a, F2b, F3, F4, F9. F6 stays in Phase 5.
- **F4** is four separate paths (A DocuSign, B Adobe Acrobat Sign, C signed upload and approval, D SharePoint eSignature).
- **Phase 6** is a build order of eleven steps, starting from the app generated from the Permits list.
- **Phase 8** keeps the roles table, the audit layers, retention and operations. It now checks the groups instead of building them.
- **Phase 9** gains Step 9.2 (create production) and the full F10 migration flow. The old Steps 9.2 and 9.3 are now 9.3 and 9.4.
- **Appendix** gains the ID mapping table and the validator's sources.

### Validator rows, by section

"TENANT TEST" marks a VERIFY row carried as a note at the step named.

#### Phase 0: Prerequisites and decisions

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 1 | WRONG | Decision: Licensing budget. "Premium is needed only for the account that owns those flows" | Phase 0 'Who needs Premium' and F3 'Licensing, stated once', using the validator's wording |
| 2 | INCOMPLETE | Accounts 1: service account | Phase 0 Accounts items 1–2 (sign-in policy, password rotation, OneDrive) and 'Create the solution' (build signed in as the account) |
| 3 | INCOMPLETE | Accounts 2: "You need SharePoint site owner rights" | Phase 0 Accounts item 4 (SharePoint Administrator; self-service site creation) |
| 4 | INCOMPLETE | Accounts 3: shared mailbox | Phase 0 Accounts item 3 (Full Access and Send As) |
| 5 | INCOMPLETE | Accounts 4: environment or Solution | Phase 0 'Create the solution' and the Managed Environment warning |

#### Phase 1: SharePoint site

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 6 | INCOMPLETE | 1.1.3 add owners | Step 1.1 item 4 (Share site, Full control) |
| 7 | INCOMPLETE | 1.2.5 PermitConditions | Step 1.2 note 'Lookups show Title'; F2a action 10.4Y.1 sets Title to the condition code |
| 8 | INCOMPLETE | 1.2.6 ComplianceItems | Step 1.2 table: both dates are 'date only' |
| 9 | INCOMPLETE | 1.2 (missing) Title is required on every new list | Step 1.4 item 1 (Title optional on four lists) |
| 10 | VERIFY | Column: 'PermitNumber' "enforce unique" | TENANT TEST at Step 1.2 (two blank permit numbers) |
| 11 | INCOMPLETE | Column: 'Coordinator', 'Superintendent' "(default from Settings)" | Step 1.2 Settings rows DefaultCoordinator and DefaultSuperintendent; F1b add-on A |
| 12 | WRONG | Column: 'ComplianceComplete' filled by "Compliance staff" | Step 1.2 Permits table: filled by the coordinator |
| 13 | INCOMPLETE | Columns: 'FolderUrl', 'FolderPath', hidden text columns | Step 1.4 item 4 (Edit form → Edit columns) |
| 14 | INCOMPLETE | 1.3.4 "Make a Templates library (or folder)" | Step 1.3 item 4: folder `_Templates` in Permit Records |
| 15 | INCOMPLETE | 1.3.5 versioning on the library | Step 1.4 item 2 (versioning on the Permits list, 100 versions) |
| 16 | INCOMPLETE | 1.4 views | Step 1.5: the kit's six view names and filters |

#### Phase 2: Condition library

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 17 | INCOMPLETE | 2.2.2 "import with the setup script, or paste into … grid view" | Step 2.2 (replace the rows of the seed CSV, `;` separators, re-run the script); grid paste carried as a tenant test |
| 18 | WRONG | 2.4 "Give the program lead Edit on the library" | Steps 1.6 and 2.4: program lead in SUP Owners, or Contribute on ConditionLibrary |
| 19 | INCOMPLETE | 2.4 "the Changed this year view" | Step 2.4: the *Changed this year* view is defined, and marked as not created by the script |

#### Phase 3: Intake form

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 20 | WRONG | 3.1.1 "owned by the shared mailbox or a group" | Step 3.1 items 1–2 and the group-form note; F1a trigger note |
| 21 | WRONG | 3.1.2 "Settings → Who can fill out this form → Anyone can respond" | Step 3.1 item 3 (Collect responses → Anyone can respond) and the greyed-out note |
| 22 | WRONG | 3.1.3 questions, "each with a one-line hint" | Step 3.1 rules: exact option text, hints in the subtitle, no Other option, Required column |
| 23 | INCOMPLETE | 3.2 Reply-with-files: "A second flow on the shared mailbox…" | F8 fully specified in Phase 4; Step 3.2 explains its naming limit |
| 24 | WRONG | 3.2 Upload link: "The flow sends a SharePoint Request files link" | Step 3.2: the coordinator creates the Request files link by hand; needs *Anyone* links |
| 25 | INCOMPLETE | 3.4 test | Step 3.4 points to 'Check it works' at the end of F1b |

#### Introduction and Flow 1

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 26 | WRONG | "Seven flows do the work" | Step 4.1 count rule: 13 flows, used in the overview and the diagram labels |
| 27 | INCOMPLETE | Rule 2: AuditLog row per change | Step 4.4 audit field table and F7a |
| 28 | WRONG | F1.2 "map each answer to its column" (PermitType) | F1a actions 3Y.3–3Y.5 (Get items Type, Permit Type Id) |
| 29 | INCOMPLETE | F1.2 Impacts: "use 'json((answer))' in an Apply to each" | F1a actions 3Y.1–3Y.2 (Select Impacts with an empty-answer guard, input entire array) |
| 30 | WRONG | F1.2 'ReceivedDate' = 'utcNow()' | F1a Received Date uses the local-date expression |

#### Flow 2: New permit setup

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 31 | WRONG | F2.1 Year: 'formatDateTime(utcNow(),'yyyy')' | F1b expression F1b-A (kit: year from ReceivedDate or local time) |
| 32 | WRONG | F2.2 Get items on Settings; "If none comes back … Create item with Value '1' and use 1 | F1b actions 5–6N.2 (kit's Condition Seq row exists block) |
| 33 | WRONG | F2.3 Seq: 'int(first(body('Get_items_Settings')?['value'])?['Value'])' | F1b action 6Y.1 runs only when a row exists; 6N.1 sets 1 |
| 34 | WRONG | F2.5 Update item on Settings: Value = 'add(outputs('Seq'), 1)' | F1b action 6Y.2 (Id, Title, Value as text) |
| 35 | INCOMPLETE | F2.9 Create new folder: "library PermitRecords, folder path '/Open Projects/…'" | F1b action 14 (library display name, no leading slash) |
| 36 | VERIFY | F2.10 Update item: "FolderUrl = the folder's link from step 9" | TENANT TEST at F1b ({Link} from Create new folder, with the fallback expression) |
| 37 | INCOMPLETE | F2.10 "Coordinator and Superintendent defaults if blank" | F1b add-on A (Claims expressions F1b-L and F1b-M) |
| 38 | INCOMPLETE | F2.11 AuditLog Created | F1b action 17 lists all five audit fields |

#### Flow 3: Suggest conditions

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 39 | INCOMPLETE | Trigger: Power Apps (V2) with input 'PermitId' | Step 4.4 'Use the service account's connection'; repeated at F2b, F3, F4a; checked in Step 8.1 |
| 40 | INCOMPLETE | "Optionally also run it when Status changes" | F2a (status trigger) and F2b (app trigger) are two flows |
| 41 | VERIFY | F3.2 Select PermitImpacts from 'body('Get_item')?['Impacts']' | TENANT TEST at F2a (permit with no impacts; coalesce already in action 6) |
| 42 | VERIFY | F3.4 filter 'Permit/Id eq @{triggerBody()?['PermitId']}' | TENANT TEST at F2a and F2b (filter form; Peek code); the filter reads the ID from Get item Permit |
| 43 | INCOMPLETE | F3.5.1 Select Triggers | F2a action 10.2 uses coalesce |
| 44 | INCOMPLETE | F3.5.2 Select Types | F2a action 10.1 uses coalesce |
| 45 | INCOMPLETE | F3.5.3 "Condition (advanced mode)" with '@and(…)' | F2a actions 10.3–10.4 (Compose Match, Condition is equal to true) and the note on advanced mode |
| 46 | INCOMPLETE | F3.5 Create item in PermitConditions | F2a action 10.4Y.1 lists every field including Title |
| 47 | INCOMPLETE | F3.6 "'Conditions suggested: n'. Return the count to the app." | F2a varAdded and Increment; F2b step 6 Respond with `added` |

#### Flow 4: Generate the draft permit

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 48 | WRONG | Trigger: Power Apps (V2) | F3 'Licensing, stated once'; Run only users at F3 |
| 49 | VERIFY | F4.2 filter 'Permit/Id eq @{triggerBody()?['PermitId']} and Included eq 1' | TENANT TEST at F3 shared actions (filter form; Peek code) |
| 50 | WRONG | F4.3 Select ConditionRows: keys 'Code' and 'Text' | F3 version 2 action 11 and the template steps use ConditionCode and ConditionText |
| 51 | INCOMPLETE | F4.4 Populate a Microsoft Word template in a Switch, one branch per type | F3 version 2: one master template; Switch alternative with Compose DraftContent |
| 52 | WRONG | F4.5 file name "'…_DraftPermit_v@{n}.docx'" | F3 actions 8–10 and expression F3-D (kit: highest existing number plus one) |
| 53 | VERIFY | F4.5 "List folder, then Filter array" | TENANT TEST at F3 (Get files (properties only) and Limit Entries to Folder) |
| 54 | INCOMPLETE | F4.6 set DocType, status, audit | F3 actions 14–18 name every action and field; Respond closes the flow |
| 55 | INCOMPLETE | Standard-licence fallback | F3 version 1 states that only Permit Number and Doc Type fill in, with the add-on for more columns |

#### Flow 5: Signature routing

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 56 | WRONG | Trigger "Permits When an item is modified" | No flow uses that trigger name; F4a is app-started per the kit |
| 57 | INCOMPLETE | (missing) who sets 'Out for Permittee Signature' | F4a action 12; app button btnMarkSent and path C step 3 for paths without F4a |
| 58 | INCOMPLETE | E-sign 1: Convert Word Document to PDF "on the latest draft" | F4a action 4 (Get files Draft, newest Word draft) |
| 59 | INCOMPLETE | E-sign 1: "OneDrive for Business → Convert file" on standard licences | F4a actions 7–11 (OneDrive Create file, Convert file, Delete file) |
| 60 | INCOMPLETE | E-sign 2: "create and send a request with signing order on" | F4 path A and path B tables name each connector action |
| 61 | VERIFY | E-sign 4: "signer completed / envelope status changed event" | TENANT TEST at F4b 'Recording that the permittee has signed' |
| 62 | INCOMPLETE | (missing) declined, voided or redrafted | F4b declined and voided cases; F3 clears the request when a draft is regenerated; F4c Reject clears the date |
| 63 | WRONG | Fallback 1: convert and email | Path C follows the kit: the coordinator emails the PDF by hand and F4c starts from the uploaded file, so nothing re-sends |
| 64 | INCOMPLETE | Fallback 2: attachment flow files the copy, coordinator enters PermitteeSigned | Path C 'What people do' steps 4–5 and F8 |
| 65 | INCOMPLETE | Fallback 3: "A flow triggered by PermitteeSigned being filled" | F4c (kit design): file-created trigger, sets Out for Superintendent Signature, 29-day timeout branch |
| 66 | INCOMPLETE | Fallback 4: on Approve / Reject | F4c action 8 tests `Approve`; action 8N.1 clears Permittee Signed |
| 67 | WRONG | SharePoint eSignature: "… → eSignature" | Path D step 2 gives Microsoft's pen icon and the kit's menu name; carried as a tenant test |

#### Flow 6 and Flow 7

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 68 | WRONG | F6 trigger name | F5 trigger is 'When an item or a file is modified' |
| 69 | VERIFY | F6.1 Move folder | TENANT TEST at F5 (typed path, option label, IDs and version history) |
| 70 | INCOMPLETE | F6.2 Update item | F5 actions 11–12 and expression F5-D |
| 71 | WRONG | F7 trigger "When an item is modified (no trigger condition)" | F7b trigger is 'When an item or a file is modified' |
| 72 | INCOMPLETE | F7.1 Get changes…, Since = 'triggerOutputs()?['body/{TriggerWindowStartToken}']' | F7b action 1 (rename, Id, Since) and the versioning prerequisite |

#### Phase 5: Scheduled reminders (Flow 8)

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 73 | INCOMPLETE | F8.1 'split((Value of ReminderDaysPermitExpiry), ',')' | F6 actions 3–10 (Filter array per setting, then split) |
| 74 | VERIFY | F8.3 filter 'PermitExpiration eq '…' and Status ne …' | TENANT TEST at F6 (exact-date filter, with two alternatives) |
| 75 | INCOMPLETE | F8.3 "Append each result to Hits with a reason" | F6 actions 14–16 and the row map replace the Hits variable (kit design) |
| 76 | INCOMPLETE | F8.4 expired-COI list "every Monday" | F6 'Optional additions' with the Monday test in expression F6-K |
| 77 | INCOMPLETE | F8.6 group by coordinator with 'union()' | F6 actions 18–20.1 |
| 78 | INCOMPLETE | F8.7 HTML table with a link column | F6 note: the Link column is a plain address, so nothing is escaped (kit design) |
| 79 | WRONG | F8.8 "stamp 'LastReminderKey' … so a re-run on the same day sends nothing twice" | F6 action 17 (Filter array Due) reads the key before sending; action 21 writes it |

#### Phase 6: Coordinator app

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 80 | INCOMPLETE | 6.1.1 make.powerapps.com → Solutions → New → App → Canvas app | Step 6.2 (service account, government note, add to the solution) |
| 81 | INCOMPLETE | 6.1.2 add SharePoint data sources | Step 6.3 item 1 includes Settings |
| 82 | INCOMPLETE | 6.2 Home: counts | Steps 6.1 and 6.10 state when counts are exact |
| 83 | INCOMPLETE | 6.2 Permit record, Conditions tab | Step 6.7 gives every formula for the toggle, the text, Suggest and Add from library |
| 84 | INCOMPLETE | 6.2 Documents tab: "Gallery on PermitRecords filtered by PermitNumber" | F9 stamps hand-uploaded files; Step 6.8 explains why path filters do not work |
| 85 | INCOMPLETE | 6.3 Suggest conditions button | F2b is named `SUPSuggestConditions` and ends with a response; formula 6-I |
| 86 | WRONG | 6.3 'Visible: varIsApprover && ThisItem.Status.Value = …' on "Superintendent approves" | Step 6.5: the approve button is replaced by the read-only label lblWaiting |
| 87 | INCOMPLETE | 6.3 'varIsApprover' "from … Office 365 Groups connector or a Settings row" | Step 6.3 formula 6-A and the Approvers row in Step 1.2 |
| 88 | WRONG | 6.4 "first 500 rows (2,000 at most…)" | Step 6.1 'Lists are read in limited slices' uses the validator's wording |
| 89 | INCOMPLETE | 6.4 "Keep the home-screen counts on indexed columns with simple filters" | Step 6.1 'Counts are exact only for small sets' |
| 90 | WRONG | 6.5 "Share the app with the three SharePoint groups' members" | Step 6.11 and Phase 0 Accounts item 6 (Entra security groups) |

#### Phase 7: Dashboard and reporting

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 91 | INCOMPLETE | 7.1 List web part, "Needs attention, Awaiting signature, Expiring in 60 days" | Step 7.1 pins *COI expiring*, *Awaiting signature* and *Expiring in 60 days* |
| 92 | VERIFY | 7.2.2 "expand Status and PermitType to their values" | TENANT TEST at Step 7.2 (column shapes; Impacts not expanded) |
| 93 | VERIFY | 7.2.2 (missing) dates | TENANT TEST at Step 7.2 (date-only values) |
| 94 | WRONG | Measure 'COI Expiring 30d' | Step 7.2 measure excludes closed, withdrawn and denied permits |
| 95 | INCOMPLETE | 7.2.5 publish, scheduled refresh, web part, Teams tab | Step 7.2 items 9–11 (shared workspace, credentials, refresh) and the government address |

#### Phase 8: Roles, permissions, audit, retention

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 96 | WRONG | Table: SUP Owners "Edit" on Condition library | Steps 1.6 and 8.1 tables: SUP Owners Full Control |
| 97 | WRONG | Table: SUP Compliance "Edit on ComplianceItems" | Steps 1.6 and 8.1 tables: SUP Compliance Contribute |
| 98 | INCOMPLETE | 8.1.1 create the groups | Step 1.6 items 1–2 and 6 (click path, site levels, default groups emptied) |
| 99 | INCOMPLETE | 8.1.2 stop inheriting on AuditLog, ConditionLibrary, Settings | Step 1.6 items 3–4 cover all five lists |
| 100 | WRONG | 8.1.3 "give SUP Compliance Edit" | Step 1.6 item 3: Contribute |
| 101 | INCOMPLETE | (missing) flows started from the app | Step 4.4 and the last check in Step 8.1 |
| 102 | INCOMPLETE | 8.3.2 publish a retention label "7 years after closure" | Step 8.3 (label that starts when labelled; requested in Phase 0; up to seven days) |
| 103 | WRONG | 8.3.3 "Set retention label in the SharePoint connector" | Step 8.3: default label on the Closed Projects folder; inheritance and SetComplianceTag carried as a tenant test |
| 104 | INCOMPLETE | 8.4 ownership, connections, export | Step 1.3 item 7 and Step 1.6 item 5 create the SUP Admin library |

#### Phase 9: Test, migrate, go live

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 105 | INCOMPLETE | 9.1.1 test site with the script | Step 4.2 'Moving from the test site to production' and Step 9.2 |
| 106 | INCOMPLETE | 9.1.2 load 'Permits-sample.csv' | Step 9.1 item 1 and Phase 1 Option A item 4 (`-ImportSamplePermits`) |
| 107 | WRONG | 9.2.3 "Turn off Flow 2 during import" | Step 9.3 item 5 and the paragraph that explains why |
| 108 | WRONG | 9.2.3 "the script's CSV import" | Step 9.3 item 6 (grid view in batches) and the note that the script cannot import the tracker |
| 109 | INCOMPLETE | 9.2.4 move folders, "one-time flow that matches folder names to permit numbers" | Step 9.3 items 7–9 and flow F10 |

#### Appendix claims

| # | Verdict | Validator row | Where it is resolved |
| --- | --- | --- | --- |
| 110 | INCOMPLETE | "'kit/flows.md' … every flow in Phases 4 and 5" | Appendix mapping table; the guide now uses the kit's IDs |

### Fixes from rows the validator marked OK

The validator attached fixes to some OK rows. These are adopted too.

- Government portal addresses (Phase 0 table and Steps 4.2, 6.2, 7.2).
- Folder names: repeated dots collapsed and a trailing dot removed (Phase 0 naming rule; kit expressions F1b-C to F1b-F). A leading dot cannot occur, because the name starts with the permit number.
- The short-name tip applies to list names (Step 1.2).
- `TemplateFile` is read only by F3's standard-licence version (Step 1.2).
- "Can add values manually" off; Status default `Received`; dates as date only; regional time zone first (Steps 1.1 and 1.2).
- Trigger condition click path; one row per condition (Step 4.3).
- Group form ID and the Response Id token (F1a).
- Concurrency on a SharePoint trigger cannot be undone (Step 4.3).
- Refresh a flow in the app after changing it (Step 6.3). `AllowEmptySelection` and `Choices(Permits.Status)` (Step 6.4).
- `Days to Execute` skips blank received dates (Step 7.2). Site root address and view mode All (Step 7.2).
- "Nobody except owners" can edit AuditLog (Step 9.1). Closed Date filled on migrated rows (Step 9.3).
- Run-after settings named for the error scope; the 90-day rule (Step 8.4).
- Hardening list: the two items the validator wanted in version one are now built (appendix).

### Missing steps M1–M14

| Item | Where it is now |
| --- | --- |
| M1 Mailbox attachment flow | F8 in Phase 4 |
| M2 Stamp PermitNumber on uploads | F9 in Phase 4 |
| M3 Create the solution; build as the service account | Phase 0 "Create the solution"; Step 4.2 |
| M4 Mailbox rights | Phase 0 Accounts item 3 |
| M5 Run-only connection | Step 4.4, repeated at F2b, F3 and F4a |
| M6 Versioning on Permits | Step 1.4 item 2 |
| M7 Title optional | Step 1.4 item 1 |
| M8 Who sets Out for Permittee Signature; the reset | F4a action 12; `btnMarkSent`; resets in F3, F4b and F4c |
| M9 Default Coordinator and Superintendent | F1b add-on A; Step 1.2 Settings rows |
| M10 Test-to-production promotion | Step 4.2; Step 9.2 |
| M11 Site time zone | Step 1.1 item 5 |
| M12 Break inheritance on two more lists; empty default groups | Step 1.6 items 3 and 6 |
| M13 Power BI credentials | Step 7.2 item 10 |
| M14 Failure path for Move folder | F5 actions 8 to 10 |

### Contradictions C1–C17

| Item | Resolution |
| --- | --- |
| C1 Flow count | One count, 13, with its rule in Step 4.1. Overview, Phase 4 and the diagram labels agree |
| C2 Flow numbering | The kit's IDs everywhere. Mapping table in the appendix |
| C3 Group count | Five groups everywhere |
| C4 View names | The kit's six names. *Changed this year* is defined in Step 2.4. *Needs attention* is gone |
| C5 Site type | Communication site |
| C6 Templates | `PermitRecords/_Templates` |
| C7 FolderPath format | Server-relative, as the kit stores it. Flows strip the site part with Compose SiteRel |
| C8 Edit vs Contribute | Contribute |
| C9 F4 trigger | The kit's designs: app button for F4a, uploaded file for F4c |
| C10 F2 trigger and filter | The kit's two triggers as F2a and F2b; `PermitId eq`, with `Permit/Id eq` as the tenant-test fallback |
| C11 F1b email | The kit's email to the coordinator. The applicant email is add-on B |
| C12 F6 status filter | The kit's filters, shown in a table at the top of F6 |
| C13 Word control names | `ConditionCode` and `ConditionText`, matched on Title |
| C14 ComplianceComplete | Set by the coordinator |
| C15 Approver button | Replaced by a read-only label |
| C16 Script prerequisites | SharePoint Administrator plus the app registration |
| C17 Audit detail | The kit's "old → new" detail from version history |

### Sequence problems

| Problem | Resolution |
| --- | --- |
| Solution and service-account sign-in | Created in Phase 0; repeated as Step 4.2 item 1 |
| Groups and permissions built too late | Moved to Step 1.6 |
| Step 3.4 test needs flows | Moved to the end of F1b |
| Mailbox attachment flow | F8, seventh in the build order |
| F2b, F3, F4a need the app | Step 4.1 says to use Test → Manually until the app exists |
| F4 needs a status no step set | F4a sets it; paths C and D set it by hand or with `btnMarkSent` |
| Retention label requested too late | Requested in Phase 0 Accounts item 7 |
| "Build in a test site first" came last | Now the lead of Phase 1 |

### The five things most likely to make a builder give up

1. **Unnamed actions and two numbering schemes.** Every action has a rename-to name. A script checked that every `body()`, `outputs()` and `items()` reference is defined earlier in the same flow.
2. **The permit number counter.** F1b uses the kit's block, with the trigger condition.
3. **The Word template flow.** F3 ships the standard-licence version first. The Premium version uses one master template, a list of control titles and a real version number.
4. **Signature routing.** One path per section, with action names and guards.
5. **The app.** A build order from the generated app, with each control's name and formula.

The runner-up, the reminder flow, is now a 21-action table.

### Validator fixes not adopted as written

Each row is still resolved. The kit's design is used where the two differ, as instructed.

1. **Draft version number.** The validator counts existing drafts. The kit takes the highest number plus one, which survives a deleted draft.
2. **F2 lookup filter.** The validator uses `Permit/Id eq`. The kit uses `PermitId eq`. The validator's form is the tenant-test fallback.
3. **F4 trigger and guard.** The validator keeps an item-modified trigger with a `PENDING` stamp. The kit uses an app button. The `PENDING` stamp is kept as a double-press guard.
4. **Fallback email flow.** The validator repairs the old "convert and email" flow with an `EMAIL-` stamp. The kit has the coordinator email the PDF, so no stamp is needed.
5. **Fallback approval trigger.** The validator triggers on `PermitteeSigned` being filled. The kit triggers on the uploaded signed file.
6. **Reminder row shape and keys.** The validator appends to a Hits variable with keys like `EXP30:2026-11-23`. The kit builds rows with Select and keys like `EXP:2026-11-23`.
7. **Expiry reminder scope.** The validator keeps every permit that is not closed. The kit limits expiry reminders to Executed and Active.
8. **HTML table links.** The validator un-escapes link tags. The kit puts a plain address in the Link column, so nothing needs un-escaping.
9. **Title on new items.** The validator offers Title = `Pending`. The guide makes Title optional, as the script does.
10. **Flow count wording.** The validator suggests "eight numbered flows, plus three helper flows". The guide counts 13 by the kit's IDs.
Also not adopted: the architecture review's larger changes (Counters list, ReminderLog, SignatureStatus, CloseReason, Reviews, restricted library, Document IDs). They stay on the hardening list, as before.

### Additions beyond the kit

These are labelled in the text as not in the kit.

- **F8, F9 and F10** (validator M1, M2 and row 109).
- **F1b add-on A** (default Coordinator and Superintendent) and **add-on B** (applicant acknowledgement from the shared mailbox).
- **F5 action 4**, Get items Mailbox, so the failure email has an address.
- **F3 Update item:** two `null` fields that clear the signature request when a draft is regenerated.
- **F3 version 1:** Get file content using path, then Create file, in place of the kit's Copy file and rename. An optional email until the app exists. A `conditions` output.
- **F4a:** the Ready to send check, the `PENDING` stamp, and the Standard OneDrive PDF conversion in place of the kit's Premium action. The kit's action is given as the alternative.
- **F4b:** the Permit found check; clearing the request on decline.
- **F4c:** a second trigger condition, a 29-day timeout with an email, and clearing Permittee Signed on Reject.
- **Actor for app-started flows:** an expression that reads the caller's email from the trigger headers and falls back to `app user`.
- **F6:** the optional Monday list of expired COIs.
- **Manual items the script does not create:** the SUP Admin library, the *Changed this year* view, the Settings rows `Approvers`, `DefaultCoordinator` and `DefaultSuperintendent`, and extra library columns for Quick Parts.
- **App:** `varCanEdit` from `DataSourceInfo`, used to hide action buttons.

Build order differs from the kit README in one way. The README builds F6 after F2 and F1a last. This guide builds F1a third and F6 sixth, because the brief puts both in the minimum working system.

### Problems found in the kit

The kit was not edited. These need a decision by its owner.

1. **`kit/flows.md` F1b step 2:** `varSettingsId` is initialised and never used. The guide leaves it out.
2. **F2 option B:** the example flow name is "SUP – Suggest Conditions (app)", but the app calls `SUPSuggestConditions.Run(ThisItem.ID)`. The name with spaces would not produce that call. `ThisItem` also works only inside a gallery. The guide names the flow `SUPSuggestConditions` and passes `varPermit.ID`.
3. **F5 step 2.2:** the failure email goes to "the program mailbox", but F5 never reads `ProgramMailbox` from Settings.
4. **F5 step 3:** it follows a Terminate, with run-after "is skipped". The designer may not allow an action after a Terminate. Not confirmed either way. The guide gives a parallel-branch alternative.
5. **F3 standard fallback, step 3.2:** "rename the file with Move file" has no working action. Move file has no new-name field. The kit marks it "verify".
6. **F3 standard fallback:** the conditions block is "returned to the app", but no output name is given. The early response at step 4 would also need that output.
7. **F4a:** nothing stops a second send, and nothing clears `SignatureRequestId` when a request is declined. The permit could then never be sent again.
8. **F4a licensing:** the PDF step is Premium and F4a is app-started. The kit and its README do not say that each person who runs it needs Premium, or that the flow needs a Process licence.
9. **F3 licensing line:** "needs Power Automate Premium or a per-flow licence" omits the per-person rule for app-started flows.
10. **SharePoint eSignature:** the kit says "… → Request signatures". Microsoft's page, as quoted by the validator, says to select the pen icon in the viewer.
11. **F7a:** the Actor input is not marked optional, though callers may leave it blank. The response action carries its older name.
12. **AUDIT notation:** it does not say what Actor to pass in app-started flows, where no item author or editor is in the trigger.
13. **F6 step 4:** the canonical date expression uses `utcNow()` while Compose Today is local. The kit notes the risk but keeps the UTC form as the default.
14. **`kit/README.md` run order:** F6 is built after F2, and F1a last. That does not match a minimum-system-first delivery.
15. **Script gaps, not errors:** no SUP Admin library, no *Changed this year* view, no `Approvers` or default-person Settings rows, and the service account is not added to SUP Owners. The README states the last one.

### Self-check results

- **Format lint:** all 12 section files start with a `## ` heading. No H1, horizontal rule, HTML outside code, image, footnote, indented fence, indented table or numbered item directly after a fence. Every table has a constant column count. No pipe sits inside inline code in a table.
- **Kit expressions:** 170 distinct expressions were pulled from `kit/flows.md`. 146 appear in the guide unchanged, ignoring line breaks and indentation. The other 24 are placeholders or prose fragments, such as `int(...)` and `P?['ID']`.
- **References:** every `body()`, `outputs()`, `items()` and `actions()` reference in an action table is defined earlier in the same flow. Three known exceptions: F2b reuses F2a's actions by reference, and the two example names in F3's Switch note.
- **Balance:** every inline expression and fenced block has balanced parentheses, brackets and quotes. The checker understands doubled single quotes.
- **Names that contradict the kit:** no hits for "Flow 1" to "Flow 9", "22 sample", "Closed this year", "Active –", "three SharePoint groups", "When an item is modified", "Set retention label", "Seven flows" or "8 flows". "Edit" as a permission appears only where the text says not to use it. The old flow numbers appear only in `diagram-labels.md` and this file, where they describe what changed.
- **Flow count:** "13 flows" in the overview, Step 4.1 and the diagram labels. "12 flows" appears once, in the count rule for path C.
- **Diagram labels:** every line is 28 characters or fewer.
- **Sentence length:** one sentence runs over 25 words. It is the list of the ten impact values in Step 1.2.
- **Expression labels:** every labelled expression, text and formula named in a table has exactly one block, and every block is referenced.
- **Duplicate action names:** none within a flow, apart from the alternatives that never coexist: F3 version 1 and version 2, and F4a path A and path B.

### What remains tenant-only verification

Nothing in the guide has been run. Step 9.1 gathers the 40 "Test in your tenant" notes into one checklist. The ones most likely to change a build step:

- Whether a unique `PermitNumber` column accepts several blank values.
- Whether **Create new folder** returns `{Link}`, and whether **Move folder** accepts a typed path.
- Whether the designer accepts an action after a Terminate (F5).
- Whether `null` clears a column in **Update item**.
- The trigger header that carries the app user's email.
- The exact field labels and status values in the DocuSign and Adobe Acrobat Sign actions, and which event fires when the first signer finishes.
- Whether OneDrive **Convert file** output can be passed on as built.
- The screens and control names the app generator produces, and the casing of flow outputs in Power Apps.
- Whether `DataSourceInfo` reports SharePoint edit rights correctly.
- How the Power BI connector returns choice, lookup, person and date-only columns.
- Whether moved files inherit a folder's default retention label, and the `SetComplianceTag` call.
- Everything the validator tagged as product knowledge rather than a documented fact.
