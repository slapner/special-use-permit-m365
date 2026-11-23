# Power Automate build sheets: SUP flows F1a to F10

> **UNTESTED against a live tenant.** These are hand-build instructions, not importable packages. Build and test in a test site first. Wherever this page says **verify** or *Test in your tenant*, the exact action name, field, output shape or behaviour could not be confirmed. Check it in the designer and in run history before relying on it.

These sheets use the same flow IDs, flow names, action names and expressions as `docs/build-guide.md` (Phase 4, F6 in Phase 5, and F10 in Phase 9). Every expression that appears in both is identical. If the two ever differ, the build guide is the source of truth. This page adds the kit's own notes: the conventions below, extra **verify** points and the alternatives the guide mentions only briefly.

## Flows and build order

Count rule, the same as build guide Step 4.1: **13 flows** stay switched on when you use an e-signature connector (DocuSign or Adobe Acrobat Sign). Both F2 flows count. F10 runs once at migration and is not counted.

With no e-signature service, F4c replaces F4a and F4b, so 12 flows stay on. With SharePoint eSignature, the optional F4d replaces them.

| Build order | ID | Flow name to type | Trigger | Delivery stage | Licence |
| --- | --- | --- | --- | --- | --- |
| 1 | F7a | `SUP – Write Audit` | Called by the other flows | 1 | Standard |
| 2 | F1b | `SUP – Number, Folder, Notify` | Permits item created | 1 | Standard |
| 3 | F1a | `SUP – Form to Permits Item` | Forms response | 1 | Standard |
| 4 | F7b | `SUP – Status Changed Logger` | Permits item modified | 1 | Standard |
| 5 | F5 | `SUP – Close Permit` | Permits item modified | 1 | Standard |
| 6 | F6 | `SUP – Daily Reminders` | Daily at 7:00 (guide Phase 5) | 1 | Standard |
| 7 | F8 | `SUP – Mailbox Attachments` | Email arrives in the shared mailbox | 1 | Standard |
| 8 | F2a | `SUP – Suggest Conditions (status)` | Permits item modified | 2 | Standard |
| 9 | F3 | `SUPGenerateDraft` | App button | 3 | Standard fallback, or Premium |
| 10 | F4a | `SUPSendForSignature` | App button | 4, paths A and B | Standard, or Premium PDF step |
| 11 | F4b | `SUP – Signature Callback` | E-signature service event | 4, paths A and B | Standard |
| 10 | F4c | `SUP – Signed Upload and Approval` | Signed file uploaded | 4, path C only | Standard |
| 10 | F4d | `SUP – Signed Copy Arrived` | Signed file saved | 4, path D only, optional | Standard |
| 12 | F2b | `SUPSuggestConditions` | App button | 5 | Standard |
| 13 | F9 | `SUP – Stamp Permit Number` | File created in Permit Records | 5 | Standard |
| Once | F10 | `SUP – Migration Folder Match` | Run by hand (guide Phase 9) | Migration | Standard |

The dash in a flow name is only a label, so a hyphen works too. The three names without spaces matter: the app calls those flows by name.

Flows started from the app (F2b, F3, F4a) can be tested before the app exists. Open the flow, select **Test → Manually**, and type a permit's ID.

Older copies of this sheet used other names for four flows. "F2 option A" is now F2a, "F2 option B" is F2b, "F4 Standard fallback" is F4c, and the file-arrival flow for SharePoint eSignature is F4d. F8, F9 and F10 are new.

The sections below follow the build order, except that F2b sits right after F2a, which it copies. Build F2b and F9 with the app, in delivery stage 5. The README lists the six delivery stages.

## Conventions

These apply to every flow.

- **Rename actions exactly as written.** Expressions refer to actions by name with spaces turned into underscores. The action `Get item Permit` is referenced as `body('Get_item_Permit')`.
- **Site Address:** `https://<tenant>.sharepoint.com/sites/SpecialUsePermits`, or your test alias such as `/sites/SUP-Test`.
- **Never hard-code the site path in an expression.** Flows that build paths start with **Compose SiteRel** (and **Compose TenantRoot** where they build a web address). Expressions read the path from those two actions.
- **List names:** use the display names in the dropdowns: `Permits`, `Settings`, and so on. The library's display name is `Permit Records` and its URL is `PermitRecords`.
- **Column names:** expressions use internal names; the designer shows display names. Most display names are the internal name with spaces (`ProposedStart` → **Proposed Start**). The exceptions: `ApplicantOrg` → **Applicant Organization**, `LocationName` → **Location**, `FolderUrl` → **Folder**, `EvidenceUrl` → **Evidence**, `DefaultTermDays` → **Default Term (days)**.
- **Connection account:** one service account (a licensed, non-personal mailbox user) for every SharePoint, Outlook, OneDrive, Word Online and Approvals connection. **Add it to SUP Owners by hand: the setup script does not.** AuditLog, Settings and ConditionLibrary are owners-only for edits, and moving folders needs edit rights on both top folders. Without it every audit write fails with error 403.
- **Store flows in the `SUP` solution.** Child flows (F7a) work only in solution-aware flows.
- **Choice, lookup and person columns.** The SharePoint connector returns a single choice as `{ "Value": "..." }`, so you read `?['Status']?['Value']`. A multi-choice comes back as an array of `{ "Value": ... }`. A lookup returns `{ "Id", "Value" }`, and a person returns `{ "Email", "DisplayName", "Claims", ... }`. **Verify these shapes in run history before trusting the expressions.**
- **Licensing:** every action is Standard except Word Online (Business), which is **Premium**. Only F3 version 2 needs it as built. The alternative PDF step in F4a also uses it. A flow started from the app is licensed per person who runs it, so either every coordinator who runs it needs Power Apps Premium, or the flow carries one Power Automate Process licence. A Premium licence on the service account alone does not cover it. In a Managed Environment, everyone who runs any flow needs Premium.

### Moving from the test site to production

Every SharePoint action stores the site address and list. Pick one of two ways to re-point them later.

- **Environment variables (recommended).** In the solution, select **New → More → Environment variable**. Create `SUP_SiteUrl` with data type **Data source**, connector **SharePoint**, parameter type **Site**. Create one more per list with parameter type **List**: Permits, PermitTypes, ConditionLibrary, PermitConditions, ComplianceItems, AuditLog, Settings and Permit Records. In each SharePoint action, choose **Enter custom value** and pick the variable. For production, change only the variable values.
- **Re-point by hand.** Pick the test site and lists directly. At go-live, open every flow and change **Site Address** and the list on every SharePoint action. Do the same for each data source in the app.

Either way, the two actions **Compose SiteRel** and **Compose TenantRoot** hold the site path as text. Change them in every flow that has them, or create two text environment variables and pick those instead.

### How to read the action tables

Each flow has one table. Work down it one row at a time.

- **#** is the order. `7Y.1` is the first action inside the **True** branch of action 7. `7N.1` is inside the **False** branch. `10.1` is the first action inside loop 10.
- **Action (rename to)** gives the action's name in the designer, then the name to give it in bold. Rename it before you add the next action: select the action, then **… → Rename**. Expressions find actions by these names, so type them exactly.
- **Field** is the field's label in the designer. Labels follow the column display names the setup script creates.
- **Value** in `code` is an expression. Select the field, select **fx**, paste the expression, then select **Add**.
- **Text** before a value means type or paste it straight into the field. Text that contains `@{...}` turns into tokens when you save.
- **Token** means pick the named item from the dynamic content list. **Choose** means pick it from the dropdown.
- **Site Address** is not repeated in the tables. Every SharePoint action needs it: choose the site, or its environment variable.
- Leave every other field that is not listed empty.
- Where a table shows `/sites/SpecialUsePermits`, type the site you are building against, such as `/sites/SUP-Test`. Change it again for production.
- A second action of the same type gets `2` added to its name by the designer. Always rename it as the table says.

Three settings come up repeatedly:

- **Trigger conditions:** select the trigger, open the **Settings** tab, and under **Trigger conditions** select **Add**. Each condition goes in its own row. All rows must be true.
- **Concurrency control:** on the trigger's **Settings** tab, turn it **On** and set **Degree of parallelism** to `1`. For a SharePoint trigger this cannot be undone.
- **Run after:** select the action, open **Settings**, and under **Run after** tick only the listed result of the listed action.

Time zone: every local date uses `'Eastern Standard Time'`. Replace it with your Windows time-zone ID, and set the same zone under **Site settings → Regional settings**.

### Rules that apply to every flow

**Stop loops.** F1b, F3, F4, F5 and F6 update Permits items. F2a, F5 and F7b start when a Permits item is modified. Each of those three is guarded so it acts only on the change it cares about.

| Flow | Guard |
| --- | --- |
| F2a | Trigger condition on `Under Review`, then **Get changes** confirms that Status changed |
| F5 | Trigger condition: status is closed and the folder is not yet under `/Closed Projects/` |
| F7b | **Get changes** confirms that Status changed. It writes only to AuditLog, so it cannot loop |

**Write an audit row for every change a flow makes.** Flows do this by calling F7a. In the tables, a row named **Audit …** is always the action **Run a Child Flow** with these six fields:

| Field | Value |
| --- | --- |
| Child Flow | Choose **SUP – Write Audit** |
| PermitNumber | The permit number, as the row states |
| PermitId | The Permits item ID, as the row states |
| EventType | Text: one of the AuditLog choices, such as `Created` |
| Detail | As the row states |
| Actor | An email address, as the row states |

**Use the service account's connection for app-started flows (F2b, F3, F4a).** After saving F2b, F3 or F4a, open the flow's details page. Under **Run only users** select **Edit**. For SharePoint, and for Word Online, OneDrive and Outlook where used, choose **Use this connection**. Otherwise the flow runs with the coordinator's own rights and cannot write AuditLog or Settings.

That setting lets every app user act as the service account through the flow. Keep each flow's only input as the permit ID.

**Actor in app-started flows.** The trigger has no item author or editor, so F2b, F3 and F4a read the caller's email from the trigger headers. The expression is F2-B (repeated as F3-H and F4-D). It falls back to `app user`.

**Catch failures.** By default, failure emails go only to the flow owner. Build guide Step 8.4 adds an error-handling scope to each flow once it works.

## F7a — Write Audit (child flow)

Build this first, because every other flow calls it. It adds one row to AuditLog.

### Trigger and settings

- **Trigger:** **Manually trigger a flow**. Flow name: `SUP – Write Audit`.
- Add five inputs in this order, because the order sets their internal keys: Text `PermitNumber`, Number `PermitId`, Text `EventType`, Text `Detail`, Text `Actor`.
- On the `Actor` input select **… → Make the field optional**.

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Create item → **Create item AuditLog** | Site Address | Choose the site |
|  |  | List Name | Choose **AuditLog** |
|  |  | Title | Token **PermitNumber** |
|  |  | Permit Id | Token **PermitId** |
|  |  | Event Type Value | Choose **Enter custom value**, then Token **EventType** |
|  |  | Detail | Token **Detail** |
|  |  | Actor | `if(empty(triggerBody()?['text_3']), 'system', triggerBody()?['text_3'])` |
|  |  | Event Time | `utcNow()` |
| 2 | Respond to a Power App or flow → **Respond ok** | Output, type Yes/No, named `ok` | `true` |

Without the response action, the calling flow waits until it times out. Older tenants name it **Respond to a PowerApp or flow**.

*Test in your tenant:* select the trigger, then **… → Peek code**. Confirm the Actor input's key is `text_3`. If it differs, use the key you see in the Actor expression.

### After saving

On the flow's details page, under **Run only users**, select **Edit**. Set the SharePoint connection to **Use this connection**. A child flow cannot use the caller's connection.

If you do not use a solution, child flows are not available. Paste a **Create item** on AuditLog with the same fields wherever a table says **Audit …**.

## F1b — Number, folder, notify

F1b gives every new Permits item its number and folder. It runs for items from the form, the list's **+ New** form and the app, so all three get the same treatment.

### Trigger and settings

- **Trigger:** SharePoint **When an item is created**. Site Address: the site. List Name: **Permits**. Flow name: `SUP – Number, Folder, Notify`.
- **Concurrency control:** On, degree of parallelism `1`. SharePoint has no safe "add one" operation. Two runs at once would read the same sequence number and issue it twice.
- **Trigger conditions:** `@empty(triggerBody()?['PermitNumber'])`. Items that arrive with a number, such as sample and migrated permits, are skipped. They are not renumbered and get no second folder.

The unique index on `PermitNumber` is a second safety net. A duplicate makes the update fail instead of saving silently.

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` (your test alias while testing) |
| 2 | Compose → **Compose TenantRoot** | Inputs | Text `https://<tenant>.sharepoint.com` |
| 3 | Initialize variable → **Initialize varSeq** | Name | Text `varSeq` |
|  |  | Type | Choose **Integer** |
|  |  | Value | Text `0` |
| 4 | Compose → **Compose Year** | Inputs | Expression F1b-A |
| 5 | Get items → **Get items Settings** | List Name | Choose **Settings** |
|  |  | Filter Query | Text `Title eq 'NextSeq_@{outputs('Compose_Year')}'` |
|  |  | Top Count | Text `1` |
| 6 | Condition → **Condition Seq row exists** | Left value | `length(body('Get_items_Settings')?['value'])` |
|  |  | Operator and right value | **is greater than** `0` |
| 6Y.1 | Set variable → **Set varSeq from row** | Name | Choose **varSeq** |
|  |  | Value | `int(first(body('Get_items_Settings')?['value'])?['Value'])` |
| 6Y.2 | Update item → **Update item Settings** | List Name | Choose **Settings** |
|  |  | Id | `first(body('Get_items_Settings')?['value'])?['ID']` |
|  |  | Title | `concat('NextSeq_', outputs('Compose_Year'))` |
|  |  | Value | `string(add(variables('varSeq'), 1))` |
| 6N.1 | Set variable → **Set varSeq to 1** | Name | Choose **varSeq** |
|  |  | Value | Text `1` |
| 6N.2 | Create item → **Create item Settings** | List Name | Choose **Settings** |
|  |  | Title | `concat('NextSeq_', outputs('Compose_Year'))` |
|  |  | Value | Text `2` |
| 7 | Compose → **Compose PermitNumber** | Inputs | `concat('SUP-', outputs('Compose_Year'), '-', formatNumber(variables('varSeq'), '0000'))` |
| 8 | Compose → **Compose ApplicantRaw** | Inputs | Expression F1b-B |
| 9 | Compose → **Compose ApplicantClean** | Inputs | Expression F1b-C |
| 10 | Compose → **Compose ApplicantShort** | Inputs | Expression F1b-D |
| 11 | Compose → **Compose LocationClean** | Inputs | Expression F1b-E |
| 12 | Compose → **Compose LocationShort** | Inputs | Expression F1b-F |
| 13 | Compose → **Compose FolderName** | Inputs | Expression F1b-G |
| 14 | Create new folder → **Create new folder** (default name) | List or Library | Choose **Permit Records** |
|  |  | Folder Path | Text `Open Projects/@{outputs('Compose_FolderName')}` |
| 15 | Compose → **Compose FolderPath** | Inputs | `concat(outputs('Compose_SiteRel'), '/PermitRecords/Open Projects/', outputs('Compose_FolderName'))` |
| 16 | Update item → **Update item Permit** | List Name | Choose **Permits** |
|  |  | Id | `triggerBody()?['ID']` |
|  |  | Title | `outputs('Compose_PermitNumber')` |
|  |  | Permit Number | `outputs('Compose_PermitNumber')` |
|  |  | Folder | `body('Create_new_folder')?['{Link}']` |
|  |  | Folder Path | `outputs('Compose_FolderPath')` |
|  |  | Received Date | Expression F1b-H |
|  |  | Status Value | `coalesce(triggerBody()?['Status']?['Value'], 'Received')` |
| 17 | Run a Child Flow → **Audit Created** | PermitNumber | `outputs('Compose_PermitNumber')` |
|  |  | PermitId | `triggerBody()?['ID']` |
|  |  | EventType | Text `Created` |
|  |  | Detail | Expression F1b-I |
|  |  | Actor | `triggerBody()?['Author']?['Email']` |
| 18 | Get items → **Get items Mailbox** | List Name | Choose **Settings** |
|  |  | Filter Query | Text `Title eq 'ProgramMailbox'` |
|  |  | Top Count | Text `1` |
| 19 | Send an email (V2) → **Send an email (V2)** (default name) | To | Expression F1b-J |
|  |  | Subject | Text `New SUP application @{outputs('Compose_PermitNumber')}: @{triggerBody()?['ProjectTitle']}` |
|  |  | Body | Text F1b-K |

### Expressions

Expression F1b-A — Compose Year. It uses the received date in local time, so a permit received on the evening of 31 December keeps the right year:

```
formatDateTime(coalesce(triggerBody()?['ReceivedDate'], convertFromUtc(utcNow(), 'Eastern Standard Time')), 'yyyy')
```

Expression F1b-B — Compose ApplicantRaw:

```
if(empty(triggerBody()?['ApplicantOrg']), triggerBody()?['ApplicantName'], triggerBody()?['ApplicantOrg'])
```

Expression F1b-C — Compose ApplicantClean. It strips spaces and the characters SharePoint rejects, collapses repeated dots, then cuts to 30 characters:

```
take(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(coalesce(outputs('Compose_ApplicantRaw'), 'Applicant'), '~', ''), '"', ''), '#', ''), '%', ''), '&', ''), '*', ''), ':', ''), '<', ''), '>', ''), '?', ''), '/', ''), '\', ''), '{', ''), '|', ''), '}', ''), ' ', ''), '..', '.'), '..', '.'), '..', '.'), '..', '.'), 30)
```

Expression F1b-D — Compose ApplicantShort. It drops a trailing dot, which SharePoint rejects at the end of a folder name:

```
take(outputs('Compose_ApplicantClean'), sub(length(outputs('Compose_ApplicantClean')), if(endsWith(outputs('Compose_ApplicantClean'), '.'), 1, 0)))
```

Expression F1b-E — Compose LocationClean:

```
take(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(coalesce(triggerBody()?['LocationName'], 'Location'), '~', ''), '"', ''), '#', ''), '%', ''), '&', ''), '*', ''), ':', ''), '<', ''), '>', ''), '?', ''), '/', ''), '\', ''), '{', ''), '|', ''), '}', ''), ' ', ''), '..', '.'), '..', '.'), '..', '.'), '..', '.'), 30)
```

Expression F1b-F — Compose LocationShort:

```
take(outputs('Compose_LocationClean'), sub(length(outputs('Compose_LocationClean')), if(endsWith(outputs('Compose_LocationClean'), '.'), 1, 0)))
```

Expression F1b-G — Compose FolderName:

```
concat(outputs('Compose_PermitNumber'), '_', outputs('Compose_ApplicantShort'), '_', outputs('Compose_LocationShort'))
```

Expression F1b-H — Received Date. It keeps a date staff typed and fills today's local date otherwise:

```
coalesce(triggerBody()?['ReceivedDate'], formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd'))
```

Expression F1b-I — audit Detail:

```
concat('Permit ', outputs('Compose_PermitNumber'), ' created. Folder: ', outputs('Compose_FolderPath'))
```

Expression F1b-J — email To. It is the coordinator, or the program mailbox when no coordinator is set:

```
if(empty(triggerBody()?['Coordinator']?['Email']), first(body('Get_items_Mailbox')?['value'])?['Value'], triggerBody()?['Coordinator']?['Email'])
```

Text F1b-K — email Body. Paste it into the body as plain text:

```
Applicant: @{triggerBody()?['ApplicantName']} (@{triggerBody()?['ApplicantOrg']})
Permit type: @{triggerBody()?['PermitType']?['Value']}
Dates: @{triggerBody()?['ProposedStart']} to @{triggerBody()?['ProposedEnd']}
Record: @{triggerBody()?['{Link}']}
Folder: @{outputs('Compose_TenantRoot')}@{replace(outputs('Compose_FolderPath'), ' ', '%20')}
```

### Tenant tests and notes

- *Test in your tenant:* open run history and check that **Create new folder** returned `{Link}`. If the Folder column stays empty, set Folder to `concat(outputs('Compose_TenantRoot'), replace(outputs('Compose_FolderPath'), ' ', '%20'))`.
- The folder name always starts with the permit number, so it cannot start with a dot.
- The setup script seeds `NextSeq_` rows for this year and next year. Action 6N creates the row if one is ever missing.
- F1b emails the coordinator, not the applicant. The coordinator then sends the applicant their number and instructions. Add-on B below automates that email.

### Check it works

1. Create two Permits items a few seconds apart with **+ New**. They must get consecutive numbers and one folder each.
2. Submit three test applications through the form once F1a is built: one with ground disturbance, one near water, one with tree clearing. Each should show a number within a few minutes.
3. Confirm a sample permit imported with a number is not renumbered.

### Add-on A — default Coordinator and Superintendent

Use this when one coordinator and one Superintendent handle most permits. The setup script creates the two Settings rows with a blank value, or with the values of `-DefaultCoordinator` and `-DefaultSuperintendent` on the run that creates them. Later runs skip existing rows, so edit the rows by hand after that. A blank value leaves the column empty.

1. In **Settings**, set the **Value** of rows `DefaultCoordinator` and `DefaultSuperintendent` to one email address each. Add the rows if they are missing.
2. Before action 16, add **Get items** renamed **Get items DefCoord**: list **Settings**, Filter Query `Title eq 'DefaultCoordinator'`, Top Count `1`.
3. Add **Get items** renamed **Get items DefSup**: the same, with `Title eq 'DefaultSuperintendent'`.
4. In action 16, set **Coordinator Claims** to expression F1b-L and **Superintendent Claims** to expression F1b-M.

Expression F1b-L — Coordinator Claims:

```
if(empty(triggerBody()?['Coordinator']?['Claims']), if(empty(first(body('Get_items_DefCoord')?['value'])?['Value']), null, concat('i:0#.f|membership|', first(body('Get_items_DefCoord')?['value'])?['Value'])), triggerBody()?['Coordinator']?['Claims'])
```

Expression F1b-M — Superintendent Claims:

```
if(empty(triggerBody()?['Superintendent']?['Claims']), if(empty(first(body('Get_items_DefSup')?['value'])?['Value']), null, concat('i:0#.f|membership|', first(body('Get_items_DefSup')?['value'])?['Value'])), triggerBody()?['Superintendent']?['Claims'])
```

*Test in your tenant:* create one item with no coordinator and confirm the default person appears. A wrong email address makes action 16 fail.

### Add-on B — acknowledgement email to the applicant

Use this with the reply-with-files option (build guide Step 3.2). Replies must reach the shared mailbox, so the email is sent from that mailbox.

Add these two actions after action 19.

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 20 | Condition → **Condition Has applicant email** | Left value | `empty(triggerBody()?['ApplicantEmail'])` |
|  |  | Operator and right value | **is equal to** `false` |
| 20Y.1 | Send an email from a shared mailbox (V2) → **Send an email from a shared mailbox (V2)** (default name) | Original Mailbox Address | `first(body('Get_items_Mailbox')?['value'])?['Value']` |
|  |  | To | `triggerBody()?['ApplicantEmail']` |
|  |  | Subject | Text `@{outputs('Compose_PermitNumber')} documents` |
|  |  | Body | Text F1b-N |

Text F1b-N — applicant email Body:

```
We received your special use permit application. Your permit number is @{outputs('Compose_PermitNumber')}.
Reply to this email with your site plan and certificate of insurance attached.
Keep @{outputs('Compose_PermitNumber')} in the subject line so your files reach the right record.
```

Use made-up applicant email addresses in the test site, because this action emails people outside the office.

## F1a — Form to Permits item

F1a turns one Microsoft Forms response into one Permits item. That is all it does. F1b then numbers the item. Skip F1a if you do not take applications through Forms.

### Trigger and settings

- **Trigger:** Microsoft Forms **When a new response is submitted**. Form Id: the application form. Flow name: `SUP – Form to Permits Item`.
- For a group form, the form is not in the dropdown. Choose **Enter custom value** and paste the text after `FormId=` from the form's edit address.

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Get response details → **Get response details** (default name) | Form Id | The same form |
|  |  | Response Id | `triggerOutputs()?['body/resourceData/responseId']` |
| 2 | Get items → **Get items Existing** | List Name | Choose **Permits** |
|  |  | Filter Query | Text `SourceSubmissionId eq '@{triggerOutputs()?['body/resourceData/responseId']}'` |
|  |  | Top Count | Text `1` |
| 3 | Condition → **Condition New response** | Left value | `length(body('Get_items_Existing')?['value'])` |
|  |  | Operator and right value | **is equal to** `0` |
| 3Y.1 | Compose → **Compose ImpactsAnswer** | Inputs | Token: the impacts question |
| 3Y.2 | Select → **Select Impacts** | From | `if(empty(outputs('Compose_ImpactsAnswer')), json('[]'), json(outputs('Compose_ImpactsAnswer')))` |
|  |  | Map | Stay in key and value mode. Key: Text `Value`. Value: `item()` |
| 3Y.3 | Compose → **Compose TypeAnswer** | Inputs | Token: the permit type question |
| 3Y.4 | Get items → **Get items Type** | List Name | Choose **PermitTypes** |
|  |  | Filter Query | Text `Title eq '@{replace(outputs('Compose_TypeAnswer'), '''', '''''')}'` |
|  |  | Top Count | Text `1` |
| 3Y.5 | Create item → **Create item Permit** | List Name | Choose **Permits** |
|  |  | Applicant Name, Applicant Organization, Applicant Email, Applicant Phone | Token: the matching answers |
|  |  | Project Title, Project Description, Location | Token: the matching answers |
|  |  | Proposed Start, Proposed End | Token: the two date answers |
|  |  | Permit Type Id | `first(body('Get_items_Type')?['value'])?['ID']` |
|  |  | Impacts | Select **Switch to input entire array**, then `body('Select_Impacts')` |
|  |  | Status Value | Text `Received` |
|  |  | Received Date | `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')` |
|  |  | Source Submission Id | `triggerOutputs()?['body/resourceData/responseId']` |

### Notes

- Action 2 and the condition skip a response that is replayed, so no duplicate permit is created.
- `PermitType` is a lookup column. It needs the type's item ID, which action 3Y.4 finds from the answer text.
- Forms returns a multiple-choice answer as text that looks like a list. Action 3Y.2 turns it into the shape a multi-choice column needs. An unanswered question becomes an empty list.
- The received date is the local date. Plain `utcNow()` would store tomorrow's date for anything received in the evening.
- The Response Id expression is the same value as the trigger's **Response Id** token.
- *Test in your tenant:* submit one response with two impacts ticked. Check in run history that **Select Impacts** returned two rows.

## F7b — Status changed logger

F7b writes one AuditLog row each time a permit's Status changes, showing the old and new status. It writes only to AuditLog, so it cannot loop.

### Trigger and settings

- **Trigger:** SharePoint **When an item or a file is modified**. List: **Permits**. Flow name: `SUP – Status Changed Logger`. No trigger condition.
- Versioning must be on for the Permits list. The setup script turns it on; build guide Step 1.4 covers the manual path.

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Get changes for an item or a file (properties only) → **Get changes** | List Name | Choose **Permits** |
|  |  | Id | `triggerBody()?['ID']` |
|  |  | Since | `triggerOutputs()?['body/{TriggerWindowStartToken}']` |
|  |  | Include Minor Versions | Choose **Yes** |
| 2 | Condition → **Condition Status changed** | Left value | `body('Get_changes')?['ColumnHasChanged']?['Status']` |
|  |  | Operator and right value | **is equal to** `true` |
| 2N.1 | Terminate → **Terminate Not status** | Status | Choose **Succeeded** |
| 3 | Send an HTTP request to SharePoint → **Send an HTTP request to SharePoint** (default name) | Method | Choose **GET** |
|  |  | Uri | Text F7b-A |
|  |  | Headers | Key: Text `Accept`. Value: Text `application/json;odata=nometadata` |
| 4 | Filter array → **Filter array OlderStatus** | From | `body('Send_an_HTTP_request_to_SharePoint')?['value']` |
|  |  | Condition | Select **Edit in advanced mode**, then paste Text F7b-B |
| 5 | Compose → **Compose PreviousStatus** | Inputs | `coalesce(first(body('Filter_array_OlderStatus'))?['Status'], '(none)')` |
| 6 | Run a Child Flow → **Audit Status Changed** | PermitNumber | `triggerBody()?['PermitNumber']` |
|  |  | PermitId | `triggerBody()?['ID']` |
|  |  | EventType | Text `Status Changed` |
|  |  | Detail | `concat(outputs('Compose_PreviousStatus'), ' → ', triggerBody()?['Status']?['Value'])` |
|  |  | Actor | `triggerBody()?['Editor']?['Email']` |

Text F7b-A — Uri:

```
_api/web/lists/getbytitle('Permits')/items(@{triggerBody()?['ID']})/versions?$select=VersionLabel,Status&$top=20
```

Text F7b-B — Filter array condition:

```
@not(equals(item()?['Status'], triggerBody()?['Status']?['Value']))
```

### Notes

- **Get changes** returns only "changed" or "not changed" for each column. The old status comes from version history in action 3.
- Action 4 finds the newest version whose status differs from the current one. The version just before is not enough, because other edits can add versions that already carry the new status.
- Two edits saved inside one trigger polling window arrive as one run. Only the net change is logged.
- When a flow made the change, Actor is the service account. The flow's own audit row carries the human context.
- *Test in your tenant:* the versions list should be newest first. If `$top` is rejected, remove `&$top=20` from the Uri.
- To log other milestones, copy actions 2 to 6 for `COIReceived`, `PermitteeSigned` or `SuperintendentSigned`, with EventType `Field Changed`.

## F5 — Close permit and move the folder

F5 moves a permit's folder to **Closed Projects** when its status becomes Closed, Withdrawn or Denied. It then updates the folder link, because the old link stops working after a move.

### Trigger and settings

- **Trigger:** SharePoint **When an item or a file is modified**. List: **Permits**. Flow name: `SUP – Close Permit`.
- **Concurrency control:** On, degree of parallelism `1`, so two quick edits cannot both try the move.
- **Trigger conditions:** paste Text F5-A on one line.

Text F5-A — trigger condition:

```
@and(contains(createArray('Closed','Withdrawn','Denied'), triggerBody()?['Status']?['Value']), not(empty(triggerBody()?['FolderPath'])), not(contains(coalesce(triggerBody()?['FolderPath'], ''), '/Closed Projects/')))
```

The flow's own update puts `/Closed Projects/` in the folder path, so the flow cannot start itself again. A permit with no folder path, such as a migrated permit without a folder, is skipped.

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Compose → **Compose TenantRoot** | Inputs | Text `https://<tenant>.sharepoint.com` |
| 3 | Compose → **Compose FolderSiteRel** | Inputs | `replace(triggerBody()?['FolderPath'], outputs('Compose_SiteRel'), '')` |
| 4 | Get items → **Get items Mailbox** | List Name | Choose **Settings** |
|  |  | Filter Query | Text `Title eq 'ProgramMailbox'` |
|  |  | Top Count | Text `1` |
| 5 | Get item → **Get item Fresh** | List Name | Choose **Permits** |
|  |  | Id | `triggerBody()?['ID']` |
| 6 | Condition → **Condition Already moved** | Left value | `contains(coalesce(body('Get_item_Fresh')?['FolderPath'], ''), '/Closed Projects/')` |
|  |  | Operator and right value | **is equal to** `true` |
| 6Y.1 | Terminate → **Terminate Already moved** | Status | Choose **Succeeded** |
| 7 | Move folder → **Move folder** (default name) | Current Site Address | Choose the site |
|  |  | Folder to Move | `outputs('Compose_FolderSiteRel')` |
|  |  | Destination Site Address | Choose the site |
|  |  | Destination Folder | Text `/PermitRecords/Closed Projects` |
|  |  | If another folder is already there | Choose **Fail this action** |
| 8 | Get folder metadata using path → **Get folder metadata using path Source** | Folder Path | `outputs('Compose_FolderSiteRel')` |
|  |  | Run after | **Move folder**: tick only **has failed** |
| 9 | Send an email (V2) → **Send an email (V2) Move failed** | To | Expression F5-B |
|  |  | Subject | Text `SUP folder move failed: @{triggerBody()?['PermitNumber']}` |
|  |  | Body | Text F5-C |
|  |  | Run after | **Get folder metadata using path Source**: tick only **is successful** |
| 10 | Terminate → **Terminate Move failed** | Status | Choose **Failed** |
|  |  | Message | Text `Folder move failed` |
| 11 | Compose → **Compose NewFolderPath** | Inputs | `replace(triggerBody()?['FolderPath'], '/PermitRecords/Open Projects/', '/PermitRecords/Closed Projects/')` |
|  |  | Run after | **Terminate Move failed**: tick only **is skipped** |
| 12 | Update item → **Update item Permit** | List Name | Choose **Permits** |
|  |  | Id | `triggerBody()?['ID']` |
|  |  | Folder Path | `outputs('Compose_NewFolderPath')` |
|  |  | Folder | `concat(outputs('Compose_TenantRoot'), replace(outputs('Compose_NewFolderPath'), ' ', '%20'))` |
|  |  | Closed Date | Expression F5-D |
|  |  | Status Value | `triggerBody()?['Status']?['Value']` |
| 13 | Run a Child Flow → **Audit Moved to Closed** | PermitNumber | `triggerBody()?['PermitNumber']` |
|  |  | PermitId | `triggerBody()?['ID']` |
|  |  | EventType | Text `Moved to Closed` |
|  |  | Detail | `concat('Status ', triggerBody()?['Status']?['Value'], '. Folder moved to ', outputs('Compose_NewFolderPath'))` |
|  |  | Actor | `triggerBody()?['Editor']?['Email']` |

Expression F5-B — email To. It is the coordinator and the program mailbox:

```
if(empty(triggerBody()?['Coordinator']?['Email']), first(body('Get_items_Mailbox')?['value'])?['Value'], concat(triggerBody()?['Coordinator']?['Email'], ';', first(body('Get_items_Mailbox')?['value'])?['Value']))
```

Text F5-C — email Body:

```
The folder for @{triggerBody()?['PermitNumber']} could not be moved to Closed Projects.
Folder: @{triggerBody()?['FolderPath']}
Error: @{coalesce(actions('Move_folder')?['error']?['message'], 'See the flow run history.')}
Close any open files in the folder, then edit and save the permit to try again.
```

Expression F5-D — Closed Date. It keeps a date already on the item:

```
coalesce(triggerBody()?['ClosedDate'], formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd'))
```

### How the failure path works

- **Move worked.** Actions 8 to 10 are skipped. Action 11 runs because action 10 was skipped.
- **Move failed and the folder is still there.** A file is open in Word, or a folder of that name already exists. Actions 8 to 10 email a person and stop the run as Failed. The permit stays closed with its folder under Open Projects until someone acts.
- **Move failed because an earlier run already moved the folder.** Action 8 fails, so 9 and 10 are skipped. Actions 11 to 13 then repair the item.

Status is re-sent in action 12 so the update cannot blank it.

### Tenant tests

- *Test in your tenant:* close a test permit. Confirm **Folder to Move** accepts the typed path `/PermitRecords/Open Projects/<name>`. If it fails, add **Get folder metadata using path** before action 7 and feed its `{Identifier}` to **Folder to Move**.
- *Test in your tenant:* confirm the dropdown offers **Fail this action**. Use the nearest label if the wording differs.
- *Test in your tenant:* if the designer will not add action 11 below a Terminate, add it as a parallel branch beside action 9. Set its run after to **Get folder metadata using path Source**: **has failed** and **is skipped**.
- **Verify:** instead of building Folder from the path in action 12, you can use `body('Move_folder')?['{Link}']` if **Move folder** returns it.
- *Test in your tenant:* note one file's ID and version count, close the permit, then compare. Do not assume item IDs or version history survive the move. Bookmarked folder links break.

## F6 — Daily reminders

One flow, F6, runs every morning. It finds permits that hit a reminder threshold today and sends each coordinator one digest email. F6 is part of the minimum working system, so build it straight after F5.

Each query matches dates exactly N days out, for each N in Settings. A permit therefore matches once at 60 days, once at 30 and once at 7, never in between. `LastReminderKey` stops a second run on the same day from sending anything twice.

### Which permits get which reminder

| Reminder | Date column | Days before (from Settings) | Statuses included |
| --- | --- | --- | --- |
| Permit expires | `PermitExpiration` | `ReminderDaysPermitExpiry`, seeded as 60, 30, 7 | Executed, Active |
| COI expires | `COIExpiration` | `ReminderDaysCOI`, seeded as 30, 7 | Every status except Closed, Withdrawn, Denied |
| Start date near, not executed | `ProposedStart` | `ReminderDaysStartUnexecuted`, seeded as 30, 14, 7 | The five statuses before Executed |

### Trigger and settings

- **Trigger:** **Recurrence**. Flow name: `SUP – Daily Reminders`.
- **Interval:** `1`. **Frequency:** Day. **Time zone:** your office time zone. **At these hours:** `7`. **At these minutes:** `0`.

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Get items → **Get items Settings** | List Name | Choose **Settings** |
|  |  | Top Count | Text `50` |
| 2 | Compose → **Compose Today** | Inputs | `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')` |
| 3 | Filter array → **Filter array Mailbox** | From | `body('Get_items_Settings')?['value']` |
|  |  | Condition | `item()?['Title']` **is equal to** Text `ProgramMailbox` |
| 4 | Compose → **Compose Mailbox** | Inputs | `first(body('Filter_array_Mailbox'))?['Value']` |
| 5 | Filter array → **Filter array Exp** | From | `body('Get_items_Settings')?['value']` |
|  |  | Condition | `item()?['Title']` **is equal to** Text `ReminderDaysPermitExpiry` |
| 6 | Filter array → **Filter array COI** | From | `body('Get_items_Settings')?['value']` |
|  |  | Condition | `item()?['Title']` **is equal to** Text `ReminderDaysCOI` |
| 7 | Filter array → **Filter array Start** | From | `body('Get_items_Settings')?['value']` |
|  |  | Condition | `item()?['Title']` **is equal to** Text `ReminderDaysStartUnexecuted` |
| 8 | Select → **Select ExpDates** | From | `split(first(body('Filter_array_Exp'))?['Value'], ',')` |
|  |  | Map | Text mode, then expression F6-A |
| 9 | Select → **Select COIDates** | From | `split(first(body('Filter_array_COI'))?['Value'], ',')` |
|  |  | Map | Text mode, then expression F6-A with `COIExpiration` in place of `PermitExpiration` |
| 10 | Select → **Select StartDates** | From | `split(first(body('Filter_array_Start'))?['Value'], ',')` |
|  |  | Map | Text mode, then expression F6-A with `ProposedStart` in place of `PermitExpiration` |
| 11 | Get items → **Get items Exp** | List Name | Choose **Permits** |
|  |  | Filter Query | Text F6-B |
|  |  | Top Count | Text `500` |
| 12 | Get items → **Get items COI** | List Name | Choose **Permits** |
|  |  | Filter Query | Text F6-C |
|  |  | Top Count | Text `500` |
| 13 | Get items → **Get items Start** | List Name | Choose **Permits** |
|  |  | Filter Query | Text F6-D |
|  |  | Top Count | Text `500` |
| 14 | Select → **Select ExpRows** | From | `body('Get_items_Exp')?['value']` |
|  |  | Map | Key and value mode, using the row map below |
| 15 | Select → **Select COIRows** | From | `body('Get_items_COI')?['value']` |
|  |  | Map | The row map, changed as the note below it says |
| 16 | Select → **Select StartRows** | From | `body('Get_items_Start')?['value']` |
|  |  | Map | The row map, changed as the note below it says |
| 17 | Filter array → **Filter array Due** | From | `union(body('Select_ExpRows'), body('Select_COIRows'), body('Select_StartRows'))` |
|  |  | Condition | Select **Edit in advanced mode**, then Text `@not(contains(item()?['PrevKey'], item()?['Key']))` |
| 18 | Select → **Select Recipients** | From | `body('Filter_array_Due')` |
|  |  | Map | Text mode, then `item()?['To']` |
| 19 | Compose → **Compose UniqueRecipients** | Inputs | `union(body('Select_Recipients'), body('Select_Recipients'))` |
| 20 | Apply to each → **Apply to each Recipient** | Select an output from previous steps | `outputs('Compose_UniqueRecipients')` |
| 20.1 | Filter array → **Filter array Mine** | From | `body('Filter_array_Due')` |
|  |  | Condition | `item()?['To']` **is equal to** `items('Apply_to_each_Recipient')` |
| 20.2 | Select → **Select Table** | From | `body('Filter_array_Mine')` |
|  |  | Map | Keys `Permit`, `Project`, `Reminder`, `Date`, `Link`: each `item()?['<same key>']`. Key `Days out`: `item()?['DaysOut']` |
| 20.3 | Create HTML table → **Create HTML table** (default name) | From | `body('Select_Table')` |
|  |  | Columns | Choose **Automatic** |
| 20.4 | Send an email (V2) → **Send an email (V2)** (default name) | To | `items('Apply_to_each_Recipient')` |
|  |  | CC | `outputs('Compose_Mailbox')` |
|  |  | Subject | Expression F6-E |
|  |  | Body | Text F6-F, pasted in the body's code view |
| 21 | Apply to each → **Apply to each Sent** | Select an output from previous steps | `body('Filter_array_Due')` |
|  |  | Settings | Concurrency control **On**, degree of parallelism `1` |
| 21.1 | Get item → **Get item Fresh** | List Name | Choose **Permits** |
|  |  | Id | `items('Apply_to_each_Sent')?['Id']` |
| 21.2 | Compose → **Compose NewKey** | Inputs | Expression F6-G |
| 21.3 | Update item → **Update item Key** | List Name | Choose **Permits** |
|  |  | Id | `items('Apply_to_each_Sent')?['Id']` |
|  |  | Last Reminder Key | `outputs('Compose_NewKey')` |
|  |  | Status Value | `body('Get_item_Fresh')?['Status']?['Value']` |
| 21.4 | Run a Child Flow → **Audit Reminder Sent** | PermitNumber | `items('Apply_to_each_Sent')?['Permit']` |
|  |  | PermitId | `items('Apply_to_each_Sent')?['Id']` |
|  |  | EventType | Text `Reminder Sent` |
|  |  | Detail | Expression F6-H |
|  |  | Actor | Text `system` |

### Row map for Select ExpRows

Add these ten keys in action 14.

| Key | Value |
| --- | --- |
| `Id` | `item()?['ID']` |
| `To` | `if(empty(item()?['Coordinator']?['Email']), outputs('Compose_Mailbox'), item()?['Coordinator']?['Email'])` |
| `Permit` | `item()?['PermitNumber']` |
| `Project` | `item()?['ProjectTitle']` |
| `Reminder` | Text `Permit expires` |
| `Date` | `formatDateTime(item()?['PermitExpiration'], 'yyyy-MM-dd')` |
| `DaysOut` | Expression F6-I |
| `Key` | `concat('EXP:', outputs('Compose_Today'))` |
| `PrevKey` | `coalesce(item()?['LastReminderKey'], '')` |
| `Link` | `item()?['{Link}']` |

For **Select COIRows**, use the same map with three changes. Reminder is `COI expires`. `COIExpiration` replaces `PermitExpiration` in `Date` and `DaysOut`. The `Key` prefix is `COI:`.

For **Select StartRows**, Reminder is `Start date, not executed`. `ProposedStart` replaces `PermitExpiration`. The `Key` prefix is `START:`.

### Expressions

Expression F6-A — one date clause per reminder offset. Inside the text, two single quotes stand for one:

```
concat('PermitExpiration eq ''', formatDateTime(addDays(utcNow(), int(trim(item()))), 'yyyy-MM-dd'), '''')
```

Text F6-B — Filter Query for permit expiration:

```
(@{join(body('Select_ExpDates'), ' or ')}) and (Status eq 'Executed' or Status eq 'Active')
```

Text F6-C — Filter Query for COI expiration:

```
(@{join(body('Select_COIDates'), ' or ')}) and Status ne 'Closed' and Status ne 'Withdrawn' and Status ne 'Denied'
```

Text F6-D — Filter Query for start dates:

```
(@{join(body('Select_StartDates'), ' or ')}) and (Status eq 'Received' or Status eq 'Under Review' or Status eq 'Draft Permit' or Status eq 'Out for Permittee Signature' or Status eq 'Out for Superintendent Signature')
```

Expression F6-E — email Subject:

```
concat('SUP reminders for ', outputs('Compose_Today'), ' (', string(length(body('Filter_array_Mine'))), ')')
```

Text F6-F — email Body:

```
<p>Permits needing attention:</p>@{body('Create_HTML_table')}
```

Expression F6-G — Compose NewKey. It adds today's key and keeps the last 12, which fit in a single-line column:

```
join(skip(split(concat(coalesce(body('Get_item_Fresh')?['LastReminderKey'], ''), '|', items('Apply_to_each_Sent')?['Key']), '|'), max(0, sub(length(split(concat(coalesce(body('Get_item_Fresh')?['LastReminderKey'], ''), '|', items('Apply_to_each_Sent')?['Key']), '|')), 12))), '|')
```

Expression F6-H — audit Detail:

```
concat(items('Apply_to_each_Sent')?['Reminder'], ' in ', string(items('Apply_to_each_Sent')?['DaysOut']), ' days, to ', items('Apply_to_each_Sent')?['To'])
```

Expression F6-I — whole days from today to the date:

```
div(sub(ticks(formatDateTime(item()?['PermitExpiration'], 'yyyy-MM-dd')), ticks(outputs('Compose_Today'))), 864000000000)
```

With today as 2026-11-23, Text F6-B resolves to this:

```
(PermitExpiration eq '2027-01-22' or PermitExpiration eq '2026-12-23' or PermitExpiration eq '2026-11-30') and (Status eq 'Executed' or Status eq 'Active')
```

### Notes

- Action 17 drops reminders already sent today. That is what makes a re-run on the same day send nothing.
- Action 21 runs one item at a time. A permit can appear twice on one day, and the two updates must not collide.
- The first run leaves an empty first entry in `LastReminderKey`. That is harmless.
- Updating `LastReminderKey` starts the item-modified flows. F7b and F2a ignore it because Status did not change. F5 ignores it because of its trigger condition.
- The Link column holds a plain web address, which email programs turn into a link. **Create HTML table** would show an HTML link tag as text.
- For table borders, wrap the table in `replace(body('Create_HTML_table'), '<table>', '<table border="1" cellpadding="4" style="border-collapse:collapse">')`.
- Keep at least one number in each reminder setting. An empty setting makes its query fail.
- Time zone: at 7:00 in any US state, the UTC date and the local date are the same. For an evening schedule, or an office ahead of UTC such as Guam, replace `utcNow()` in expression F6-A with `convertFromUtc(utcNow(), 'Eastern Standard Time')`.

*Test in your tenant:* set one test permit's Permit Expiration to exactly 30 days out and run the flow. If the permit is missed, the exact-date filter does not match date-only values in your site's time zone. Use one of these instead:

- A date range in each clause: `(PermitExpiration ge 'D' and PermitExpiration lt 'D+1')`. Build `D+1` with `addDays(utcNow(), add(int(trim(item())), 1))`.
- No date clause in the query. Filter in the flow by comparing `formatDateTime(item()?['PermitExpiration'], 'yyyy-MM-dd')` with the wanted dates.

### Optional additions

**A weekly list of COIs that have already expired.** The *COI expiring* view already shows them. To add them to Monday's digest:

1. After action 13, add **Get items** renamed **Get items COIExpired** on Permits, Top Count `500`, with Filter Query text F6-J.
2. Add **Select** renamed **Select COIExpiredRows** with the row map. Reminder is `COI expired`. Use `COIExpiration`. The `Key` prefix is `COIX:`.
3. In action 17, replace **From** with expression F6-K. Day 1 is Monday.

Text F6-J — Filter Query for expired COIs:

```
COIExpiration lt '@{outputs('Compose_Today')}' and Status ne 'Closed' and Status ne 'Withdrawn' and Status ne 'Denied'
```

Expression F6-K — the Monday-only union:

```
union(body('Select_ExpRows'), body('Select_COIRows'), body('Select_StartRows'), if(equals(dayOfWeek(convertFromUtc(utcNow(), 'Eastern Standard Time')), 1), body('Select_COIExpiredRows'), json('[]')))
```

**A reminder to the permittee.** Add a second loop over `body('Select_COIRows')` that emails the applicant from the shared mailbox, 30 days before the COI expires. Copy the coordinator.

### Check it works

1. Give three test permits the same Coordinator, so they land in one email.
2. Set the first permit's Permit Expiration to exactly 30 days from today, with status Active.
3. Set the second permit's COI Expiration to 7 days from today.
4. Set the third permit's Proposed Start 14 days out, with status Draft Permit.
5. Run the flow by hand. One email should list all three.
6. Run it again the same day. The second run must send nothing.

With the sample permits (`Permits-sample.csv`) on the anchor date, F6 flags six reminders:

- 0006 (expiry, 60 days) and 0005 (expiry, 30 days)
- 0006 (COI, 30 days) and 0007 (COI, 7 days)
- 0009 (start, 30 days) and 0010 (start, 14 days)

## F8 — Mailbox attachments

F8 saves attachments from emails in the shared mailbox into the right permit folder. It reads the permit number from the subject line.

F8 cannot tell a certificate of insurance from a site plan. It files everything as Correspondence. The coordinator then renames the file and sets its **Doc Type**.

### Trigger and settings

- **Trigger:** Office 365 Outlook **When a new email arrives in a shared mailbox (V2)**. Flow name: `SUP – Mailbox Attachments`.
- **Original Mailbox Address:** the shared mailbox. **Subject Filter:** `SUP-`. **Include Attachments:** Yes. **Only with Attachments:** Yes.
- The service account needs **Full Access** on the mailbox (build guide Phase 0, Accounts item 3).

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Compose → **Compose PermitNumber** | Inputs | Expression F8-A |
| 3 | Get items → **Get items Permit** | List Name | Choose **Permits** |
|  |  | Filter Query | Text `PermitNumber eq '@{outputs('Compose_PermitNumber')}'` |
|  |  | Top Count | Text `1` |
| 4 | Condition → **Condition Permit found** | Left value | Expression F8-B |
|  |  | Operator and right value | **is equal to** `true` |
| 4N.1 | Terminate → **Terminate No match** | Status | Choose **Succeeded** |
| 5 | Compose → **Compose FolderSiteRel** | Inputs | `replace(first(body('Get_items_Permit')?['value'])?['FolderPath'], outputs('Compose_SiteRel'), '')` |
| 6 | Apply to each → **Apply to each Attachment** | Select an output from previous steps | `triggerOutputs()?['body/attachments']` |
| 6.1 | Condition → **Condition Real attachment** | Left value | `not(equals(items('Apply_to_each_Attachment')?['isInline'], true))` |
|  |  | Operator and right value | **is equal to** `true` |
| 6.1Y.1 | Create file → **Create file** (default name) | Folder Path | `outputs('Compose_FolderSiteRel')` |
|  |  | File Name | Expression F8-C |
|  |  | File Content | `base64ToBinary(items('Apply_to_each_Attachment')?['contentBytes'])` |
| 6.1Y.2 | Update file properties → **Update file properties** (default name) | Library Name | Choose **Permit Records** |
|  |  | Id | `body('Create_file')?['ItemId']` |
|  |  | Permit Number | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
|  |  | Doc Type Value | Text `Correspondence` |
| 6.1Y.3 | Run a Child Flow → **Audit Document Added** | PermitNumber | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Document Added` |
|  |  | Detail | `concat('Email attachment filed: ', body('Create_file')?['Name'])` |
|  |  | Actor | `triggerOutputs()?['body/from']` |

Expression F8-A — Compose PermitNumber. It takes the 13 characters that start at `SUP-`:

```
substring(triggerOutputs()?['body/subject'], indexOf(triggerOutputs()?['body/subject'], 'SUP-'), 13)
```

Expression F8-B — permit found and it has a folder:

```
and(greater(length(body('Get_items_Permit')?['value']), 0), not(empty(first(body('Get_items_Permit')?['value'])?['FolderPath'])))
```

Expression F8-C — File Name:

```
concat(first(body('Get_items_Permit')?['value'])?['PermitNumber'], '_Correspondence_', formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd'), '_', items('Apply_to_each_Attachment')?['name'])
```

### Notes

- An email whose number matches no permit ends at action 4N.1. It stays in the Inbox for a person to file.
- A subject with fewer than 13 characters after `SUP-` makes action 2 fail. The email stays in the Inbox.
- Action 6.1 skips pictures inside the message, such as signature logos.
- Two attachments with the same name on the same day clash. The second **Create file** fails and a person files it.
- *Test in your tenant:* send a test email with one PDF and a logo in the signature. Check that only the PDF is filed. If nothing is filed, look at the attachment's field names in run history.

## F2a — Suggest conditions when review starts

F2a adds the suggested conditions to a permit when its status changes to `Under Review`. It applies the rule in build guide Step 2.3 and never adds a condition twice.

A flow has one trigger. F2a starts from the status change. F2b, built with the app, is the same flow started from a button.

### Trigger and settings

- **Trigger:** SharePoint **When an item or a file is modified**. List: **Permits**. Flow name: `SUP – Suggest Conditions (status)`.
- **Trigger conditions:** `@equals(triggerBody()?['Status']?['Value'], 'Under Review')`

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Initialize variable → **Initialize varAdded** | Name | Text `varAdded` |
|  |  | Type | Choose **Integer** |
|  |  | Value | Text `0` |
| 2 | Get changes for an item or a file (properties only) → **Get changes** | List Name | Choose **Permits** |
|  |  | Id | `triggerBody()?['ID']` |
|  |  | Since | `triggerOutputs()?['body/{TriggerWindowStartToken}']` |
| 3 | Condition → **Condition Status changed** | Left value | `body('Get_changes')?['ColumnHasChanged']?['Status']` |
|  |  | Operator and right value | **is equal to** `true` |
| 3N.1 | Terminate → **Terminate Not status** | Status | Choose **Succeeded** |
| 4 | Get item → **Get item Permit** | List Name | Choose **Permits** |
|  |  | Id | `triggerBody()?['ID']` |
| 5 | Compose → **Compose PermitTypeId** | Inputs | `body('Get_item_Permit')?['PermitType']?['Id']` |
| 6 | Select → **Select PermitImpacts** | From | `coalesce(body('Get_item_Permit')?['Impacts'], json('[]'))` |
|  |  | Map | Switch Map to text mode, then `item()?['Value']` |
| 7 | Get items → **Get items Library** | List Name | Choose **ConditionLibrary** |
|  |  | Filter Query | Text `Active eq 1` |
|  |  | Order By | Text `SortOrder asc` |
|  |  | Top Count | Text `500` |
| 8 | Get items → **Get items Existing** | List Name | Choose **PermitConditions** |
|  |  | Filter Query | Text `PermitId eq @{body('Get_item_Permit')?['ID']}` |
|  |  | Top Count | Text `500` |
| 9 | Select → **Select ExistingConditionIds** | From | `body('Get_items_Existing')?['value']` |
|  |  | Map | Text mode, then `item()?['Condition']?['Id']` |
| 10 | Apply to each → **Apply to each Condition** | Select an output from previous steps | `body('Get_items_Library')?['value']` |
|  |  | Settings | Concurrency control **On**, degree of parallelism `1` |
| 10.1 | Select → **Select TypeIds** | From | `coalesce(items('Apply_to_each_Condition')?['AppliesToTypes'], json('[]'))` |
|  |  | Map | Text mode, then `item()?['Id']` |
| 10.2 | Select → **Select TriggerValues** | From | `coalesce(items('Apply_to_each_Condition')?['TriggerImpacts'], json('[]'))` |
|  |  | Map | Text mode, then `item()?['Value']` |
| 10.3 | Compose → **Compose Match** | Inputs | Expression F2-A |
| 10.4 | Condition → **Condition Match** | Left value | `outputs('Compose_Match')` |
|  |  | Operator and right value | **is equal to** `true` |
| 10.4Y.1 | Create item → **Create item PermitCondition** | List Name | Choose **PermitConditions** |
|  |  | Title | `items('Apply_to_each_Condition')?['ConditionCode']` |
|  |  | Permit Id | `body('Get_item_Permit')?['ID']` |
|  |  | Condition Id | `items('Apply_to_each_Condition')?['ID']` |
|  |  | Condition Text | `items('Apply_to_each_Condition')?['ConditionText']` |
|  |  | Source Value | Text `Suggested` |
|  |  | Included | Choose **Yes** |
|  |  | Sort Order | `items('Apply_to_each_Condition')?['SortOrder']` |
| 10.4Y.2 | Increment variable → **Increment varAdded** | Name | Choose **varAdded** |
|  |  | Value | Text `1` |
| 11 | Run a Child Flow → **Audit Conditions Suggested** | PermitNumber | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | PermitId | `body('Get_item_Permit')?['ID']` |
|  |  | EventType | Text `Field Changed` |
|  |  | Detail | `concat(string(variables('varAdded')), ' condition(s) suggested from library')` |
|  |  | Actor | `triggerBody()?['Editor']?['Email']` |

Expression F2-A — Compose Match. It is the build guide Step 2.3 rule, plus a check that the condition is not already on the permit:

```
and(
  or(
    equals(length(body('Select_TypeIds')), 0),
    greater(length(intersection(body('Select_TypeIds'), createArray(outputs('Compose_PermitTypeId')))), 0)
  ),
  or(
    equals(items('Apply_to_each_Condition')?['AlwaysInclude'], true),
    greater(length(intersection(body('Select_TriggerValues'), body('Select_PermitImpacts'))), 0)
  ),
  not(contains(body('Select_ExistingConditionIds'), items('Apply_to_each_Condition')?['ID']))
)
```

### Notes

- The **Initialize variable** action must sit at the top level, outside any condition or loop.
- The library query does not filter on the two multi-value columns. SharePoint cannot filter those reliably, so the flow does it.
- The condition text is copied to the permit as a snapshot. Later edits to the library do not change issued permits.
- The Condition action has no advanced mode in the current designer. That is why the rule sits in a Compose and the Condition tests it against `true`.
- *Test in your tenant:* if action 8 is rejected, change its filter to `Permit/Id eq @{body('Get_item_Permit')?['ID']}`.
- *Test in your tenant:* run it on a permit with no impacts ticked. The `coalesce` in action 6 keeps an empty value from failing the run.
- *Test in your tenant:* if nothing matches by type, wrap the type ID as `int(outputs('Compose_PermitTypeId'))` inside `createArray`.

### Check it works

Set a sample permit to `Under Review`. With the sample data, every permit gets the six standard conditions (GEN-01 to GEN-04, INS-01, INS-02). Permit 0012 also gets WAT-01, SAF-01 and SAF-02, nine in total. Set the status away and back: no duplicates appear.

## F2b — Suggest conditions from the app

Build F2b with the app (build guide Phase 6). It is F2a with a different trigger, so the coordinator can run suggestions again at any status.

1. Create a new flow in the solution named exactly `SUPSuggestConditions`.
2. **Trigger:** **Power Apps (V2)**. Add one Number input named `PermitId`.
3. Add F2a's actions 1 and 4 to 11. Leave out actions 2 and 3, which belong to the status trigger.
4. In action 4, set **Id** to Token **PermitId** instead of the expression.
5. In action 11, set **Actor** to expression F2-B.
6. Add a last action, **Respond to a Power App or flow**, renamed **Respond added**. Add a Number output named `added` with value `variables('varAdded')`.
7. Save, then set **Run only users** as described under "Rules that apply to every flow".

Expression F2-B — Actor for app-started flows:

```
base64ToString(coalesce(triggerOutputs()?['headers']?['x-ms-user-email-encoded'], base64('app user')))
```

*Test in your tenant:* run F2b from the app and read the Actor on the new AuditLog row. If it shows `app user`, the trigger did not pass the person's email. Nothing else breaks.

*Test in your tenant:* use **Peek code** on the trigger to see the input's key. The **PermitId** token works whatever the key is.

The app calls `SUPSuggestConditions.Run(varPermit.ID)` (build guide formula 6-I). The flow name has no spaces, because the app calls it by name, and `varPermit.ID` works on any screen, unlike `ThisItem.ID`.

Without the response action, the app refreshes before the new rows exist. To save typing, you can copy each action from F2a with **… → Copy action** and paste it into F2b.

## F3 — Generate the draft permit

F3 creates the draft permit document in the permit's folder and sets the status to `Draft Permit`. Build the standard-licence version first. Move to the Premium version when the licence is in place.

### Licensing, stated once

The only Premium piece is the Word Online (Business) connector. A flow started from the app is licensed per person who runs it. So either every coordinator who presses **Generate draft** needs Power Apps Premium, or the flow carries one Power Automate Process licence. A Premium licence on the service account alone does not cover it. Sharing one licensed account between many users is not compliant. If neither is in budget, stay on the standard-licence version.

### Trigger and settings

- **Trigger:** **Power Apps (V2)** with one Number input named `PermitId`. Flow name: exactly `SUPGenerateDraft`.
- After saving, set **Run only users** as described under "Rules that apply to every flow".
- Until the app exists, run it from **Test → Manually** with a permit's ID.

### Permit expiration

If **Permit Expiration** is blank, F3 sets it to Proposed Start plus the permit type's default term. It writes the date to the permit and says so in the audit row. If Proposed Start is also blank, F3 stops and asks the coordinator to enter the dates.

### Actions shared by both versions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Get item → **Get item Permit** | List Name | Choose **Permits** |
|  |  | Id | Token **PermitId** |
| 3 | Get item → **Get item Type** | List Name | Choose **PermitTypes** |
|  |  | Id | `body('Get_item_Permit')?['PermitType']?['Id']` |
| 4 | Compose → **Compose Expiration** | Inputs | Expression F3-A |
| 5 | Condition → **Condition Expiration missing** | Left value | `empty(outputs('Compose_Expiration'))` |
|  |  | Operator and right value | **is equal to** `true` |
| 5Y.1 | Respond to a Power App or flow → **Respond No dates** | Text output `fileUrl` | Leave empty |
|  |  | Text output `message` | Text `Draft not generated: enter Proposed Start (or Permit Expiration) on the permit, then try again.` |
| 5Y.2 | Terminate → **Terminate No dates** | Status | Choose **Cancelled** |
| 6 | Get items → **Get items Conditions** | List Name | Choose **PermitConditions** |
|  |  | Filter Query | Text `PermitId eq @{body('Get_item_Permit')?['ID']} and Included eq 1` |
|  |  | Order By | Text `SortOrder asc` |
|  |  | Top Count | Text `500` |
| 7 | Compose → **Compose FolderSiteRel** | Inputs | `replace(body('Get_item_Permit')?['FolderPath'], outputs('Compose_SiteRel'), '')` |
| 8 | Get files (properties only) → **Get files Drafts** | Library Name | Choose **Permit Records** |
|  |  | Filter Query | Text F3-B |
|  |  | Limit Entries to Folder | `outputs('Compose_FolderSiteRel')` |
| 9 | Select → **Select DraftNumbers** | From | `body('Get_files_Drafts')?['value']` |
|  |  | Map | Text mode, then expression F3-C |
| 10 | Compose → **Compose Version** | Inputs | `add(max(union(body('Select_DraftNumbers'), createArray(0))), 1)` |

Expression F3-A — Compose Expiration. It gives the expiration as `yyyy-MM-dd`, or empty text when it cannot be worked out:

```
if(not(empty(body('Get_item_Permit')?['PermitExpiration'])), formatDateTime(body('Get_item_Permit')?['PermitExpiration'], 'yyyy-MM-dd'), if(or(empty(body('Get_item_Permit')?['ProposedStart']), empty(body('Get_item_Type')?['DefaultTermDays'])), '', addDays(body('Get_item_Permit')?['ProposedStart'], int(body('Get_item_Type')?['DefaultTermDays']), 'yyyy-MM-dd')))
```

Text F3-B — Filter Query for Word drafts only:

```
startswith(FileLeafRef, '@{body('Get_item_Permit')?['PermitNumber']}_DraftPermit_v') and substringof('.docx', FileLeafRef)
```

Expression F3-C — the number after `_v` in each draft's file name:

```
int(first(split(first(split(last(split(item()?['{FilenameWithExtension}'], '_DraftPermit_v')), '.')), '_')))
```

Notes on the shared actions:

- The version is the highest existing draft number plus one. Deleting an old draft cannot cause a name clash.
- Tell staff not to rename drafts. A name whose `_v` is not followed by a number makes action 9 fail.
- *Test in your tenant:* confirm **Limit Entries to Folder** accepts the path from action 7. If not, pick a folder once to see the format it wants.
- *Test in your tenant:* use **Peek code** on the trigger to see the input's key. The **PermitId** token works whatever the key is.
- *Test in your tenant:* if action 6 is rejected, change `PermitId eq` to `Permit/Id eq`.

### Version 1 — standard licence

No standard action fills a Word template. This version copies the type's template into the folder under the right name. Word fills the permit number from the library's columns. The coordinator pastes the conditions once.

Prepare each template first:

1. Open the Word template from inside **Permit Records**, in the `_Templates` folder. The template must live in this library, because document properties bind only to the columns of the library that holds the file.
2. Where the permit number goes, select **Insert → Quick Parts → Document Property → Permit Number**.
3. Add a heading for conditions with one empty numbered paragraph under it. The coordinator pastes there.
4. Check that each PermitTypes row's **Template File** holds that template's path.

Only **Permit Number** and **Doc Type** fill in as built. To fill more fields the same way, see the add-on after the table.

Add these actions after action 10.

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 11 | Select → **Select ConditionLines** | From | `body('Get_items_Conditions')?['value']` |
|  |  | Map | Text mode, then `concat(item()?['Title'], '  ', item()?['ConditionText'])` |
| 12 | Compose → **Compose ConditionsBlock** | Inputs | `join(body('Select_ConditionLines'), decodeUriComponent('%0D%0A%0D%0A'))` |
| 13 | Get file content using path → **Get file content using path** (default name) | File Path | `replace(body('Get_item_Type')?['TemplateFile'], outputs('Compose_SiteRel'), '')` |
| 14 | Create file → **Create file** (default name) | Folder Path | `outputs('Compose_FolderSiteRel')` |
|  |  | File Name | Expression F3-D |
|  |  | File Content | `body('Get_file_content_using_path')` |
| 15 | Update file properties → **Update file properties** (default name) | Library Name | Choose **Permit Records** |
|  |  | Id | `body('Create_file')?['ItemId']` |
|  |  | Permit Number | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | Doc Type Value | Text `Draft Permit` |
| 16 | Update item → **Update item Permit** | List Name | Choose **Permits** |
|  |  | Id | `body('Get_item_Permit')?['ID']` |
|  |  | Status Value | Text `Draft Permit` |
|  |  | Permit Expiration | Expression F3-E |
|  |  | Signature Request Id | `null` |
|  |  | Permittee Signed | `null` |
| 17 | Run a Child Flow → **Audit Document Added** | PermitNumber | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | PermitId | `body('Get_item_Permit')?['ID']` |
|  |  | EventType | Text `Document Added` |
|  |  | Detail | Expression F3-F |
|  |  | Actor | Expression F3-H |
| 18 | Respond to a Power App or flow → **Respond Done** | Text output `fileUrl` | `body('Update_file_properties')?['{Link}']` |
|  |  | Text output `message` | Text `Draft generated. Paste the conditions into the document.` |
|  |  | Text output `conditions` | `outputs('Compose_ConditionsBlock')` |

Expression F3-D — File Name:

```
concat(body('Get_item_Permit')?['PermitNumber'], '_DraftPermit_v', string(outputs('Compose_Version')), '.docx')
```

Expression F3-E — Permit Expiration. It keeps a date staff typed and saves the default otherwise:

```
if(empty(body('Get_item_Permit')?['PermitExpiration']), outputs('Compose_Expiration'), body('Get_item_Permit')?['PermitExpiration'])
```

Expression F3-F — audit Detail:

```
concat('Draft permit generated: ', body('Create_file')?['Name'], if(empty(body('Get_item_Permit')?['PermitExpiration']), concat('. Permit Expiration was blank; set to ', outputs('Compose_Expiration'), ' (Proposed Start + ', string(body('Get_item_Type')?['DefaultTermDays']), ' days).'), ''))
```

Expression F3-H — Actor for app-started flows:

```
base64ToString(coalesce(triggerOutputs()?['headers']?['x-ms-user-email-encoded'], base64('app user')))
```

Notes on version 1:

- Every response action in a flow must return the same outputs. Add an empty Text output `conditions` to action 5Y.1 as well.
- Action 16's two `null` values reset the signature fields when a draft is regenerated. Cancel any request already out in the e-signature service by hand.
- F7b logs the status change. The audit row here logs the document.
- Earlier versions of this sheet copied the template with **Copy file** and then renamed it. No standard action renames a file, so actions 13 and 14 create the file under its final name instead. The old route is kept below as an alternative.
- **Verify:** **Create file** has no `{Link}` output, which is why action 18 reads `{Link}` from **Update file properties**. Check the output name in run history.
- *Test in your tenant:* confirm the two signature columns are blank after a run. If a `null` is ignored, clear the two columns by hand in grid view.
- *Test in your tenant:* open a generated draft in Word and confirm the permit number shows. The first open can take a minute to refresh.
- Until the app exists, nobody sees the response. Add a temporary **Send an email (V2)** before action 18 that sends the link and `outputs('Compose_ConditionsBlock')` to the coordinator.

Alternative — **Copy file** and rename (not recommended). Replace actions 13 and 14 with **Copy file** from `_Templates/<template>` to the permit folder, then rename the copy to the name in expression F3-D. **Move file** has no new-name field, so the rename needs **Send an HTTP request to SharePoint** with the `MoveTo` method; **verify** the call before relying on it. Action 15 then needs the copy's item ID in place of `body('Create_file')?['ItemId']`.

Add-on — more fields through Quick Parts. The setup script does not create these columns.

1. In **Permit Records**, add single-line text columns `ApplicantName`, `LocationName`, `ProposedStart`, `ProposedEnd` and `PermitExpiration`. Text columns let the flow send dates already written out.
2. In action 15, fill each new column from **Get item Permit**. For the dates, use the null-safe pattern under Version 2.
3. In each template, add the matching Quick Parts.

### Version 2 — Premium (Word template filled by the flow)

This version fills every field and the numbered conditions with no paste. It replaces version 1's actions 11 to 18.

Prepare one master template:

1. Use Word for Windows desktop. Turn on the **Developer** tab under **File → Options → Customize Ribbon**.
2. Where each field goes, insert a **Plain Text Content Control**. Select **Properties** and set **Title** to the field name. Set **Tag** to the same value.
3. Use these nine titles: `PermitNumber`, `ApplicantName`, `ApplicantOrg`, `ProjectTitle`, `LocationName`, `ProposedStart`, `ProposedEnd`, `PermitExpiration`, `PermitTypeName`.
4. For the conditions, insert a **Repeating Section Content Control** titled `Conditions`. Inside it, put one numbered paragraph holding two plain-text controls titled `ConditionCode` and `ConditionText`.
5. Save it as `SUP_Template_Master.docx` in `Permit Records/_Templates`.

The connector matches fields by **Title**. Two controls with the same title get the same value. It fills plain text, drop-down, combo box, image and repeating section controls only. Rich text, date picker and check box controls are not supported. Keep the template under 10 MB.

One master template is the simplest design. Type-specific wording belongs in the condition library, not in six templates. If you must keep one template per type, see the note after the table.

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 11 | Select → **Select WordConditions** | From | `body('Get_items_Conditions')?['value']` |
|  |  | Map | Key and value mode. Key `ConditionCode`: `item()?['Title']`. Key `ConditionText`: `item()?['ConditionText']` |
| 12 | Populate a Microsoft Word template → **Populate a Microsoft Word template** (default name) | Location | Choose the site |
|  |  | Document Library | Choose **Permit Records** |
|  |  | File | Browse to `/_Templates/SUP_Template_Master.docx` |
|  |  | PermitNumber | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | ApplicantName, ApplicantOrg, ProjectTitle, LocationName | The same pattern, with each column's name |
|  |  | PermitTypeName | `body('Get_item_Permit')?['PermitType']?['Value']` |
|  |  | ProposedStart | Expression F3-G |
|  |  | ProposedEnd | Expression F3-G with `ProposedEnd` in both places |
|  |  | PermitExpiration | `formatDateTime(outputs('Compose_Expiration'), 'MMMM d, yyyy')` |
|  |  | Conditions | Switch to array input, then `body('Select_WordConditions')` |
| 13 | Create file → **Create file** (default name) | Folder Path | `outputs('Compose_FolderSiteRel')` |
|  |  | File Name | Expression F3-D |
|  |  | File Content | `body('Populate_a_Microsoft_Word_template')` |
| 14 | Update file properties → **Update file properties** (default name) | Library Name | Choose **Permit Records** |
|  |  | Id | `body('Create_file')?['ItemId']` |
|  |  | Permit Number | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | Doc Type Value | Text `Draft Permit` |
| 15 | Update item → **Update item Permit** | List Name | Choose **Permits** |
|  |  | Id | `body('Get_item_Permit')?['ID']` |
|  |  | Status Value | Text `Draft Permit` |
|  |  | Permit Expiration | Expression F3-E |
|  |  | Signature Request Id | `null` |
|  |  | Permittee Signed | `null` |
| 16 | Run a Child Flow → **Audit Document Added** | PermitNumber | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | PermitId | `body('Get_item_Permit')?['ID']` |
|  |  | EventType | Text `Document Added` |
|  |  | Detail | Expression F3-F |
|  |  | Actor | Expression F3-H |
| 17 | Respond to a Power App or flow → **Respond Done** | Text output `fileUrl` | `body('Update_file_properties')?['{Link}']` |
|  |  | Text output `message` | Text `Draft generated.` |

Expression F3-G — a date written out, or empty when the date is blank:

```
if(empty(body('Get_item_Permit')?['ProposedStart']), '', formatDateTime(body('Get_item_Permit')?['ProposedStart'], 'MMMM d, yyyy'))
```

Notes on version 2:

- Dates go into the template as text, because date picker controls are not supported. `formatDateTime` fails on a blank date, which is why expression F3-G checks first.
- Remove the `conditions` output from every response action when you move from version 1. Then refresh the flow in the app (build guide Step 6.3).
- Pick the template file from the folder browser. A file chosen by a changing path, such as `body('Get_item_Type')?['TemplateFile']`, makes the action lose its named fields (**verify**).
- The date expressions rely on `if()` evaluating only the branch it picks. **Verify** with the Proposed End test below.
- **One template per type instead:** add a **Switch** on `body('Get_item_Permit')?['PermitType']?['Value']` with one case per type. Put one Populate action in each case, renamed `Populate SpecialEvent`, `Populate Filming` and so on. After the Switch, add a Compose named **Compose DraftContent** set to `coalesce(body('Populate_SpecialEvent'), body('Populate_Filming'))`, listing all six. Use `outputs('Compose_DraftContent')` as the file content in action 13.
- The action fails if a multi-factor sign-in policy applies to the service account. See build guide Phase 0, Accounts item 2.
- *Test in your tenant:* generate a draft for a permit with no Proposed End. The run should succeed with that field empty.
- *Test in your tenant:* the new file can take about a minute before later actions can use it. If action 14 fails, add a one-minute **Delay** before it.

### Check it works

On a permit with a blank Permit Expiration, the draft shows Proposed Start plus the type's default term. The Permits item now has that date, and the AuditLog row says it was set. With Proposed Start also blank, the flow returns the "enter Proposed Start" message and creates no file.

## F4 — Signature routing

The permittee signs first, then the Superintendent. Build only the path you chose (build guide Phase 0). Each path below stands alone.

| Path | Use it when | Flows to build |
| --- | --- | --- |
| A — DocuSign | The agency licenses DocuSign. The only connector listed for GCC High and DoD | F4a and F4b |
| B — Adobe Acrobat Sign | The agency licenses Acrobat Sign. Commercial and GCC only | F4a and F4b |
| C — Signed upload and approval | No e-signature service | F4c |
| D — SharePoint eSignature | Commercial cloud, $2 per request, started by hand | None required; F4d optional |

In every path the status moves from `Draft Permit` to `Out for Permittee Signature`, then `Out for Superintendent Signature`, then `Executed`. F7b logs each change.

## F4 path A and path B — e-signature connector

F4a sends the latest draft to the service as one request with a signing order. F4b records the result. Paths A and B share every action except the ones that talk to the service.

### Licensing

The DocuSign and Adobe Acrobat Sign connectors are Standard. The service itself is licensed separately. The table below converts the draft to PDF with OneDrive actions, which are Standard. Word Online's **Convert Word Document to PDF** is Premium. F4a is started from the app, so the F3 licensing rule applies to it if you use that action.

### F4a — trigger and settings

- **Trigger:** **Power Apps (V2)** with one Number input named `PermitId`. Flow name: exactly `SUPSendForSignature`.
- After saving, set **Run only users** as described under "Rules that apply to every flow".
- Create a folder named `SUP-temp` in the service account's OneDrive.
- Each permit needs a Superintendent and an applicant email before it is sent.

### F4a — actions shared by paths A and B

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Get item → **Get item Permit** | List Name | Choose **Permits** |
|  |  | Id | Token **PermitId** |
| 3 | Compose → **Compose FolderSiteRel** | Inputs | `replace(body('Get_item_Permit')?['FolderPath'], outputs('Compose_SiteRel'), '')` |
| 4 | Get files (properties only) → **Get files Draft** | Library Name | Choose **Permit Records** |
|  |  | Filter Query | Text F4-A |
|  |  | Order By | Text `Modified desc` |
|  |  | Top Count | Text `1` |
|  |  | Limit Entries to Folder | `outputs('Compose_FolderSiteRel')` |
| 5 | Condition → **Condition Ready to send** | Left value | Expression F4-B |
|  |  | Operator and right value | **is equal to** `true` |
| 5N.1 | Respond to a Power App or flow → **Respond Not sent** | Text output `message` | Text `Not sent. Generate a draft first, or this permit is already out for signature.` |
| 5N.2 | Terminate → **Terminate Not sent** | Status | Choose **Cancelled** |
| 6 | Update item → **Update item Pending** | List Name | Choose **Permits** |
|  |  | Id | `body('Get_item_Permit')?['ID']` |
|  |  | Signature Request Id | Text `PENDING` |
|  |  | Status Value | `body('Get_item_Permit')?['Status']?['Value']` |
| 7 | Get file content → **Get file content** (default name) | File Identifier | `first(body('Get_files_Draft')?['value'])?['{Identifier}']` |
| 8 | Create file (OneDrive for Business) → **Create file OneDrive** | Folder Path | Text `/SUP-temp` |
|  |  | File Name | `concat(body('Get_item_Permit')?['PermitNumber'], '_', guid(), '.docx')` |
|  |  | File Content | `body('Get_file_content')` |
| 9 | Convert file (OneDrive for Business) → **Convert file** (default name) | File | `body('Create_file_OneDrive')?['Id']` |
|  |  | Target type | Choose **PDF** |
| 10 | Compose → **Compose PdfContent** | Inputs | `body('Convert_file')` |
| 11 | Delete file (OneDrive for Business) → **Delete file OneDrive** | File | `body('Create_file_OneDrive')?['Id']` |

Text F4-A — Filter Query for the newest Word draft:

```
startswith(FileLeafRef, '@{body('Get_item_Permit')?['PermitNumber']}_DraftPermit_v') and substringof('.docx', FileLeafRef)
```

Expression F4-B — a draft exists and no request is open:

```
and(greater(length(body('Get_files_Draft')?['value']), 0), empty(body('Get_item_Permit')?['SignatureRequestId']))
```

Notes on the shared actions:

- Action 6 marks the permit before anything is sent. A second press of the button then stops at action 5.
- If F4a fails after action 6, the permit keeps `PENDING`. Regenerate the draft to clear it, then send again.
- *Test in your tenant:* run actions 1 to 11 on a test permit and open the PDF from run history. **Convert file** works on files in the account's own OneDrive, not on SharePoint files.
- **Alternative (Premium): Word Online (Business) Convert Word Document to PDF.** Earlier versions of this sheet used it. The OneDrive actions above are Standard, so paths A and B need no Premium licence. To use the Premium action, replace actions 8, 9 and 11 with it and set **Compose PdfContent** to its output. F4a is started from the app, so every person who runs it then needs Premium, or the flow needs a Process licence (see F3 "Licensing, stated once").
- If your service accepts Word files, you can skip the conversion. Set **Compose PdfContent** to `body('Get_file_content')` and end the document name in `.docx`.

### Path A — DocuSign actions

Add these after action 11. Field labels vary by connector version, so use the labels you see. **Verify the action names in your tenant** as well.

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| A1 | Create envelope (V2) → **Create envelope** | Account | Choose the agency account |
|  |  | Email subject | `concat('Special use permit ', body('Get_item_Permit')?['PermitNumber'], ' for signature')` |
| A2 | Compose → **Compose RequestId** | Inputs | Token: the envelope ID from **Create envelope** |
| A3 | Add documents to an envelope → **Add documents to an envelope** (default name) | Envelope | `outputs('Compose_RequestId')` |
|  |  | Document name | `concat(body('Get_item_Permit')?['PermitNumber'], '_Executed.pdf')` |
|  |  | Document content | `outputs('Compose_PdfContent')` |
| A4 | Add recipient to an envelope (V2) → **Add recipient Permittee** | Envelope | `outputs('Compose_RequestId')` |
|  |  | Recipient type | Choose the signer type |
|  |  | Signer name | `body('Get_item_Permit')?['ApplicantName']` |
|  |  | Signer email | `body('Get_item_Permit')?['ApplicantEmail']` |
|  |  | Signing order | Text `1` |
| A5 | Add recipient to an envelope (V2) → **Add recipient Superintendent** | Envelope | `outputs('Compose_RequestId')` |
|  |  | Recipient type | Choose the signer type |
|  |  | Signer name | `body('Get_item_Permit')?['Superintendent']?['DisplayName']` |
|  |  | Signer email | `body('Get_item_Permit')?['Superintendent']?['Email']` |
|  |  | Signing order | Text `2` |
| A6 | Send envelope → **Send envelope** (default name) | Envelope | `outputs('Compose_RequestId')` |

Then add the closing actions below.

*Test in your tenant:* ask the DocuSign administrator how signers place their signature. Without signature fields or anchor text in the document, signers place it themselves.

### Path B — Adobe Acrobat Sign actions

Add these after action 11. Field labels vary by connector version, so use the labels you see. **Verify the action names in your tenant** as well.

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| B1 | Upload a document and get a document ID → **Upload a document** | File name | `concat(body('Get_item_Permit')?['PermitNumber'], '_Executed.pdf')` |
|  |  | File content | `outputs('Compose_PdfContent')` |
| B2 | Create an agreement from an uploaded document and send for signature → **Create agreement** | Agreement name | `concat('Special use permit ', body('Get_item_Permit')?['PermitNumber'])` |
|  |  | Document ID | Token: the document ID from **Upload a document** |
|  |  | Signature type | Choose the e-signature option |
|  |  | Participant 1 email, order and role | `body('Get_item_Permit')?['ApplicantEmail']`, order `1`, signer |
|  |  | Participant 2 email, order and role | `body('Get_item_Permit')?['Superintendent']?['Email']`, order `2`, signer |
| B3 | Compose → **Compose RequestId** | Inputs | Token: the agreement ID from **Create agreement** |

Then add the closing actions below.

*Test in your tenant:* confirm the action lets you add a second participant with **Order** 2. If it shows only one, set the signing order in an Adobe workflow and use **Create an agreement from a workflow** instead.

### F4a — closing actions for paths A and B

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 12 | Update item → **Update item Permit** | List Name | Choose **Permits** |
|  |  | Id | `body('Get_item_Permit')?['ID']` |
|  |  | Signature Request Id | `outputs('Compose_RequestId')` |
|  |  | Status Value | Text `Out for Permittee Signature` |
| 13 | Run a Child Flow → **Audit Signature Sent** | PermitNumber | `body('Get_item_Permit')?['PermitNumber']` |
|  |  | PermitId | `body('Get_item_Permit')?['ID']` |
|  |  | EventType | Text `Signature Sent` |
|  |  | Detail | Expression F4-C |
|  |  | Actor | Expression F4-D |
| 14 | Respond to a Power App or flow → **Respond Sent** | Text output `message` | Text `Sent for signature.` |

Expression F4-C — audit Detail:

```
concat('Sent to ', body('Get_item_Permit')?['ApplicantEmail'], ' then ', body('Get_item_Permit')?['Superintendent']?['Email'], '. Request ', outputs('Compose_RequestId'))
```

Expression F4-D — Actor for app-started flows:

```
base64ToString(coalesce(triggerOutputs()?['headers']?['x-ms-user-email-encoded'], base64('app user')))
```

### F4b — signature callback

F4b runs when the e-signature service reports a change. It finds the permit by its request ID. Flow name: `SUP – Signature Callback`.

- **Path A trigger:** DocuSign **When an envelope status changes (Connect) (V3)**.
- **Path B trigger:** Adobe Acrobat Sign **When an agreement workflow is completed successfully**.
- **Verify** the trigger names and the **Get signed PDF** action names (8C.1) in your tenant.
- If no usable trigger exists, a **Recurrence** every hour that polls the service's status action for each permit with a **Signature Request Id** is a fallback (**verify** the action name, for example Adobe's *Get agreement status*).

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Compose → **Compose RequestId** | Inputs | Token: the envelope ID or agreement ID from the trigger |
| 3 | Compose → **Compose EventStatus** | Inputs | Path A: Token, the envelope status from the trigger. Path B: Text `completed` |
| 4 | Compose → **Compose Today** | Inputs | `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')` |
| 5 | Get items → **Get items Permit** | List Name | Choose **Permits** |
|  |  | Filter Query | Text `SignatureRequestId eq '@{outputs('Compose_RequestId')}'` |
|  |  | Top Count | Text `1` |
| 6 | Condition → **Condition Permit found** | Left value | `length(body('Get_items_Permit')?['value'])` |
|  |  | Operator and right value | **is greater than** `0` |
| 6N.1 | Terminate → **Terminate Not ours** | Status | Choose **Succeeded** |
| 7 | Compose → **Compose FolderSiteRel** | Inputs | `replace(first(body('Get_items_Permit')?['value'])?['FolderPath'], outputs('Compose_SiteRel'), '')` |
| 8 | Switch → **Switch Status** | On | `toLower(outputs('Compose_EventStatus'))` |

Case `completed` — both people have signed:

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 8C.1 | Path A: Get documents from an envelope. Path B: Get a PDF of a signed agreement → **Get signed PDF** | Envelope or Agreement ID | `outputs('Compose_RequestId')` |
| 8C.2 | Create file → **Create file Executed** | Folder Path | `outputs('Compose_FolderSiteRel')` |
|  |  | File Name | `concat(first(body('Get_items_Permit')?['value'])?['PermitNumber'], '_Executed.pdf')` |
|  |  | File Content | `body('Get_signed_PDF')` |
| 8C.3 | Update file properties → **Update file properties Executed** | Library Name | Choose **Permit Records** |
|  |  | Id | `body('Create_file_Executed')?['ItemId']` |
|  |  | Permit Number | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
|  |  | Doc Type Value | Text `Executed Permit` |
| 8C.4 | Update item → **Update item Executed** | List Name | Choose **Permits** |
|  |  | Id | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | Permittee Signed | `coalesce(first(body('Get_items_Permit')?['value'])?['PermitteeSigned'], outputs('Compose_Today'))` |
|  |  | Superintendent Signed | `outputs('Compose_Today')` |
|  |  | Status Value | Text `Executed` |
| 8C.5 | Run a Child Flow → **Audit Signed** | PermitNumber | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Signed` |
|  |  | Detail | Text `Superintendent signed; executed permit filed` |
|  |  | Actor | Text `system` |

Case `declined` — the request was refused (path A):

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 8D.1 | Update item → **Update item Declined** | List Name | Choose **Permits** |
|  |  | Id | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | Status Value | Text `Draft Permit` |
|  |  | Signature Request Id | `null` |
|  |  | Permittee Signed | `null` |
| 8D.2 | Send an email (V2) → **Send an email (V2) Declined** | To | `first(body('Get_items_Permit')?['value'])?['Coordinator']?['Email']` |
|  |  | Subject | Text `Signature request declined: @{first(body('Get_items_Permit')?['value'])?['PermitNumber']}` |
|  |  | Body | Text `The signature request was declined or cancelled. The permit is back at Draft Permit.` |
| 8D.3 | Run a Child Flow → **Audit Declined** | PermitNumber | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Field Changed` |
|  |  | Detail | `concat('Signature request ', outputs('Compose_EventStatus'), '. Returned to Draft Permit.')` |
|  |  | Actor | Text `system` |

Add a third case, `voided`, with the same three actions. Give them names that end in `Voided`.

Clearing the two signature columns matters. While **Signature Request Id** is filled, the permit cannot be sent again.

### Recording that the permittee has signed

Between the two signatures, the status should read `Out for Superintendent Signature`. Whether a trigger fires at that moment is not confirmed for either service.

*Test in your tenant:* in a sandbox account, send a test request and have the first signer sign. Watch F4b's run history.

- **If a run starts,** add a case to **Switch Status** for the status value you see. Give it one **Update item** with **Permittee Signed** `outputs('Compose_Today')` and **Status Value** `Out for Superintendent Signature`. Add an **Audit** row with Detail `Permittee signed`.
- **Path B option:** a second small flow on **When an agreement is sent to a participant** fires when the Superintendent's turn starts. Give it the same update.
- **If nothing fires,** the coordinator sets the status and the date by hand. The service emails them when the permittee signs. Action 8C.4 fills **Permittee Signed** at completion if it is still blank.

Path B has no declined event in this design. The coordinator edits the permit and sets **Status** back to `Draft Permit`. They then generate the draft again, which clears the request.

*Test in your tenant:* check that the status values your trigger sends are `completed`, `declined` and `voided`. Use the values you see as the case names, in lower case.

## F4 path C — signed upload and approval (no e-signature service)

The permittee signs a PDF and returns it. The Superintendent then answers an approval request. F4c runs the second half.

An Approvals response records who approved and when. It is not a legal e-signature. Agency counsel should confirm whether it counts as the Superintendent's signature. If not, the Superintendent also signs the PDF before it is filed.

### What people do

1. The coordinator opens the draft in Word and selects **File → Save as → Download as PDF**.
2. The coordinator emails the PDF to the applicant from the shared mailbox. The subject line holds the permit number.
3. The coordinator sets **Status** to `Out for Permittee Signature`, in the list or with the app's button.
4. The applicant signs and replies. F8 files the reply in the permit folder.
5. The coordinator checks the signed copy. They upload a copy named `{PermitNumber}_DraftPermit_v{n}_PermitteeSigned.pdf` to the permit folder.

The upload starts F4c. Renaming a file already in the folder does not start it, so upload a copy.

### F4c — trigger and settings

- **Trigger:** SharePoint **When a file is created (properties only)**. Library: **Permit Records**. Flow name: `SUP – Signed Upload and Approval`.
- **Trigger conditions**, two rows:

```
@endsWith(triggerBody()?['{FilenameWithExtension}'], '_PermitteeSigned.pdf')
```

```
@contains(triggerBody()?['{FilenameWithExtension}'], '_DraftPermit_v')
```

The second row stops a reply that F8 filed from starting the approval before a person has checked it.

### F4c — actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Compose → **Compose PermitNumber** | Inputs | `first(split(triggerBody()?['{FilenameWithExtension}'], '_'))` |
| 3 | Get items → **Get items Permit** | List Name | Choose **Permits** |
|  |  | Filter Query | Text `PermitNumber eq '@{outputs('Compose_PermitNumber')}'` |
|  |  | Top Count | Text `1` |
| 4 | Update file properties → **Update file properties Signed** | Library Name | Choose **Permit Records** |
|  |  | Id | `triggerBody()?['ID']` |
|  |  | Permit Number | `outputs('Compose_PermitNumber')` |
|  |  | Doc Type Value | Text `Draft Permit` |
| 5 | Update item → **Update item Permittee signed** | List Name | Choose **Permits** |
|  |  | Id | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | Permittee Signed | `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')` |
|  |  | Status Value | Text `Out for Superintendent Signature` |
| 6 | Run a Child Flow → **Audit Permittee Signed** | PermitNumber | `outputs('Compose_PermitNumber')` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Signed` |
|  |  | Detail | Text `Permittee-signed copy uploaded` |
|  |  | Actor | `triggerBody()?['Author']?['Email']` |
| 7 | Start and wait for an approval → **Start and wait for an approval** (default name) | Approval type | Choose **Approve/Reject – First to respond** |
|  |  | Title | `concat('Approve and sign SUP ', outputs('Compose_PermitNumber'))` |
|  |  | Assigned to | `first(body('Get_items_Permit')?['value'])?['Superintendent']?['Email']` |
|  |  | Details | Text F4-E |
|  |  | Item link | `triggerBody()?['{Link}']` |
|  |  | Settings → Timeout | Text `P29D` |
| 8 | Condition → **Condition Approved** | Left value | `body('Start_and_wait_for_an_approval')?['outcome']` |
|  |  | Operator and right value | **is equal to** Text `Approve` |
| 8Y.1 | Get file content → **Get file content Signed** | File Identifier | `triggerBody()?['{Identifier}']` |
| 8Y.2 | Compose → **Compose FolderSiteRel** | Inputs | `replace(first(body('Get_items_Permit')?['value'])?['FolderPath'], outputs('Compose_SiteRel'), '')` |
| 8Y.3 | Create file → **Create file Executed** | Folder Path | `outputs('Compose_FolderSiteRel')` |
|  |  | File Name | `concat(outputs('Compose_PermitNumber'), '_Executed.pdf')` |
|  |  | File Content | `body('Get_file_content_Signed')` |
| 8Y.4 | Update file properties → **Update file properties Executed** | Library Name | Choose **Permit Records** |
|  |  | Id | `body('Create_file_Executed')?['ItemId']` |
|  |  | Permit Number | `outputs('Compose_PermitNumber')` |
|  |  | Doc Type Value | Text `Executed Permit` |
| 8Y.5 | Update item → **Update item Executed** | List Name | Choose **Permits** |
|  |  | Id | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | Superintendent Signed | `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')` |
|  |  | Status Value | Text `Executed` |
| 8Y.6 | Run a Child Flow → **Audit Approved** | PermitNumber | `outputs('Compose_PermitNumber')` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Signed` |
|  |  | Detail | Expression F4-F |
|  |  | Actor | `first(body('Start_and_wait_for_an_approval')?['responses'])?['responder']?['email']` |
| 8N.1 | Update item → **Update item Rejected** | List Name | Choose **Permits** |
|  |  | Id | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | Status Value | Text `Draft Permit` |
|  |  | Permittee Signed | `null` |
| 8N.2 | Send an email (V2) → **Send an email (V2) Rejected** | To | `first(body('Get_items_Permit')?['value'])?['Coordinator']?['Email']` |
|  |  | Subject | Text `Superintendent rejected @{outputs('Compose_PermitNumber')}` |
|  |  | Body | `first(body('Start_and_wait_for_an_approval')?['responses'])?['comments']` |
| 8N.3 | Run a Child Flow → **Audit Rejected** | PermitNumber | `outputs('Compose_PermitNumber')` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Field Changed` |
|  |  | Detail | `concat('Superintendent rejected: ', first(body('Start_and_wait_for_an_approval')?['responses'])?['comments'])` |
|  |  | Actor | `first(body('Start_and_wait_for_an_approval')?['responses'])?['responder']?['email']` |
| 9 | Send an email (V2) → **Send an email (V2) Timed out** | To | `first(body('Get_items_Permit')?['value'])?['Coordinator']?['Email']` |
|  |  | Subject | Text `No approval response in 29 days: @{outputs('Compose_PermitNumber')}` |
|  |  | Body | Text `The approval request expired. Upload the signed copy again to restart it.` |
|  |  | Run after | **Start and wait for an approval**: tick only **has timed out** |

Text F4-E — approval Details:

```
Permit: @{outputs('Compose_PermitNumber')}
Project: @{first(body('Get_items_Permit')?['value'])?['ProjectTitle']}
Applicant: @{first(body('Get_items_Permit')?['value'])?['ApplicantName']}
Dates: @{first(body('Get_items_Permit')?['value'])?['ProposedStart']} to @{first(body('Get_items_Permit')?['value'])?['ProposedEnd']}
Folder: @{first(body('Get_items_Permit')?['value'])?['FolderPath']}
```

Expression F4-F — audit Detail on approval:

```
concat('Approved by ', first(body('Start_and_wait_for_an_approval')?['responses'])?['responder']?['email'], ' at ', body('Start_and_wait_for_an_approval')?['completionDate'], '. Comments: ', first(body('Start_and_wait_for_an_approval')?['responses'])?['comments'])
```

Notes on path C:

- The outcome values are `Approve` and `Reject`. They are case-sensitive.
- A flow run lasts at most 30 days. The 29-day timeout lets action 9 warn the coordinator before the run ends.
- Add action 9 as a parallel branch beside action 8, so its run-after setting stands alone.
- On Reject, the permittee's signed date is cleared. The coordinator fixes the draft and starts again.
- In US Government plans, an approver must already be a user in the tenant.

## F4 path D — SharePoint eSignature

SharePoint eSignature has no Power Automate trigger or action. The coordinator starts each request by hand and records the dates. Microsoft documents it for the commercial cloud only.

1. The coordinator saves the draft as a PDF, as in path C step 1. Requests accept PDF files only.
2. In the permit folder, open the PDF and start a signature request. Microsoft's page says to select the pen icon, **Get signatures**, in the viewer. Earlier versions of this sheet named the menu item **… → Request signatures**. Use whichever your tenant shows.
3. Add the permittee first and the Superintendent second. Turn on **Recipients must sign in order**.
4. Set **Status** to `Out for Permittee Signature`.
5. When the service emails that the permittee has signed, enter **Permittee Signed** and set the status to `Out for Superintendent Signature`.
6. When the request completes, the signed copy is saved to the same folder. Enter **Superintendent Signed** and set the status to `Executed`.
7. Set the signed copy's **Doc Type** to `Executed Permit`.

External signers must be enabled as guests in Microsoft Entra. Each request costs $2, billed to an Azure subscription.

*Test in your tenant:* confirm which control starts the request, and the signed copy's file name.

### F4d — optional: record the signed copy automatically

Once the test shows how signed copies are named, F4d can do steps 6 and 7. Build it as F4c's trigger with one trigger condition that matches that file name. Then add F4c's actions 1 to 4 with **Doc Type Value** `Executed Permit`. Finish with one **Update item** that sets **Superintendent Signed** and **Status Value** `Executed`, and one **Audit** row with EventType `Signed`.

## F9 — Stamp the permit number on uploaded files

F9 writes the permit number on every file a person adds to a permit folder. The app's Documents screen finds files by that number, so without F9 it misses hand-uploaded files. Build it with the app (delivery stage 5, build guide Phase 6).

### Trigger and settings

- **Trigger:** SharePoint **When a file is created (properties only)**. Library: **Permit Records**. Flow name: `SUP – Stamp Permit Number`.
- **Trigger conditions**, two rows:

```
@equals(triggerBody()?['{IsFolder}'], false)
```

```
@empty(triggerBody()?['PermitNumber'])
```

### Actions

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Delay → **Delay** (default name) | Count and unit | `2`, **Minute** |
| 2 | Get file properties → **Get file properties Fresh** | Library Name | Choose **Permit Records** |
|  |  | Id | `triggerBody()?['ID']` |
| 3 | Compose → **Compose PermitNumber** | Inputs | `first(split(last(split(triggerBody()?['{Path}'], ' Projects/')), '_'))` |
| 4 | Get items → **Get items Permit** | List Name | Choose **Permits** |
|  |  | Filter Query | Text `PermitNumber eq '@{replace(outputs('Compose_PermitNumber'), '''', '''''')}'` |
|  |  | Top Count | Text `1` |
| 5 | Condition → **Condition Stamp needed** | Left value | Expression F9-A |
|  |  | Operator and right value | **is equal to** `true` |
| 5Y.1 | Update file properties → **Update file properties** (default name) | Library Name | Choose **Permit Records** |
|  |  | Id | `triggerBody()?['ID']` |
|  |  | Permit Number | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
| 5Y.2 | Run a Child Flow → **Audit Document Added** | PermitNumber | `first(body('Get_items_Permit')?['value'])?['PermitNumber']` |
|  |  | PermitId | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | EventType | Text `Document Added` |
|  |  | Detail | `concat('File added: ', triggerBody()?['{FilenameWithExtension}'])` |
|  |  | Actor | `triggerBody()?['Author']?['Email']` |

Expression F9-A — the file still has no number and its folder belongs to a permit:

```
and(empty(body('Get_file_properties_Fresh')?['PermitNumber']), greater(length(body('Get_items_Permit')?['value']), 0))
```

### Notes

- The permit number is the start of the permit folder's name. Action 3 reads it from the file's path.
- Files that F3, F4 or F8 create are stamped by those flows. The two-minute delay and the fresh read in action 2 let F9 skip them.
- A file outside a permit folder, such as a template, matches no permit and is left alone.
- F9 does not set **Doc Type**. The person who uploads the file sets it.
- *Test in your tenant:* upload a file to a permit folder and check `{Path}` in run history. It should read like `PermitRecords/Open Projects/SUP-2026-0042_Name_Place/`.

## F10 — Migration folder match (run once)

F10 matches each folder to its permit by the number at the start of the folder's name. Delete the flow after the migration.

- **Trigger:** **Manually trigger a flow**, with no inputs. Flow name: `SUP – Migration Folder Match`.

| # | Action (rename to) | Field | Value |
| --- | --- | --- | --- |
| 1 | Compose → **Compose SiteRel** | Inputs | Text `/sites/SpecialUsePermits` |
| 2 | Compose → **Compose TenantRoot** | Inputs | Text `https://<tenant>.sharepoint.com` |
| 3 | Apply to each → **Apply to each Top** | Select an output from previous steps | `createArray('Open Projects', 'Closed Projects')` |
| 3.1 | Get files (properties only) → **Get files Folders** | Library Name | Choose **Permit Records** |
|  |  | Filter Query | Text `FSObjType eq 1` |
|  |  | Limit Entries to Folder | `concat('/PermitRecords/', items('Apply_to_each_Top'))` |
|  |  | Include Nested Items | Choose **No** |
|  |  | Top Count | Text `5000` |
| 3.2 | Apply to each → **Apply to each Folder** | Select an output from previous steps | `body('Get_files_Folders')?['value']` |
| 3.2.1 | Compose → **Compose LegacyNumber** | Inputs | `first(split(items('Apply_to_each_Folder')?['{FilenameWithExtension}'], '_'))` |
| 3.2.2 | Get items → **Get items Permit** | List Name | Choose **Permits** |
|  |  | Filter Query | Text `PermitNumber eq '@{replace(outputs('Compose_LegacyNumber'), '''', '''''')}'` |
|  |  | Top Count | Text `1` |
| 3.2.3 | Condition → **Condition Needs path** | Left value | Expression F10-A |
|  |  | Operator and right value | **is equal to** `true` |
| 3.2.3Y.1 | Compose → **Compose FolderPath** | Inputs | Expression F10-B |
| 3.2.3Y.2 | Update item → **Update item Permit** | List Name | Choose **Permits** |
|  |  | Id | `first(body('Get_items_Permit')?['value'])?['ID']` |
|  |  | Folder Path | `outputs('Compose_FolderPath')` |
|  |  | Folder | `concat(outputs('Compose_TenantRoot'), replace(outputs('Compose_FolderPath'), ' ', '%20'))` |
|  |  | Status Value | `first(body('Get_items_Permit')?['value'])?['Status']?['Value']` |

Expression F10-A — a permit matches and has no folder path yet:

```
and(greater(length(body('Get_items_Permit')?['value']), 0), empty(first(body('Get_items_Permit')?['value'])?['FolderPath']))
```

Expression F10-B — Compose FolderPath:

```
concat(outputs('Compose_SiteRel'), '/PermitRecords/', items('Apply_to_each_Top'), '/', items('Apply_to_each_Folder')?['{FilenameWithExtension}'])
```

After the run, sort the Permits list by **Folder Path** and look for blanks. A blank means no folder name started with that permit's number.

A closed permit whose folder you placed under Open Projects is moved by flow F5 as soon as F10 fills its path. That is the intended result.

### Migration notes

F10 is step 9 of the migration in build guide Step 9.3. The notes from that step that affect F10, F1b and F9:

Do not switch F1b off during the import. A SharePoint trigger remembers what it missed. When the flow is switched back on, it would number every imported permit again and create a second folder for each.

The setup script cannot import your tracker. It loads only `Permits-sample.csv`.

*Test in your tenant:* paste five rows first. Check that the lookup, person and multi-choice columns arrive correctly before pasting the rest.

Legacy numbers must not contain an underscore, because F10 reads the number as the text before the first underscore.

Flow F9 stamps the permit number on every moved file, about three actions per file. A standard licence allows a limited number of actions a day. Move a few hundred files at a time if you have thousands.

## Summary

| ID | Trigger | Connectors | Premium? |
| --- | --- | --- | --- |
| F7a | Manually trigger a flow (child flow) | SharePoint | No (must be in a solution) |
| F1b | SharePoint: item created (concurrency 1, trigger condition) | SharePoint, Outlook | No |
| F1a | Forms: new response | Forms, SharePoint | No |
| F7b | SharePoint: item or file modified | SharePoint (including Send an HTTP request to SharePoint) | No |
| F5 | SharePoint: item or file modified (concurrency 1, trigger condition) | SharePoint, Outlook | No |
| F6 | Recurrence, daily at 7:00 | SharePoint, Outlook | No |
| F8 | Outlook: new email in a shared mailbox (V2) | Outlook, SharePoint | No |
| F2a | SharePoint: item or file modified (trigger condition, then Get changes) | SharePoint | No |
| F2b | Power Apps (V2) | SharePoint | No |
| F3 | Power Apps (V2) | SharePoint; version 2 adds **Word Online (Business)** | Version 1: No. Version 2: **Yes**, per person who runs it or a Process licence |
| F4a | Power Apps (V2) | SharePoint, OneDrive for Business, DocuSign or Adobe Acrobat Sign | No. **Yes** only with the alternative Word Online PDF step |
| F4b | DocuSign or Adobe Acrobat Sign event | SharePoint, Outlook, DocuSign or Adobe Acrobat Sign | No (the service is licensed separately) |
| F4c | SharePoint: file created (two trigger conditions) | SharePoint, Approvals, Outlook | No |
| F4d | SharePoint: file created (optional) | SharePoint | No |
| F9 | SharePoint: file created (two trigger conditions) | SharePoint | No |
| F10 | Manually trigger a flow (run once, not counted) | SharePoint | No |
