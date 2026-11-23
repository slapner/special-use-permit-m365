# Build guide validation: step-by-step review

Reviewed: `docs/build-guide.md` (652 lines) on 2026-11-23. Nothing was run against a tenant. Each non-OK verdict is tagged **[doc]** (confirmed today on a Microsoft page listed at the end) or **[pk]** (product knowledge, not re-confirmed today). Time zone in the fixes is `'Eastern Standard Time'`; substitute the site's Windows time-zone ID.

## Executive verdict

- **Not buildable as written by a first-time builder.** The design and data model are sound, and every expression is syntactically valid, but of 213 steps, expressions and claims checked, 103 are OK, 33 are WRONG, 66 are INCOMPLETE and 11 need a tenant test.
- **Five defects break a working build:** the Flow 2 counter fails on the first permit of a year and has no item ID to update; app-started flows are likely to run on the coordinator's connection and fail to write AuditLog; the Premium licensing statement is wrong for Flow 4; the Flow 5 fallback re-emails the permittee on every later edit; and "turn off Flow 2 during import" renumbers migrated permits when the flow is turned back on.
- **Five steps name things that do not exist:** a *When an item is modified* trigger, a *Set retention label* action, a flow action that creates a Request files link, a shared mailbox owning a form, and sharing an app with SharePoint groups.
- **The rest are gaps, not errors:** null handling, action names the builder is never told to set, and one-sentence steps that take ten actions. Most are in Phases 3–6 and 8.

## Phase 0: Prerequisites and decisions

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| Overview: "default path uses only what a standard Microsoft 365 license includes" | OK | | |
| Decision: Tenant type | OK | Matches the connector availability table in `spec/facts.md`. | Add the government portals, because Step 6.1 sends everyone to `make.powerapps.com`: GCC `make.gov.powerapps.us` and `make.gov.powerautomate.us`; GCC High `make.high.powerapps.us` and `make.high.powerautomate.us` **[doc]**. |
| Decision: Licensing budget. "Premium is needed only for the account that owns those flows" | WRONG **[doc]** | Flow 4 is started from the app. Microsoft: "If the flow is in context of a Power Apps … app, and is an instant flow, every user running the flow needs a Power Apps Premium license." Also: "Assigning a single Power Automate Premium license to a service account that many users share is multiplexing, and the flow isn't compliant." | Replace with: "The only Premium piece is the Word Online (Business) connector. A flow started from the app is licensed per person who runs it, so either every coordinator who presses *Generate draft* needs Power Apps Premium, or the draft flow and the PDF flow each carry one Power Automate Process licence. A Premium licence on the service account alone does not cover it. If neither is in budget, use the standard-licence fallback." |
| Decision: E-signature tool | OK | Per-signer callback events are not confirmed; see Flow 5 step 4. | |
| Decision: How applicants submit | OK | | |
| Four design questions (mandated forms, folder move, compliance staff, visibility) | OK | No build step. | |
| Accounts 1: service account | INCOMPLETE **[doc]** | A conditional-access MFA policy on this account breaks the SharePoint and Word connections. Nothing says to build while signed in as this account. | Add: "Ask IT to exempt the account from interactive MFA prompts or give it a compliant policy, set a password rotation plan, and give it a OneDrive. Sign in as this account to create the solution, every connection and every flow." |
| Accounts 2: "You need SharePoint site owner rights" | INCOMPLETE | The kit README says the script needs the **SharePoint Administrator** role because it creates the site through the admin endpoint. Self-service site creation is often disabled, so the manual path may need IT too. | Add both sentences. |
| Accounts 3: shared mailbox | INCOMPLETE **[doc]** | Flows 2, 5 and 8 and the attachment flow fail unless the service account has rights on the mailbox. The trigger doc: "Your account should have permission to access the mailbox." | Add: "Ask the Exchange admin to give the service account **Full Access** and **Send As** on the shared mailbox." |
| Accounts 4: environment or Solution | INCOMPLETE **[doc]** | No steps to create the solution. A dedicated environment that IT marks as a Managed Environment needs Premium for everyone who runs a flow, even with standard connectors. | Add: "make.powerautomate.com → **Solutions → New solution**, name `SUP`, pick or create a publisher. Create every flow and the app from inside it. If IT offers a dedicated environment, confirm it is not a Managed Environment." |
| Naming convention table and character rule | OK | | Also strip a leading or trailing period, which SharePoint rejects **[pk]**. |

## Phase 1: SharePoint site

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| 1.1.1 "+ Create site → Team site (or Communication site…)" | OK **[doc]** | The UI now asks for a template after the site type. The kit script builds a **Communication** site. On a Team site the Microsoft 365 group's Members get **Edit** on everything that inherits ("By default, the Members group has this permission level"), which defeats Phase 8. | Change to: "**Communication site** (the script builds this too). Pick the blank template." |
| 1.1.2 site name and address | OK **[doc]** | | |
| 1.1.3 add owners | INCOMPLETE | No click path. | "Gear → **Site permissions → Add members**" (Team site) or "**Share site**, Full control" (Communication site). |
| 1.2 tip: create with the short name, then rename | OK | | Say it applies to list names too (`PermitTypes`, not `Permit Types`). |
| 1.2.1 Settings | OK | | |
| 1.2.2 PermitTypes | OK | `TemplateFile` is never read in the Premium path (Flow 4 step 4 picks the file by hand). | Say it is used only by the fallback. |
| 1.2.3 ConditionLibrary | OK | | |
| 1.2.4 Permits | OK | See the column rows below. | |
| 1.2.5 PermitConditions | INCOMPLETE **[pk]** | A lookup needs a display column. Flow 4 reads the condition code from `Title`, which nothing tells the builder to fill. | Add: "Lookups show **Title**. `Title` holds the condition code." |
| 1.2.6 ComplianceItems | INCOMPLETE | `DueDate` and `CompletedDate` have no type. | "(date only)". |
| 1.2.7 AuditLog | OK | | |
| 1.2 (missing) Title is required on every new list | INCOMPLETE **[pk]** | *Create item* in Flows 1, 3 and 7 and the list's **+ New** form all demand Title. | Add a step: "On Permits, PermitConditions, ComplianceItems and AuditLog: List settings → Title → *Require that this column contains information* = No." |
| Column: `PermitNumber` "enforce unique" | VERIFY | New rows are blank until Flow 2 numbers them. I could not confirm that SharePoint allows several blank values in a unique column. | Test: create two items by hand before Flow 2 exists. If the second is rejected, turn uniqueness off. |
| Columns: PermitType, Status, applicant, project, location, Impacts | OK | | Leave "Can add values manually" off on Impacts. Status default must stay `Received`. |
| Columns: dates | OK | | Add: "Format **Date only**. Set Site settings → Regional settings → Time zone first; date-only values shift a day if it is wrong." |
| Column: `Coordinator`, `Superintendent` "(default from Settings)" | INCOMPLETE | Settings has no such keys, so Flow 2 step 10 has nothing to read. | Add Settings rows `DefaultCoordinator` and `DefaultSuperintendent` holding an email address. |
| Column: `ComplianceComplete` filled by "Compliance staff" | WRONG | Step 8.1 gives SUP Compliance **Read** on Permits, so they cannot set it. | Either "Filled by: Coordinator", or have a flow set it when every ComplianceItems row for the permit is Completed. |
| Columns: `FolderUrl`, `FolderPath`, hidden text columns | INCOMPLETE **[pk]** | "Hidden from forms" has no click path. | "Open **+ New**, select the *Edit form* icon → **Edit columns**, untick the three." |
| Status values and Impact values | OK | Ten statuses, ten impacts, matching the data model. | |
| 1.3.1 create the library | OK | | |
| 1.3.2 library columns | OK | | |
| 1.3.3 two folders | OK | | |
| 1.3.4 "Make a **Templates** library (or folder)" | INCOMPLETE | The kit script and `PermitTypes-seed.csv` use the folder `PermitRecords/_Templates`. The Quick Parts fallback only works when the template sits in the library whose columns it binds to. | "Create the folder `_Templates` in Permit Records." |
| 1.3.5 versioning on the library | INCOMPLETE **[doc]** | Libraries have it on already. The list is what matters: *Get changes* in Flow 7 states "The list must have Versioning turned on." | Add: "On **Permits**: List settings → Versioning settings → Create a version each time you edit = Yes, keep 100." |
| 1.4 views | INCOMPLETE | View names differ from `kit/list-views.md` (see the contradictions list). | Use the kit's six names. |

## Phase 2: Condition library

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| 2.1 library columns | OK | | |
| 2.2.1 tag the Excel library | OK | | |
| 2.2.2 "import with the setup script, or paste into … grid view" | INCOMPLETE | The script has no general CSV import. It loads `kit/ConditionLibrary-seed.csv`. Grid-view paste into a multi-choice column is unreliable when values contain commas, and "Near stream, river or wetland" does. | "Replace the rows of `kit/ConditionLibrary-seed.csv` with your own, keeping its header row and `;` between multiple values, then run the script." Grid paste: VERIFY with one row first. |
| 2.2.3 keep Excel read-only | OK | | |
| 2.3 suggestion rule and example table | OK | Flow 3's expression implements exactly this rule. | |
| 2.4 retire by setting Active to No | OK | | |
| 2.4 "Give the program lead **Edit** on the library" | WRONG **[doc]** | Edit includes "Add, edit, and delete lists", so the lead could delete the list or its columns. It also contradicts Step 8.1 and the script, which put the lead in SUP Owners. | "Give the program lead **Contribute** on ConditionLibrary." |
| 2.4 "the *Changed this year* view" | INCOMPLETE | No such view is defined in the guide, the kit or the script. | Add: "Create view *Changed this year*: filter Modified ≥ `[Today]-365`, sort Modified descending." |

## Phase 3: Intake form

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| 3.1.1 "owned by the shared mailbox or a group" | WRONG **[doc]** | A shared mailbox cannot sign in to Forms **[pk]**. A group form works, but "Group forms will not show up in the drop-down list … the Form Id needs to be added manually." | "Sign in to Forms as the service account and create the form, then add two co-owners (*… → Collaborate or Duplicate*). If you use a group form instead, in Flow 1 choose *Enter custom value* and paste the text after `FormId=` from the form's edit URL." |
| 3.1.2 "Settings → Who can fill out this form → Anyone can respond" | WRONG **[doc]** | That path is gone. Current: "Select **Collect responses**. The Send and collect responses dialog box opens." | "Select **Collect responses** → **Anyone can respond**. If the option is greyed out, a Forms admin has turned off external responses for the tenant." |
| 3.1.3 questions, "each with a one-line hint" | WRONG **[pk]** | Forms has no per-option hint. If the hint is typed into the option text, the answer no longer equals the Impacts choice value and Flow 3 matches nothing, without an error. | "Option text must equal the ten impact values exactly. Put all hints in the question's subtitle. Mark type, both dates and email **Required**. Do not add an *Other* option." |
| 3.1.4 thank-you message | OK | | |
| 3.2 Reply-with-files: "A second flow on the shared mailbox…" | INCOMPLETE | This flow is never specified in Phase 4 and Flow 5's fallback depends on it. It also cannot name files "by the convention", because it cannot tell a COI from a site plan. | See missing step M1 for the build. |
| 3.2 Upload link: "The flow sends a SharePoint **Request files** link" | WRONG **[doc]** | The SharePoint connector has no action that creates a file request. The feature needs "The admin enabled **Anyone** links" and folder permission "**View, edit, and upload**", not merely external sharing. | "The coordinator selects the permit folder → **Request files**, copies the link and emails it. This needs *Anyone* links enabled for the site, so check with IT first. It cannot be automated with standard actions." |
| 3.2 Power Pages | OK | | |
| 3.3 staff entry | OK | Works from the list's **+ New** form today; the app arrives in Phase 6. | |
| 3.4 test | INCOMPLETE | Cannot pass until Flows 1 and 2 exist. | Move to the end of Flow 2. |

## Phase 4: Power Automate flows

Applies to every flow below **[pk]**: expressions such as `body('Get_items_Settings')`, `body('Types')` and `body('Get_changes')` only resolve if the action carries exactly that name. The guide never tells the builder to rename actions. Each step needs "rename to: …".

### Introduction and Flow 1

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| "Seven flows do the work" | WRONG | The overview diagram says 8, and the text needs at least 11 (see contradictions C1). | "Eight numbered flows, plus three helper flows." |
| Rule 1: trigger condition to stop loops | OK | | Add the path: "select the trigger → **Settings** tab → **Trigger conditions**" **[doc]**. |
| Rule 2: AuditLog row per change | INCOMPLETE | Never says which fields. | "Title = permit number, PermitId = item ID, EventType, Detail, Actor, EventTime = `utcNow()`." |
| Lifecycle diagram | OK | | |
| F1 trigger: Forms *When a new response is submitted* | OK **[doc]** | | Group form: paste the Form Id. |
| F1.1 *Get response details* | OK | | Response Id = the trigger's *Response Id* token. |
| F1.2 "map each answer to its column" (PermitType) | WRONG **[pk]** | `PermitType` is a lookup. *Create item* needs the type's item ID, not its name. | Before *Create item*, add *Get items* renamed `Get items Type` on PermitTypes, Filter Query `Title eq '@{replace(<type answer>, '''', '''''')}'`, Top Count 1. Then **PermitType Id** = `first(body('Get_items_Type')?['value'])?['ID']`. |
| F1.2 Impacts: "use `json(<answer>)` in an *Apply to each*" | INCOMPLETE **[pk]** | The multi-select answer is a JSON string, so `json()` is right, but a loop cannot feed a choice column and an unanswered question makes `json('')` fail. | *Select* renamed `Select Impacts`. From: `if(empty(<impacts answer>), json('[]'), json(<impacts answer>))`. Map: key `Value`, value `item()`. In *Create item*, switch Impacts to *input entire array* and enter `body('Select_Impacts')`. |
| F1.2 `ReceivedDate` = `utcNow()` | WRONG **[pk]** | It stores a UTC time of day in a date-only column. The list shows the right day, but flows and Power BI read the UTC value, which is the next day for anything received after 7 pm Eastern. | `formatDateTime(convertFromUtc(utcNow(),'Eastern Standard Time'),'yyyy-MM-dd')` |
| F1.2 Status, `SourceSubmissionId` | OK | | Set **Title** = `Pending` unless Title was made optional. |

### Flow 2: New permit setup

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| Trigger *When an item is created* + concurrency 1 | OK **[doc]** | Correct and necessary. For SharePoint triggers the setting cannot be undone. | Add trigger condition `@empty(triggerBody()?['PermitNumber'])` so imported and already-numbered rows are skipped (needed by Step 9.2.3). |
| F2.1 Year: `formatDateTime(utcNow(),'yyyy')` | WRONG **[pk]** | From 7 pm Eastern on 31 December, permits get next year's number. | `formatDateTime(convertFromUtc(utcNow(),'Eastern Standard Time'),'yyyy')` |
| F2.2 *Get items* on Settings; "If none comes back … *Create item* with Value `1` and use 1" | WRONG **[pk]** | Step 5 then adds 1 to an item that has no known ID, and creating with Value `1` makes the second permit of the year reuse number 1. | See the replacement block under this table. |
| F2.3 Seq: `int(first(body('Get_items_Settings')?['value'])?['Value'])` | WRONG **[pk]** | When no row exists, `first()` returns null and `int(null)` fails the run. | Same block. |
| F2.4 PermitNumber: `concat('SUP-', outputs('Year'), '-', formatNumber(outputs('Seq'), '0000'))` | OK | | Use `variables('varSeq')` with the block below. |
| F2.5 *Update item* on Settings: Value = `add(outputs('Seq'), 1)` | WRONG **[pk]** | No item Id is given, Title is required by the action, and `Value` is a text column receiving a number. | Same block. |
| F2.6 ApplicantShort expression | OK | 16 nested `replace` calls, balanced. Fails only if both ApplicantOrg and ApplicantName are blank (`replace` on null). | Change the innermost argument to `coalesce(triggerBody()?['ApplicantOrg'], triggerBody()?['ApplicantName'], 'Applicant')`. |
| F2.7 LocationShort | OK | Same null risk. | Innermost: `coalesce(triggerBody()?['LocationName'], 'Location')`. |
| F2.8 FolderName | OK | | |
| F2.9 *Create new folder*: "library **PermitRecords**, folder path `/Open Projects/…`" | INCOMPLETE **[doc]** | The dropdown shows the display name *Permit Records*. Microsoft's example path has no leading slash ("folder1/folder2/folder3"). | Library: `Permit Records`. Folder Path: `Open Projects/@{outputs('FolderName')}` |
| F2.10 *Update item*: "FolderUrl = the folder's link from step 9" | VERIFY **[doc]** | The action's outputs are documented only as "dynamic". | Test: check run history for `{Link}`. If absent use `concat('https://<tenant>.sharepoint.com/sites/SpecialUsePermits/PermitRecords/Open%20Projects/', outputs('FolderName'))`. |
| F2.10 "Coordinator and Superintendent defaults if blank" | INCOMPLETE **[pk]** | No source and no expression. A person column is set through its Claims field. | **Coordinator Claims** = `if(empty(triggerBody()?['Coordinator']?['Email']), concat('i:0#.f\|membership\|', <DefaultCoordinator value>), triggerBody()?['Coordinator']?['Claims'])`. Same for Superintendent. |
| F2.11 AuditLog *Created* | INCOMPLETE | Fields not listed. | Title = permit number, PermitId = `triggerBody()?['ID']`, Actor = `triggerBody()?['Author']?['Email']`, EventTime = `utcNow()`. |
| F2.12 *Send an email from a shared mailbox (V2)* | OK **[doc]** | Action name is exact. Needs the mailbox rights from Phase 0. Coordinator may be blank. | CC: `coalesce(triggerBody()?['Coordinator']?['Email'], '')`. |

Replacement for F2 steps 2–5:

```
0. Initialize variable varSeq (Integer) = 1
2. Get items, renamed "Get items Settings", list Settings
     Filter Query: Title eq 'NextSeq_@{outputs('Year')}'     Top Count: 1
3. Condition: length(body('Get_items_Settings')?['value'])  is greater than  0
     If yes:
       Set variable varSeq = int(first(body('Get_items_Settings')?['value'])?['Value'])
       Update item (Settings)
         Id:    first(body('Get_items_Settings')?['value'])?['ID']
         Title: NextSeq_@{outputs('Year')}
         Value: string(add(variables('varSeq'), 1))
     If no:
       Create item (Settings)   Title: NextSeq_@{outputs('Year')}   Value: 2
4. Compose PermitNumber:
     concat('SUP-', outputs('Year'), '-', formatNumber(variables('varSeq'), '0000'))
```

### Flow 3: Suggest conditions

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| Trigger: Power Apps (V2) with input `PermitId` | INCOMPLETE | Microsoft documents two settings per connection, *Provided by run-only user* and an embedded connection **[doc]**. The default for an app-started flow is the app user's connection **[pk]**. Coordinators have Read on AuditLog, so step 6 would fail with access denied. | Test: run *Suggest conditions* as a coordinator and check the AuditLog step. Fix: flow details page → **Run only users → Edit** → for SharePoint choose **Use this connection (service account)**. This lets every app user act as the service account through this flow, so keep the flow's inputs to the permit ID only. |
| "Optionally also run it when Status changes" | INCOMPLETE **[pk]** | A flow has one trigger. | Needs a second flow that calls this one as a child flow, or a copy. |
| F3.1 *Get item* (`PermitId`) | OK | | Use the **PermitId** token from the trigger. |
| F3.2 Select PermitImpacts from `body('Get_item')?['Impacts']` | VERIFY **[pk]** | If a permit with no impacts returns null rather than an empty array, *Select* fails. | Test: run on a permit with no impacts. Safe either way: From `coalesce(body('Get_item')?['Impacts'], json('[]'))` |
| F3.3 *Get items* `Active eq 1`, pagination 5000 | OK | Not filtering the multi-choice in OData is the right call. | |
| F3.4 filter `Permit/Id eq @{triggerBody()?['PermitId']}` | VERIFY **[pk]** | The filter syntax is right. The key may not be: V2 trigger inputs are normally keyed by type (`triggerBody()?['number']`), not by the label you typed. | Test: open **Peek code** on the trigger and read the key. This works either way: `Permit/Id eq @{body('Get_item')?['ID']}` |
| F3.4 Select ExistingIds `item()?['Condition']?['Id']` | OK | | |
| F3.5 *Apply to each*, concurrency 10 | OK | | |
| F3.5.1 Select Triggers | INCOMPLETE | Null when no trigger impacts are set. | From: `coalesce(items('Apply_to_each')?['TriggerImpacts'], json('[]'))` |
| F3.5.2 Select Types | INCOMPLETE | Same. | From: `coalesce(items('Apply_to_each')?['AppliesToTypes'], json('[]'))` |
| F3.5.3 "*Condition* (advanced mode)" with `@and(…)` | INCOMPLETE **[pk]** | The logic is correct. The current designer has no advanced mode on a Condition. | "In the left box choose **Expression** and paste the expression **without the leading `@`**. Operator *is equal to*. Right box: expression `true`." |
| F3.5 *Create item* in PermitConditions | INCOMPLETE | Title is not set, yet Flow 4 step 3 reads the code from Title. | Title = `items('Apply_to_each')?['ConditionCode']`; Permit Id; Condition Id = `items('Apply_to_each')?['ID']`; Source Value `Suggested`; Included `Yes`. |
| F3.6 "`Conditions suggested: n`. Return the count to the app." | INCOMPLETE **[pk]** | `n` is never computed and the return action is not named. Without a response action the app's `Refresh` runs before the rows exist. | *Initialize variable* `varAdded` (Integer, 0) at the top; *Increment variable* after each Create item; end with **Respond to a Power App or flow**, output number `added` = `variables('varAdded')`. |

### Flow 4: Generate the draft permit

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| Trigger: Power Apps (V2) | WRONG **[doc]** | With the Premium Word action in an app-started flow, every coordinator needs Power Apps Premium (see Phase 0). Same run-only connection issue as Flow 3. | Buy one Process licence for this flow, or licence each coordinator, or build the fallback. Set **Run only users → Use this connection**. |
| F4.1 two *Get item* actions | OK | The second is unused in the Premium path. | Rename `Get item Type`. |
| F4.2 filter `Permit/Id eq @{triggerBody()?['PermitId']} and Included eq 1` | VERIFY **[pk]** | Same trigger key question as F3.4. | `Permit/Id eq @{body('Get_item')?['ID']} and Included eq 1`, Order By `SortOrder asc`. |
| F4.3 Select ConditionRows: keys `Code` and `Text` | WRONG | The template section below defines only a `Text` control, and `kit/flows.md` uses `ConditionCode` and `ConditionText`. Array keys must equal the control titles. | Use `ConditionCode` and `ConditionText` in the Select and as the two control titles. |
| F4.4 *Populate a Microsoft Word template* in a Switch, one branch per type | INCOMPLETE **[pk]** | The static-file reason is correct. Missing: what to switch on, and how one *Create file* after the Switch reads whichever branch ran. | Simplest: **one master template** with a `PermitTypeName` field, no Switch. If you keep the Switch: On = `body('Get_item')?['PermitType']?['Value']`, rename each action `Populate <Type>`, then *Compose* `DraftContent` = `coalesce(body('Populate_SpecialEvent'), body('Populate_Filming'), …)`. |
| F4.5 file name "`…_DraftPermit_v@{n}.docx`" | WRONG | `@{n}` is not an expression and saves a file literally named `v.docx` or fails. | *Get files (properties only)* renamed `Get files Drafts`, Limit Entries to Folder = FolderPath, Filter Query `startswith(FileLeafRef,'@{body('Get_item')?['PermitNumber']}_DraftPermit_v')`. File Name: `concat(body('Get_item')?['PermitNumber'], '_DraftPermit_v', add(length(body('Get_files_Drafts')?['value']), 1), '.docx')` |
| F4.5 "*List folder*, then *Filter array*" | VERIFY **[doc]** | *List folder* takes a "File Identifier", described as "Unique identifier of the folder", not a path. | Use *Get files (properties only)* as above. |
| F4.6 set DocType, status, audit | INCOMPLETE | No action names. | *Update file properties*, Id = `body('Create_file')?['ItemId']`. *Update item* on Permits must resend Title. End with *Respond to a Power App or flow*. |
| Template preparation | OK | Plain-text controls matched on **Title** is right. | Name the second control (`ConditionCode`). |
| Limits paragraph (control types, dates as text, 10 MB) | OK | Matches the connector page. `formatDateTime` on a blank date fails. | `if(empty(<date>), '', formatDateTime(<date>, 'MMMM d, yyyy'))` |
| Standard-licence fallback | INCOMPLETE **[pk]** | Quick Parts bind only to columns of the library the file is in. The library has only `PermitNumber` and `DocType`, so applicant, location and dates stay empty. | Add library columns `ApplicantName`, `LocationName`, `ProposedStart`, `ProposedEnd`, `PermitExpiration`, have the flow fill them with *Update file properties*, and build the template inside Permit Records. Otherwise say plainly that only the permit number fills in. |

### Flow 5: Signature routing

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| Trigger "Permits *When an item is modified*" | WRONG **[doc]** | No trigger has that name. | "**When an item or a file is modified**". |
| Trigger conditions (two) | OK | Syntax is right. Each goes on its own row; all rows must be true. | |
| (missing) who sets `Out for Permittee Signature` | INCOMPLETE | Nothing in the guide sets this status. | App button: `Patch(Permits, varPermit, {Status: {Value: "Out for Permittee Signature"}})`. |
| E-sign 1: *Convert Word Document to PDF* "on the latest draft" | INCOMPLETE | How to find the latest draft is not given. Premium; the trigger is automated, so the owner's licence applies, with the multiplexing caveat in Phase 0. | *Get files (properties only)* in FolderPath, filter `startswith(FileLeafRef,'<PermitNumber>_DraftPermit_v')`, Order By `Modified desc`, Top 1. |
| E-sign 1: "OneDrive for Business → *Convert file*" on standard licences | INCOMPLETE **[doc]** | The action exists and is Standard, and docx to pdf is supported. It takes a OneDrive file ("data owned by that account"), not a SharePoint library file. | Four actions: SharePoint *Get file content* → OneDrive *Create file* (in `/SUP-temp`) → OneDrive *Convert file* (Target type PDF) → SharePoint *Create file* in FolderPath. Then OneDrive *Delete file*. |
| E-sign 2: "create and send a request with **signing order on**" | INCOMPLETE **[doc]** | No action names. | DocuSign: *Create envelope (V2)* → *Add documents to an envelope* → *Add recipient to an envelope (V2)* twice with **Signing order** `1` then `2` → *Send envelope*. Adobe: *Upload a document and get a document ID* → *Create an agreement from an uploaded document and send for signature* with participant **Order** 1 and 2. |
| E-sign 3: save the request ID | OK | A second edit between the trigger and this step would send a second envelope. | Make the first action *Update item* `SignatureRequestId` = `PENDING`, then overwrite with the real ID. |
| E-sign 4: "*signer completed* / *envelope status changed* event" | VERIFY **[doc]** | DocuSign's triggers are *When an envelope status changes (Connect) (V3)* and *When a Docusign Connect event occurs*; the pages do not list recipient-level events. Adobe has *When an agreement is sent to a participant* and *When an agreement workflow is completed successfully*; none is named for one signer finishing. | Test in a sandbox account: does a trigger fire when signer 1 finishes? If not, treat Adobe's "sent to participant" for signer 2 as "permittee signed", or poll hourly. Signed copy: DocuSign *Get documents from an envelope*, Adobe *Get a PDF of a signed agreement*. |
| (missing) declined, voided or redrafted | INCOMPLETE | `SignatureRequestId` stays filled, so the permit can never be sent again. | On decline, or when Status returns to `Draft Permit`: clear `SignatureRequestId` and `PermitteeSigned`. |
| Fallback 1: convert and email | WRONG **[pk]** | Nothing fills `SignatureRequestId`, so every later edit while the status is unchanged, including Flow 8's stamp, emails the permittee again. | After sending: *Update item* `SignatureRequestId` = `concat('EMAIL-', utcNow())`. |
| Fallback 2: attachment flow files the copy, coordinator enters PermitteeSigned | INCOMPLETE | Depends on the unspecified mailbox flow (M1). | |
| Fallback 3: "A flow triggered by PermitteeSigned being filled" | INCOMPLETE **[pk]** | Without a guard it restarts the approval on every edit. Nothing ever sets `Out for Superintendent Signature`. A run waits at most 30 days. | Trigger condition `@and(not(empty(triggerBody()?['PermitteeSigned'])), empty(triggerBody()?['SuperintendentSigned']), equals(triggerBody()?['Status']?['Value'],'Out for Permittee Signature'))`. First action: *Update item* Status = `Out for Superintendent Signature`. Add a timeout branch. |
| Fallback 4: on Approve / Reject | INCOMPLETE **[doc]** | Outcome values are "Approve" and "Reject", case-sensitive. On Reject the signed date and request ID must be cleared. | Condition `body('Start_and_wait_for_an_approval')?['outcome']` is equal to `Approve`. |
| Counsel note on Approvals | OK | | |
| SharePoint eSignature: "*… → eSignature*" | WRONG **[doc]** | Microsoft: "In the document viewer, select the pen icon" (*Get signatures*). The toggle name *Recipients must sign in order* is right. | "Open the PDF from the library and select the **pen icon** (*Get signatures*)." |

### Flow 6 and Flow 7

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| F6 trigger name | WRONG **[doc]** | As Flow 5. | "When an item or a file is modified". |
| F6 trigger condition expression | OK | Balanced and correct. A closed permit with an empty FolderPath (every migrated one without a folder) fails on each edit. | Add `, not(empty(triggerBody()?['FolderPath']))` inside the `and`. |
| F6.1 *Move folder* | VERIFY **[doc]** | *Folder to Move* is documented as a "File Identifier"; a typed site-relative path normally resolves **[pk]**. Open Office files in the folder block the move. | Test with `/PermitRecords/Open Projects/<name>`. If it fails, feed the folder's `{Identifier}` from *Get folder metadata using path*. Option label: confirm *Fail this action* in the dropdown. |
| F6.2 *Update item* | INCOMPLETE | No expressions. | ClosedDate `formatDateTime(convertFromUtc(utcNow(),'Eastern Standard Time'),'yyyy-MM-dd')`; FolderPath `replace(triggerBody()?['FolderPath'], '/Open Projects/', '/Closed Projects/')`; FolderUrl `concat('https://<tenant>.sharepoint.com/sites/SpecialUsePermits', replace(<new FolderPath>, ' ', '%20'))`; Title `triggerBody()?['Title']`. |
| F6.3 AuditLog | OK | | |
| F7 trigger "*When an item is modified* (no trigger condition)" | WRONG **[doc]** | Only *When an item or a file is modified* supplies the window token: "Trigger Window Start Token … only available when you use when an item or file is modified trigger." | Use that trigger. |
| F7.1 *Get changes…*, Since = `triggerOutputs()?['body/{TriggerWindowStartToken}']` | INCOMPLETE **[doc]** | Expression is right. Missing: Id, the rename, and list versioning (Step 1.3.5). | Rename `Get changes`; Id = `triggerBody()?['ID']`. |
| F7.2 condition `body('Get_changes')?['ColumnHasChanged']?['Status']` | OK | | "is equal to" expression `true`. |
| F7.3 AuditLog *Status Changed* | OK | Writes only to AuditLog, so it cannot loop. Two edits inside one polling window are logged as one. | |
| "Add the same pattern for COIReceived…" | OK | | |

## Phase 5: Scheduled reminders (Flow 8)

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| Trigger: Recurrence daily 7:00 with time zone | OK | | |
| F8.1 `split(<Value of ReminderDaysPermitExpiry>, ',')` | INCOMPLETE | How to pull one row's value out of *Get items* is not shown. | *Filter array* renamed `Filter Exp`: From `body('Get_items')?['value']`, `item()?['Title']` is equal to `ReminderDaysPermitExpiry`. Then `split(first(body('Filter_Exp'))?['Value'], ',')`. |
| F8.2 Hits array | OK | | |
| F8.3 filter `PermitExpiration eq '…' and Status ne …` | VERIFY | Syntax is valid and `int(items('Each_expiry'))` works if the loop is renamed `Each expiry`. Equality against a date-only column usually matches in US time zones, but I found no Microsoft statement of it. | Test: set one permit to exactly 30 days out and run. If it is missed use `PermitExpiration ge 'D' and PermitExpiration lt 'D+1'`. Use `int(trim(items('Each_expiry')))`. Add Top Count 500. |
| F8.3 "Append each result to Hits with a reason" | INCOMPLETE | Needs an inner loop and an object shape. | Inner *Apply to each* over the results → *Append to array variable*: `{"Id": ID, "Permit": PermitNumber, "Applicant": ApplicantName, "Reason": "Permit expires in @{items('Each_expiry')} days", "Date": PermitExpiration, "To": coalesce(Coordinator Email, ProgramMailbox), "Key": "EXP@{items('Each_expiry')}:@{formatDateTime(utcNow(),'yyyy-MM-dd')}", "LastKey": LastReminderKey, "Link": {Link}}`. Key looks like `EXP30:2026-11-23`. |
| F8.4 COI loop | OK | | |
| F8.4 expired-COI list "every Monday" | INCOMPLETE | No test for Monday. | Condition: `dayOfWeek(convertFromUtc(utcNow(),'Eastern Standard Time'))` is equal to `1`. |
| F8.5 `SuperintendentSigned eq null` | OK **[pk]** | SharePoint accepts `eq null` on a date column. | Keep the three `Status ne` clauses in this filter too. |
| F8.6 group by coordinator with `union()` | INCOMPLETE | One line for four actions. | *Select* `Select To` from `variables('Hits')`, map `item()?['To']` → *Compose* `union(body('Select_To'), body('Select_To'))` → *Apply to each* → *Filter array* where `item()?['To']` equals the current item. |
| F8.7 HTML table with a link column | INCOMPLETE **[pk]** | *Create HTML table* escapes HTML, so an `<a>` tag arrives as text. | Body: `replace(replace(replace(body('Create_HTML_table'),'&lt;','<'),'&gt;','>'),'&quot;','"')`. Action name is *Send an email from a shared mailbox (V2)*. |
| F8.8 "stamp `LastReminderKey` … so a re-run on the same day sends nothing twice" | WRONG | Nothing reads the stamp before sending, so a re-run sends everything again. | Before step 6, *Filter array* on Hits: `@not(contains(coalesce(item()?['LastKey'], ''), item()?['Key']))`. After sending, stamp `LastReminderKey` = the Hit's `Key` (the string built in F8.3). *Update item* must resend Title. |
| F8.8 "which is why Flows 5 and 6 carry trigger conditions" | OK | True for the e-signature path. The Flow 5 fallback is not protected (see Fallback 1). | |
| Time-zone note | OK | Correct for every US state. A Pacific territory ahead of UTC (Guam) is a day off. | |
| Optional applicant reminder | OK | | |
| Test it | OK | All three test permits need the same Coordinator to land in one email. | |

## Phase 6: Coordinator app

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| "A canvas app that uses only SharePoint and standard flows runs on standard M365 licenses" | OK | True only while Flow 4 is the fallback or carries a Process licence. | |
| 6.1.1 make.powerapps.com → Solutions → New → App → Canvas app | INCOMPLETE | Government URL differs (Phase 0). Must be signed in as the service account for it to own the app. | |
| 6.1.2 add SharePoint data sources | INCOMPLETE | `Settings` is missing from the list, and Step 6.3 reads approvers from it. | Add **Settings**. |
| 6.1.3 **Power Automate → Add flow** | OK **[doc]** | | After any later change to a flow, refresh it in the app's Power Automate pane (**… → Refresh**); Microsoft: "otherwise, the flow may fail to run". |
| 6.2 Home: counts | INCOMPLETE **[doc]** | SharePoint does not count on the server. `CountRows(Filter(…))` counts only the rows the app has pulled, up to the data row limit. | State that counts are exact only while each filtered set is under the limit. |
| 6.2 Permits screen | OK | See the search formula. | |
| 6.2 Permit record, Conditions tab | INCOMPLETE | No formulas for the on/off toggle, *Add from library* or the form. These are the hard part for a new builder. | Toggle `OnChange`: `Patch(PermitConditions, ThisItem, {Included: Self.Value})`. Add: `Patch(PermitConditions, Defaults(PermitConditions), {Title: galLib.Selected.ConditionCode, Permit: {Id: varPermit.ID, Value: varPermit.Title}, Condition: {Id: galLib.Selected.ID, Value: galLib.Selected.Title}, ConditionText: galLib.Selected.ConditionText, Source: {Value: "Added by staff"}, Included: true})`. Gallery items: `Filter(PermitConditions, Permit.Id = varPermit.ID)`. |
| 6.2 Documents tab: "Gallery on PermitRecords filtered by PermitNumber" | INCOMPLETE **[doc]** | Only files a flow created carry `PermitNumber`. Anything dragged into the folder or uploaded by the applicant is invisible. Filtering on folder path is not an alternative: "You can't delegate SharePoint system fields", including `FullPath`. | Add helper flow M2, which stamps `PermitNumber` on every new file. |
| 6.2 History tab | OK | `Filter(AuditLog, PermitId = varPermit.ID)` is delegable. | |
| 6.2 New application | OK | | |
| 6.3 search formula | OK **[doc]** | Delegable: `=` on choice and lookup subfields, `StartsWith` on text, joined by And/Or, no `Not`. | Dropdowns need `AllowEmptySelection` = true, or the first value is always applied. `drpStatus.Items` = `Choices(Permits.Status)`. |
| 6.3 *Suggest conditions* button | INCOMPLETE **[pk]** | Works only if the flow is named exactly `SuggestConditions` and ends with a response action (F3.6). | Name the flow `SuggestConditions`. |
| 6.3 `Visible: varIsApprover && ThisItem.Status.Value = …` on "*Superintendent approves*" | WRONG | Step 8.1 gives approving officials Read on Permits and says they approve in Approvals or the e-signature service, so this button can never save. `ThisItem` is also not valid outside a gallery or form. | Remove the button, or show a read-only banner: `Visible: varPermit.Status.Value = "Out for Superintendent Signature"`. |
| 6.3 `varIsApprover` "from … Office 365 Groups connector or a *Settings* row" | INCOMPLETE **[pk]** | No formula. The Office 365 Groups connector reads Microsoft 365 groups, not SharePoint groups. | Settings row `Approvers` = emails separated by `;`. `App.OnStart`: `Set(varIsApprover, Lower(User().Email) in Split(Lower(LookUp(Settings, Title = "Approvers").Value), ";").Value)` |
| 6.4 signing outside the app | OK | | |
| 6.4 draft opens in Word | OK | | |
| 6.4 hidden buttons are not security | OK | | |
| 6.4 "first 500 rows (2,000 at most…)" | WRONG **[doc]** | Microsoft's delegation page now reads "change the Data row limit setting from 1 to 10,000". | "(default 500; the setting can be raised, but higher values slow the app)". |
| 6.4 "Keep the home-screen counts on indexed columns with simple filters" | INCOMPLETE | Indexing does not make a count delegable (see Home). | |
| 6.4 one screen size | OK | | |
| 6.5 "Share the app with the three SharePoint groups' members" | WRONG **[doc]** | There are five groups, and an app cannot be shared with a SharePoint group: "individual users by name or … a security group in Microsoft Entra ID". | "Ask IT for one Entra security group per role, put those groups inside the five SharePoint groups, and share the app with the same security groups." |
| 6.5 Teams tab | OK | | |

## Phase 7: Dashboard and reporting

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| 7.1 List web part, "*Needs attention*, *Awaiting signature*, *Expiring in 60 days*" | INCOMPLETE | No view called *Needs attention* is defined in Step 1.4 or the kit. | Name the kit views to pin: *COI expiring*, *Awaiting signature*, *Expiring in 60 days*. |
| 7.1 search box and column filters | OK | | |
| 7.2.1 Get data → SharePoint Online list, 2.0 | OK **[doc]** | | Enter the site root URL; choose view mode **All**. |
| 7.2.2 "expand Status and PermitType to their values" | VERIFY | Microsoft does not document how the 2.0 connector shapes choice, lookup and person columns. | Test: load Permits and look at the three column types. Do **not** expand Impacts in the Permits table; it multiplies rows and inflates every count. |
| 7.2.2 (missing) dates | VERIFY **[doc]** | Microsoft documents a UTC shift for the 1.0 connector and is silent for 2.0. | Test: compare one date-only value with the list. Set each date column to type *Date*. |
| Measure `Open Permits` | OK **[doc]** | `NOT` binds below `IN` in DAX precedence, so it parses as `NOT (… IN {…})`. | |
| Measure `Days to Execute` | OK **[doc]** | A blank `ReceivedDate` on migrated rows produces a huge number. | Filter: `NOT ISBLANK(Permits[SuperintendentSigned]) && NOT ISBLANK(Permits[ReceivedDate])`. |
| Measure `COI Expiring 30d` | WRONG | Counts closed, withdrawn and denied permits. | `COI Expiring 30d = CALCULATE(COUNTROWS(Permits), Permits[COIExpiration] >= TODAY(), Permits[COIExpiration] <= TODAY() + 30, NOT Permits[Status] IN {"Closed","Withdrawn","Denied"})` |
| 7.2.4 report pages | OK | | |
| 7.2.5 publish, scheduled refresh, web part, Teams tab | INCOMPLETE **[doc]** | "Up to 8 scheduled refreshes per day" for Pro is right. Missing: the dataset needs credentials before it will refresh, and refresh stops if they expire. | "Semantic model → Settings → Data source credentials → OAuth2, signed in as the service account." GCC: `app.powerbigov.us`. |
| Power BI licence paragraph | OK | Matches `spec/facts.md`. | |
| 7.3 metrics table | OK | | |

## Phase 8: Roles, permissions, audit, retention

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| "five SharePoint groups" | OK | Contradicts "Three" in the overview table and Step 6.5. | |
| Table: SUP Owners "Edit" on Condition library | WRONG | The script grants Full Control; the program lead needs only Contribute. | "SUP Owners: Full control. Program lead: Contribute (granted on this list)." |
| Table: SUP Compliance "Edit on ComplianceItems" | WRONG **[doc]** | Edit lets them delete the list. The script uses Contribute. | "Contribute on ComplianceItems". |
| 8.1.1 create the groups | INCOMPLETE **[pk]** | No click path and no site-level permission for each group; the table gives only per-list levels. A Team site's default Members group still has Edit. | "Gear → Site permissions → **Advanced permissions settings → Create Group**. Site level: Owners Full Control, Coordinators Contribute, the other three Read. Empty the default Members and Visitors groups." |
| 8.1.2 stop inheriting on AuditLog, ConditionLibrary, Settings | INCOMPLETE | Path is right. The table also needs **ComplianceItems** and **Permit Records** broken, because SUP Compliance is Read at site level but Contribute on both. | Add those two lists to this step. |
| 8.1.3 "give SUP Compliance *Edit*" | WRONG **[doc]** | See above. | "Contribute". |
| 8.1.4 approving officials need no edit rights | OK | Contradicts the approver button in Step 6.3. | |
| (missing) flows started from the app | INCOMPLETE **[doc]** | With coordinators Read on AuditLog, Flows 3 and 4 fail unless they use the service account's connection. | See F3 trigger row. |
| 8.2 AuditLog layer | OK | | |
| 8.2 version history, 100 versions | OK | | |
| 8.2 Purview audit log | OK | | |
| 8.3.1 ask the records officer | OK | | |
| 8.3.2 publish a retention label "*7 years after closure*" | INCOMPLETE **[doc]** | Labels "typically appear … within one day. However, allow up to seven days." A period that starts at closure is either event-based retention (licence not confirmed) or a label whose period starts "when labeled". | Ask for a label that retains 7 years **from when labeled**, and apply it at closing. |
| 8.3.3 "*Set retention label* in the SharePoint connector" | WRONG **[doc]** | The connector page has no action containing "retention" or any label action. | Use the default label on the *Closed Projects* folder (details pane → *Apply label*). VERIFY that files moved in by Flow 6 pick it up: Microsoft says only that it "is applied to all new unlabeled items in the container". If they do not, call SharePoint REST `SetComplianceTag` from *Send an HTTP request to SharePoint* and test it. |
| 8.3.4 never delete by hand | OK | | |
| 8.4 ownership, connections, export | INCOMPLETE | "the site's *Admin* library" is never created. | Add it to Step 1.3 with owners-only permissions. |
| 8.4 error-handling scope | OK | | "Configure run after → has failed, has timed out". |
| 8.4 "idle flows can be switched off after about 90 days" | OK **[doc]** | "A cloud flow that isn't triggered within a 90 day period might be turned off", unless the owner has a premium licence. | |
| 8.4 runbook, AuditLog caveat | OK | | |

## Phase 9: Test, migrate, go live

| Step | Verdict | Problem | Exact fix |
|---|---|---|---|
| 9.1.1 test site with the script | INCOMPLETE | Nothing says how flows and the app built against the test site are pointed at production. Each SharePoint action stores the site address. | Add: "In the solution create environment variables `SiteUrl` and one per list, and pick them in every SharePoint action. For production, change only the variable values. Otherwise every action and every app data source must be re-pointed by hand." |
| 9.1.2 load `Permits-sample.csv` | INCOMPLETE | Not said how. | "Run the script with `-ImportSamplePermits`." Do this before Flow 2 is on, or with the F2 trigger condition in place. |
| 9.1.3 checklist | OK | "nobody can edit AuditLog" is false for SUP Owners, as Step 8.4 admits. | "nobody except owners". |
| 9.2.1 freeze the tracker | OK | | |
| 9.2.2 map columns, `NextSeq_{year}` | OK | | Fill `ClosedDate` on every closed row, or Flow 6 fires on its first edit. |
| 9.2.3 "Turn off Flow 2 during import" | WRONG **[doc]** | SharePoint item triggers poll ("periodically checks for changes"). For polling triggers: "When you turn the flow back on, it processes all unprocessed or pending events." Flow 2 would renumber every imported permit and create a second folder for each. | "Leave Flow 2 on. Its trigger condition `@empty(triggerBody()?['PermitNumber'])` skips rows that arrive with a number." |
| 9.2.3 "the script's CSV import" | WRONG | The script imports only the sample file and shifts its dates to today. | Use grid-view paste in batches, and test lookup, person and multi-choice columns with five rows first (VERIFY). |
| 9.2.4 move folders, "one-time flow that matches folder names to permit numbers" | INCOMPLETE | No build, and it works only if old folder names contain the permit number. Moved files carry no `PermitNumber`, so the app's Documents tab is empty for them. | Rename old folders to start with the permit number first. Flow: *Get files (properties only)*, Limit Entries to Folder `/PermitRecords/Open Projects`, Include Nested Items No, Filter Query `FSObjType eq 1`; for each, `first(split(item()?['{Name}'], '_'))` → *Get items* on Permits → *Update item*. |
| 9.2.5 spot-check | OK | | |
| 9.3.1 turn on all flows | OK | Safe only with the F2 trigger condition. | |
| 9.3.2 – 9.3.4 | OK | | |

## Appendix claims

| Claim | Verdict | Problem | Exact fix |
|---|---|---|---|
| Script "builds Phase 1 and Step 8.1 in one run" | OK | It builds a Communication site and puts templates in `_Templates`, both unlike the guide. | Align Steps 1.1.1 and 1.3.4. |
| "PowerShell 7.4+, PnP.PowerShell 3.x … `Register-PnPEntraIDAppForInteractiveLogin`" | OK | Per `spec/facts.md`. | Add the SharePoint Administrator requirement and, for government, `-AzureEnvironment USGovernment` or `USGovernmentHigh`. |
| "`kit/flows.md` … every flow in Phases 4 and 5" | INCOMPLETE | The kit numbers flows F1–F7 and the guide 1–8, with different triggers for three of them. | Add the mapping in C2. |
| "six tracker views" | OK | Names differ (C4). | |
| "22 sample conditions", "12 fictitious permits" | OK | Counted. | |
| Options considered table | OK | | |
| Hardening list | OK | Two things are needed in version one, not later: clearing `SignatureRequestId` when a request is declined (not on the list), and the folder-move retry (`FolderMoveState`). | |
| Sources and "Not confirmed" list | OK | | |

## Sequence of phases

| Dependency | Problem | Fix |
|---|---|---|
| Solution and service-account sign-in | Phase 0 mentions them; the first flow (Phase 4) and the app (Phase 6) need them to exist. | Make "create the solution, signed in as the service account" the first step of Phase 4. |
| Groups and permissions (Step 8.1) | Built after the flows and app that depend on them. Flow tests in Phases 4–6 pass as an owner and then fail for coordinators. The script already builds the groups with Phase 1. | Move Step 8.1 to the end of Phase 1. |
| Step 3.4 test | Needs Flows 1 and 2 (Phase 4). | Move to the end of Flow 2. |
| Mailbox attachment flow | Promised in Step 3.2, needed by Flow 5's fallback, never built. | Build it after Flow 2 (see M1). |
| Flows 3 and 4 | Triggered by the app, which is built in Phase 6. | Say they can be tested from the flow's **Test → Manually** with a permit ID until the app exists. |
| Flow 5 | Needs the status set by an app button that Phase 6 never defines. | Until the app exists, change Status in the list by hand. |
| Step 8.3 retention label | Flow 6 (Phase 4) is told to apply a label that is published in Phase 8 and can take up to seven days to appear **[doc]**. | Request the label in Phase 0. |
| Step 9.1 "build in a test site first" | Comes after eight phases of building. | Move the instruction to the top of Phase 1. |

## 1. Steps missing entirely

- **M1. Mailbox attachment flow** (Step 3.2 and Flow 5 fallback rely on it). Trigger *When a new email arrives in a shared mailbox (V2)*, Subject Filter `SUP-`, Include Attachments Yes. Compose `substring(triggerOutputs()?['body/subject'], indexOf(triggerOutputs()?['body/subject'], 'SUP-'), 13)` → *Get items* on Permits by PermitNumber → for each attachment *Create file* in FolderPath named `<PermitNumber>_Correspondence_<yyyy-MM-dd>_<original name>` → *Update file properties*.
- **M2. Stamp PermitNumber on uploaded files.** Trigger *When a file is created (properties only)* on Permit Records; take the permit number from the folder name; *Update file properties*. Without it the app's Documents tab misses hand-uploaded files.
- **M3. Create the solution, and build signed in as the service account** (Phase 0).
- **M4. Mailbox rights for the service account** (Full Access and Send As).
- **M5. Run-only connection setting** on every app-started flow.
- **M6. Turn on versioning for the Permits list** before building Flow 7.
- **M7. Make Title optional**, or set it in every *Create item* and *Update item*.
- **M8. The action that sets `Out for Permittee Signature`**, and the reset when a request is declined or a draft is regenerated.
- **M9. Default Coordinator and Superintendent** settings and the Claims expression.
- **M10. Test-to-production promotion** (environment variables, or a re-pointing checklist).
- **M11. Site regional time zone**, set before any date is entered.
- **M12. Break inheritance on ComplianceItems and Permit Records**, and empty the default Members and Visitors groups.
- **M13. Power BI data source credentials** for scheduled refresh.
- **M14. A failure path for *Move folder*** (file open in Word, name clash): email the coordinator; the permit otherwise stays Closed with its folder under Open Projects.

## 2. Contradictions

- **C1. Flow count.** Overview diagram: "8 flows". Phase 4: "Seven flows". Actual: 8 numbered, plus the mailbox flow, the e-signature callback flow, the fallback approval flow and the one-time migration flow.
- **C2. Flow numbering, guide vs `kit/flows.md`.** Flow 1 = F1a, Flow 2 = F1b, Flow 3 = F2, Flow 4 = F3, Flow 5 = F4, Flow 6 = F5, Flow 7 = F7b, Flow 8 = F6. The kit also has F7a (audit child flow), which the guide does not use.
- **C3. Group count.** "Three SharePoint groups" (overview table, Step 6.5) vs "five" (Phase 8).
- **C4. View names.** Step 1.4: *COI expiring in 30 days*, *Permits expiring in 60 days*, *Start within 30 days and not executed*. Kit: *COI expiring*, *Expiring in 60 days*, *Unexecuted, start within 30 days*. Step 7.1 adds *Needs attention*; Step 2.4 adds *Changed this year*. Neither exists.
- **C5. Site type.** Guide: Team site. Kit script: Communication site.
- **C6. Templates.** Guide: "a **Templates** library (or folder)". Kit and seed data: `PermitRecords/_Templates`.
- **C7. FolderPath format.** Guide: `/PermitRecords/Open Projects/…` (site-relative). Kit and data model: `/sites/SpecialUsePermits/PermitRecords/…` (server-relative). Either works alone; mixing breaks *Create file* and *Move folder*.
- **C8. Edit vs Contribute.** Guide Steps 2.4 and 8.1.3 say Edit; the script and data model say Contribute.
- **C9. Flow 5 trigger.** Guide: Permits item modified with status `Out for Permittee Signature`. Kit F4a: Power Apps (V2) button; kit fallback: file created ending `_PermitteeSigned.pdf`.
- **C10. Flow 3 trigger and lookup filter.** Guide: Power Apps only, `Permit/Id eq`. Kit: item modified with *Get changes*, or Power Apps; `PermitId eq`.
- **C11. Flow 2 email.** Guide: to the applicant from the shared mailbox, coordinator copied. Kit F1b: to the coordinator only.
- **C12. Flow 8 status filter.** Guide: expiry reminders for every permit not closed. Kit F6: only `Executed` or `Active`.
- **C13. Word control names.** Guide Select keys `Code`/`Text`, template control `Text`, matched on Title. Kit: `ConditionCode`/`ConditionText`, "tagged".
- **C14. ComplianceComplete.** "Filled by Compliance staff" (Phase 1) vs Compliance has Read on Permits (Phase 8).
- **C15. Approver button** in Step 6.3 vs "they don't need edit rights" in Step 8.1.4.
- **C16. Script prerequisites.** Guide: site owner plus an app registration. Kit README: SharePoint Administrator.
- **C17. Audit status detail.** Guide Flow 7 logs "Status set to X". Kit F7b logs "old → new" using an HTTP call to version history.

## 3. Five things most likely to make a first-time builder give up

1. **Expressions that refer to actions the builder never named, and a kit that numbers the flows differently.** The first save fails with "the action 'Get_items_Settings' … is not defined". Rewrite every flow step as: action type, **Rename to**, then each field on its own line with the value to paste. Put the C2 mapping at the top of Phase 4 and renumber one side.
2. **Flow 2's counter (steps 2–5).** It fails on the first permit and has no ID for the update. Replace with the block given under Flow 2, and add the trigger condition.
3. **Flow 4, the Word template.** A Switch with six *Populate* actions, an undefined `n`, mismatched control names and a licence the guide says is not needed. Rewrite: one master template; a field list that names each control title; the *Get files* count expression; the Process-licence sentence. Tell builders to ship the fallback first and add this later.
4. **Flow 5, signature routing.** Three variants in one section, no action names for either connector, and a fallback that re-emails the permittee on every edit. Rewrite: choose the variant in Phase 0, then give only that variant as numbered actions with the guards above.
5. **Phase 6, the app.** Seven screens described in one table and three formulas. Rewrite as a build order: screen by screen, each control's name and its `Items`, `OnSelect` or `Visible` formula, starting from *Create an app from a SharePoint list* so the browse, detail and edit screens already exist. Until then, staff can run on list views and list forms.

Runner-up: Flow 8 steps 6–8 compress about fifteen actions into three sentences.

## Government cloud differences

| Item | GCC | GCC High / DoD | Evidence |
|---|---|---|---|
| Maker portals | `make.gov.powerapps.us`, `make.gov.powerautomate.us` | `make.high.powerapps.us`, `make.high.powerautomate.us`; DoD `make.apps.appsplatform.us`, `make.powerautomate.appsplatform.us` | [doc] |
| Forms "Anyone can respond" | Available | Microsoft's Forms page says available; older Microsoft material says off. Confirm with the Forms admin. | [doc] plus unopened search result |
| Forms email notifications | Not available | Not available | [doc] |
| Request files | Not stated; needs *Anyone* links, so check with IT first | Same | [doc] |
| DocuSign / Adobe / SharePoint eSignature | Both / yes / not documented | DocuSign only / no / not documented | `spec/facts.md` |
| Power BI | `app.powerbigov.us`; every viewer needs Pro | Same | `spec/facts.md` |
| PnP script | `-AzureEnvironment USGovernment` | `USGovernmentHigh`, `USGovernmentDoD` | `spec/facts.md` |
| Other feature gaps | Microsoft points to the *Business Applications US Government – Availability Summary* file, which I did not open | Same | [doc] |

## Could not verify

Test each in the tenant:

1. Whether a unique `PermitNumber` column accepts several blank values.
2. Whether *Create new folder* returns `{Link}` (documented only as "dynamic" outputs).
3. Whether *Move folder* accepts a typed site-relative path, and whether it keeps version history and item IDs.
4. Whether `DateColumn eq 'yyyy-MM-dd'` matches date-only values in your site's time zone.
5. The Power Apps (V2) input key names (`number`, `text`); check with **Peek code**.
6. How the Power BI SharePoint Online list 2.0 connector returns choice, lookup, person and date-only columns.
7. Which DocuSign and Adobe Acrobat Sign events fire when the first of two signers finishes.
8. Whether files moved into a folder with a default retention label inherit it, the `SetComplianceTag` REST call, and the licence for event-based retention.
9. Grid-view paste into lookup, person and multi-choice columns.
10. Whether Quick Parts keep their binding when a template is copied between folders of the same library.
11. Every item tagged **[pk]**: these rest on product knowledge and were not re-confirmed on a page today.

## URLs opened

- https://learn.microsoft.com/en-us/connectors/sharepointonline/
- https://learn.microsoft.com/en-us/sharepoint/dev/business-apps/power-automate/sharepoint-connector-actions-triggers
- https://learn.microsoft.com/en-us/troubleshoot/power-platform/power-automate/flow-run-issues/triggers-troubleshoot
- https://learn.microsoft.com/en-us/power-automate/triggers-introduction
- https://learn.microsoft.com/en-us/power-platform/admin/power-automate-licensing/faqs
- https://learn.microsoft.com/en-us/power-platform/admin/power-automate-licensing/types
- https://learn.microsoft.com/en-us/power-automate/limits-and-config
- https://learn.microsoft.com/en-us/power-automate/create-team-flows
- https://learn.microsoft.com/en-us/power-automate/change-cloud-flow-owner
- https://learn.microsoft.com/en-us/power-automate/us-govt
- https://learn.microsoft.com/en-us/power-platform/admin/powerapps-us-government
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/working-with-flows
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/share-app
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/connections/connection-sharepoint-online
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/delegation-overview
- https://learn.microsoft.com/en-us/connectors/microsoftforms/
- https://learn.microsoft.com/en-us/connectors/onedriveforbusiness/
- https://learn.microsoft.com/en-us/connectors/office365/
- https://learn.microsoft.com/en-us/connectors/approvals/
- https://learn.microsoft.com/en-us/connectors/wordonlinebusiness/
- https://learn.microsoft.com/en-us/connectors/docusign/
- https://learn.microsoft.com/en-us/connectors/adobesign/
- https://learn.microsoft.com/en-us/microsoft-365/documentprocessing/esignature-send-requests
- https://learn.microsoft.com/en-us/graph/api/driveitem-get-content-format
- https://learn.microsoft.com/en-us/power-query/connectors/sharepoint-online-list
- https://learn.microsoft.com/en-us/dax/dax-operator-reference
- https://learn.microsoft.com/en-us/dax/datediff-function-dax
- https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh
- https://learn.microsoft.com/en-us/sharepoint/enable-file-requests
- https://learn.microsoft.com/en-us/sharepoint/understanding-permission-levels
- https://learn.microsoft.com/en-us/purview/create-apply-retention-labels
- https://learn.microsoft.com/en-us/purview/event-driven-retention
- https://learn.microsoft.com/en-us/purview/retention-policies-sharepoint
- https://support.microsoft.com/office/create-a-file-request-f54aa7f8-2589-4421-b351-d415fc3b83af
- https://support.microsoft.com/en-US/Forms/choose-who-can-fill-out-a-form-or-quiz
- https://support.microsoft.com/en-US/Forms/microsoft-forms-features-for-u-s-government-community-cloud-gcc-gcc-high-and-dod-environments
- https://support.microsoft.com/en-us/office/create-a-site-in-sharepoint-4d1e11bf-8ddc-499d-b889-2b48d10b1ce8

Opened but returned nothing usable: `support.microsoft.com/…/enable-and-configure-versioning-for-a-list-or-library…` (no statement on list defaults).
