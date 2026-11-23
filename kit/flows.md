# Power Automate build sheets: SUP flows F1–F7

> **UNTESTED against a live tenant.** These are hand-build instructions, not importable packages. Build and test in a test site first. Wherever this page says **verify**, the author could not confirm the exact action name, field or output shape. Check it in the designer and in run history before relying on it.

## Conventions used in every flow

- **Rename actions exactly as written.** Expressions refer to actions by name with spaces turned into underscores. The action `Get item Permit` is referenced as `body('Get_item_Permit')`.
- **Site Address:** `https://<tenant>.sharepoint.com/sites/SpecialUsePermits`, or your test alias such as `/sites/SUP-Test`.
- **Never hard-code the site path in expressions.** Every flow that builds paths (F1b, F3 and F5) starts with two Compose actions. Better still, create solution environment variables and point these Composes at them, so test and production differ only by environment variable:
  - **Compose SiteRel:** `/sites/SpecialUsePermits`
  - **Compose TenantRoot:** `https://<tenant>.sharepoint.com`
- **List names:** use the display names in the dropdowns: `Permits`, `Settings`, and so on. The library's display name is `Permit Records` and its URL is `PermitRecords`.
- **Connection account:** use one service account (a licensed, non-personal mailbox user) for all SharePoint, Outlook and Approvals connections. Put it in **SUP Owners**. AuditLog is owners-only for edits, and moving folders needs edit rights on both top folders.
- **Store flows in a solution.** Child flows (F7a) only work in solution-aware flows. Put environment variables `SiteUrl` and `TimeZone` in the solution if you want portability.
- **Time zone:** where a local date matters, these sheets use `'Eastern Standard Time'`. Replace it with your Windows time-zone ID. Set the same zone in Site settings → Regional settings.
- **Choice and person columns.** The SharePoint connector returns a single choice as `{ "Value": "..." }`, so you read `?['Status']?['Value']`. A multi-choice comes back as an array of `{ "Value": ... }`. A lookup returns `{ "Id", "Value" }`, and a person returns `{ "Email", "DisplayName", "Claims", ... }`. **Verify these shapes in run history before trusting the expressions.**
- **Licensing:** every action in these sheets is **Standard** (Microsoft 365 licence) **except** where marked **PREMIUM**.

### Loop prevention (read this before building)
F1, F2, F4, F5 and F6 all update Permits items, and F2, F5 and F7b trigger on Permits *modified*. Each modified-trigger flow has a **trigger condition** (Settings → Trigger conditions) so that it fires only on the change it cares about:

| Flow | Guard |
|---|---|
| F2 | Uses `Get changes`: proceeds only if `Status` changed **and** it is now `Under Review` |
| F5 | Fires only when Status is closed **and** the folder is not yet in `/Closed Projects/` |
| F7b | Uses `Get changes`: logs only when `Status` changed. It writes only to AuditLog, so it cannot loop. |

---

## F7a: "SUP – Write Audit" (child flow)
**Build this first, because the other flows call it.**

**Trigger:** Manually trigger a flow (Standard). Add these inputs:

| Input | Type |
|---|---|
| `PermitNumber` | Text |
| `PermitId` | Number |
| `EventType` | Text (must be one of the AuditLog choices) |
| `Detail` | Text |
| `Actor` | Text (email) |

**Actions:**
1. **Create item** (SharePoint) → list `AuditLog`
   - Title: `triggerBody()['text']`. Use the token for PermitNumber; the designer names inputs `text`, `number`, `text_1` and so on, so **verify the key names**.
   - PermitId: PermitId token
   - EventType Value: EventType token
   - Detail: Detail token
   - Actor: `if(empty(<Actor token>), 'system', <Actor token>)`
   - EventTime: `utcNow()`
2. **Respond to a PowerApp or flow**, with output `ok` = `true`. Without this response, the parent waits until it times out.

**Settings:** on the flow's details page, open **Run only users** and set each connection to **"Use this connection"** (embedded). Child flows cannot use the caller's connection.

**Non-solution fallback.** If you do not use a solution, paste a **Create item → AuditLog** action wherever the sheets below say **AUDIT(...)**, with the same five fields and `EventTime = utcNow()`.

Notation used below: **AUDIT(EventType, Detail)** means "Run a Child Flow → SUP – Write Audit" with PermitNumber, PermitId, EventType, Detail and Actor filled from the current permit.

---

## F1: New Application → number, folder, notify
Two flows keep one numbering code path. **F1a** turns a Forms response into a Permits item, and **F1b** numbers every new Permits item, whether it came from the form, the app or a manual entry.

### F1a: Form → Permits item (optional; use only if you take applications through Microsoft Forms)

**Trigger:** Microsoft Forms, *When a new response is submitted* (Standard).

**Actions:**
1. **Get response details**
   - Form Id: same form
   - Response Id: `triggerOutputs()?['body/resourceData/responseId']`
2. **Get items Existing** (Permits). This skips duplicates if the response is replayed.
   - Filter Query: `SourceSubmissionId eq '@{triggerOutputs()?['body/resourceData/responseId']}'`
   - Top Count: `1`
3. **Condition:** `length(body('Get_items_Existing')?['value'])` *is equal to* `0`. Put the rest of this flow in the **If yes** branch.
4. **Select Impacts** turns the form's multi-select answer into the multi-choice array.
   - From: `json(body('Get_response_details')?['<impactsQuestionId>'])`. Forms returns multi-select answers as a JSON array string; **verify** this in run history.
   - Map (switch to text mode): key `Value`, value `item()`
5. **Create item** (Permits)
   - Set Applicant*, Project*, Location, ProposedStart and ProposedEnd from the form answers.
   - `ReceivedDate`: `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')`
   - `SourceSubmissionId`: the responseId expression above
   - `Status Value`: `Received`
   - `Impacts`: click **"Switch to input entire array"** and enter `body('Select_Impacts')`
   - `PermitType Id`: map the form's type question to the PermitTypes item Id, with a Switch or a small `Get items PermitTypes` filtered by `Title eq '<answer>'`.

F1b then fires on the new item.

### F1b: Number, folder, notify

**Trigger:** SharePoint, *When an item is created* (list `Permits`).

**Settings → Concurrency control: On, Degree of parallelism = 1.**

Why: the sequence number is a read-modify-write on the `NextSeq_{year}` row in Settings. SharePoint has no atomic increment. Two runs in parallel would both read `42` and issue `SUP-2026-0042` twice. Running one at a time serializes the allocation.

- Turning concurrency control on cannot be undone; you would have to recreate the trigger.
- The unique index on `PermitNumber` is a second safety net: a duplicate makes the Update fail instead of saving silently.

**Actions:**

0. **Compose SiteRel** and **Compose TenantRoot** (see Conventions).
1. **Initialize variable** `varSeq` (Integer) = `0`
2. **Initialize variable** `varSettingsId` (Integer) = `0`
3. **Compose Year**
   ```
   formatDateTime(coalesce(triggerBody()?['ReceivedDate'], convertFromUtc(utcNow(), 'Eastern Standard Time')), 'yyyy')
   ```
4. **Get items Settings** (Settings)
   - Filter Query: `Title eq 'NextSeq_@{outputs('Compose_Year')}'`
   - Top Count: `1`
5. **Condition Seq row exists:** `length(body('Get_items_Settings')?['value'])` *is greater than* `0`
   - **If yes:**
     - Set variable `varSeq` = `int(first(body('Get_items_Settings')?['value'])?['Value'])`
     - **Update item Settings** (Settings)
       - Id: `first(body('Get_items_Settings')?['value'])?['ID']`
       - Title: `concat('NextSeq_', outputs('Compose_Year'))`
       - Value: `string(add(variables('varSeq'), 1))`
   - **If no** (first application of a new year, when the row is missing):
     - Set variable `varSeq` = `1`
     - **Create item** (Settings)
       - Title: `concat('NextSeq_', outputs('Compose_Year'))`
       - Value: `2`
6. **Compose PermitNumber**
   ```
   concat('SUP-', outputs('Compose_Year'), '-', formatNumber(variables('varSeq'), '0000'))
   ```
7. **Compose ApplicantRaw**
   ```
   if(empty(triggerBody()?['ApplicantOrg']), triggerBody()?['ApplicantName'], triggerBody()?['ApplicantOrg'])
   ```
8. **Compose ApplicantShort** strips `~ " # % & * : < > ? / \ { | }` and spaces, then caps the result at 30 characters:
   ```
   take(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(coalesce(outputs('Compose_ApplicantRaw'), 'Applicant'), '~', ''), '"', ''), '#', ''), '%', ''), '&', ''), '*', ''), ':', ''), '<', ''), '>', ''), '?', ''), '/', ''), '\', ''), '{', ''), '|', ''), '}', ''), ' ', ''), 30)
   ```
9. **Compose LocationShort:** the same expression with `coalesce(triggerBody()?['LocationName'], 'Location')` as the innermost argument.
10. **Compose FolderName**
    ```
    concat(outputs('Compose_PermitNumber'), '_', outputs('Compose_ApplicantShort'), '_', outputs('Compose_LocationShort'))
    ```
    SharePoint also rejects names that start or end with `.` or contain `..`. If applicants can type those, wrap the result in `trim(replace(..., '..', ''))`.
11. **Create new folder** (SharePoint)
    - List or Library: `Permit Records`
    - Folder Path: `Open Projects/@{outputs('Compose_FolderName')}`
12. **Compose FolderPath** (server-relative, as stored in Permits.FolderPath)
    ```
    concat(outputs('Compose_SiteRel'), '/PermitRecords/Open Projects/', outputs('Compose_FolderName'))
    ```
13. **Update item Permit** (Permits)
    - Id: `triggerBody()?['ID']`
    - Title: `outputs('Compose_PermitNumber')`
    - PermitNumber: `outputs('Compose_PermitNumber')`
    - FolderUrl: `body('Create_new_folder')?['{Link}']`. **Verify:** if `{Link}` is empty, use `concat(outputs('Compose_TenantRoot'), replace(outputs('Compose_FolderPath'), ' ', '%20'))`. The Update item action only sets the hyperlink URL, not its description.
    - FolderPath: `outputs('Compose_FolderPath')`
    - ReceivedDate: `coalesce(triggerBody()?['ReceivedDate'], formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd'))`
    - Status Value: `coalesce(triggerBody()?['Status']?['Value'], 'Received')`
14. **AUDIT(Created, ...)** with Detail:
    ```
    concat('Permit ', outputs('Compose_PermitNumber'), ' created. Folder: ', outputs('Compose_FolderPath'))
    ```
    Actor: `triggerBody()?['Author']?['Email']`
15. **Get items Mailbox** (Settings): Filter Query `Title eq 'ProgramMailbox'`, Top Count `1`
16. **Send an email (V2)** (Office 365 Outlook). Alternatively use *Send an email from a shared mailbox (V2)* with the ProgramMailbox value.
    - To:
      ```
      if(empty(triggerBody()?['Coordinator']?['Email']), first(body('Get_items_Mailbox')?['value'])?['Value'], triggerBody()?['Coordinator']?['Email'])
      ```
    - Subject: `New SUP application @{outputs('Compose_PermitNumber')}: @{triggerBody()?['ProjectTitle']}`
    - Body (HTML): applicant, type `triggerBody()?['PermitType']?['Value']`, dates, a link to the item (`triggerBody()?['{Link}']`) and the folder link.

---

## F2: Suggest Conditions

**Trigger option A:** SharePoint, *When an item or a file is modified* (Permits).

Trigger condition:
```
@equals(triggerBody()?['Status']?['Value'], 'Under Review')
```
Then add:
- **Get changes for an item or a file (properties only)**
  - Id: `triggerBody()?['ID']`
  - Since: `triggerOutputs()?['body/{TriggerWindowStartToken}']`
- **Condition:** `body('Get_changes_for_an_item_or_a_file_(properties_only)')?['ColumnHasChanged']?['Status']` *is equal to* `true`. Rename the action to `Get changes` and the reference becomes `body('Get_changes')`. If the condition is false, terminate with **Succeeded**.

**Trigger option B (button from the app):** Power Apps (V2), with input `PermitId` (Number). The app calls `SUPSuggestConditions.Run(ThisItem.ID)`. Option B can run at any status.

**Actions** (`PermitId` is `triggerBody()?['ID']` for option A or the Power Apps input for option B):

1. **Get item Permit** (Permits): Id = PermitId
2. **Compose PermitTypeId:** `body('Get_item_Permit')?['PermitType']?['Id']`
3. **Select PermitImpacts** turns the permit's multi-choice into a plain string array.
   - From: `coalesce(body('Get_item_Permit')?['Impacts'], json('[]'))`
   - Map (text mode): `item()?['Value']`
4. **Get items Library** (ConditionLibrary)
   - Filter Query: `Active eq 1`
   - Order By: `SortOrder asc`
   - Top Count: `500`
   - The Filter Query has no OData on `TriggerImpacts` or `AppliesToTypes`. SharePoint OData cannot filter multi-choice or multi-lookup columns reliably, so that filtering happens in the flow.
5. **Get items Existing** (PermitConditions)
   - Filter Query: `PermitId eq @{body('Get_item_Permit')?['ID']}`. This is the lookup's Id field; **verify**. If it is rejected, try `Permit/Id eq ...`.
   - Top Count: `500`
6. **Select ExistingConditionIds**
   - From: `body('Get_items_Existing')?['value']`
   - Map (text mode): `item()?['Condition']?['Id']`
7. **Initialize variable** `varAdded` (Integer) = `0`. Add it at top level, before the loop.
8. **Apply to each Condition** over `body('Get_items_Library')?['value']`. Set Concurrency to 1, which is optional but keeps SortOrder inserts predictable.
   1. **Select TypeIds**
      - From: `coalesce(items('Apply_to_each_Condition')?['AppliesToTypes'], json('[]'))`
      - Map (text mode): `item()?['Id']`
   2. **Select TriggerValues**
      - From: `coalesce(items('Apply_to_each_Condition')?['TriggerImpacts'], json('[]'))`
      - Map (text mode): `item()?['Value']`
   3. **Compose Match** applies the spec rule: Active (already filtered) AND (AppliesToTypes empty OR contains the permit's type) AND (AlwaysInclude OR TriggerImpacts ∩ Impacts ≠ ∅).
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
      The last line skips duplicates: a condition already on the permit, whether suggested or added by staff, is never added twice. Both sides of `intersection` are plain arrays of the same type, ints for type Ids and strings for impact values. If `Compose_PermitTypeId` comes back as a string, wrap it in `int(...)`.
   4. **Condition:** `outputs('Compose_Match')` *is equal to* `true`
      - **If yes:**
        - **Create item** (PermitConditions):
          - Title: `items('Apply_to_each_Condition')?['ConditionCode']`
          - Permit Id: `body('Get_item_Permit')?['ID']`
          - Condition Id: `items('Apply_to_each_Condition')?['ID']`
          - ConditionText: `items('Apply_to_each_Condition')?['ConditionText']`
          - Source Value: `Suggested`
          - Included: `true`
          - SortOrder: `items('Apply_to_each_Condition')?['SortOrder']`
        - **Increment variable** `varAdded` by 1
9. **AUDIT(Field Changed, ...)** with Detail: `concat(variables('varAdded'), ' condition(s) suggested from library')`
10. *(Option B only)* **Respond to a PowerApp or flow**, with output `added` = `variables('varAdded')`

---

## F3: Generate Draft Permit

**Trigger:** Power Apps (V2), with input `PermitId` (Number). Alternatively use SharePoint *For a selected item* on Permits.

### Primary path: Word template, PREMIUM
*Populate a Microsoft Word template* is in the Word Online (Business) connector and is **PREMIUM** (it needs Power Automate Premium or a per-flow licence).

**Template preparation.** Each `.docx` in `Permit Records/_Templates` needs:
- Plain-text content controls tagged `PermitNumber`, `ApplicantName`, `ApplicantOrg`, `ProjectTitle`, `LocationName`, `ProposedStart`, `ProposedEnd`, `PermitExpiration` and `PermitTypeName`.
- A **Repeating Section** content control tagged `Conditions`, containing plain-text controls `ConditionCode` and `ConditionText`. Use Word's numbered-list style for numbering.

**Actions:**
0. **Compose SiteRel** (see Conventions).
1. **Get item Permit** (Permits): Id = PermitId
2. **Get item Type** (PermitTypes): Id = `body('Get_item_Permit')?['PermitType']?['Id']`
3. **Get items Conditions** (PermitConditions)
   - Filter Query: `PermitId eq @{body('Get_item_Permit')?['ID']} and Included eq 1`
   - Order By: `SortOrder asc`
   - Top Count: `500`
4. **Select WordConditions**
   - From: `body('Get_items_Conditions')?['value']`
   - Map:
     - `ConditionCode`: `item()?['Title']`
     - `ConditionText`: `item()?['ConditionText']`
5. **Compose FolderSiteRel** (path relative to the site, as SharePoint actions expect)
   ```
   replace(body('Get_item_Permit')?['FolderPath'], outputs('Compose_SiteRel'), '')
   ```
6. **Get files Drafts.** Use *Get files (properties only)* on Permit Records.
   - Filter Query: `startswith(FileLeafRef, '@{body('Get_item_Permit')?['PermitNumber']}_DraftPermit_v')`
   - Limit Entries to Folder: `outputs('Compose_FolderSiteRel')`. **Verify** that this parameter accepts a library-relative path.
7. **Compose Version:** `add(length(body('Get_files_Drafts')?['value']), 1)`
8. **Populate a Microsoft Word template** — **PREMIUM**
   - Location: the site
   - Document Library: `Permit Records`
   - File: pick the template.
   - **Limitation, verify:** when *File* is a dynamic path (for example `body('Get_item_Type')?['TemplateFile']`), the designer cannot read the template at design time. It then shows no named fields to map.
   - **Recommended:**
     - Use **one master template**, with `PermitTypeName` as a field and type-specific text kept in the condition library.
     - Or use a **Switch** on `body('Get_item_Permit')?['PermitType']?['Value']` with one Populate action per template, each with a static file. That is six branches.
   - Map the plain fields from `Get_item_Permit`. For dates, use `formatDateTime(body('Get_item_Permit')?['PermitExpiration'], 'MMMM d, yyyy')`.
   - Conditions (repeating section): switch to array input and enter `body('Select_WordConditions')`.
9. **Create file** (SharePoint)
   - Folder Path: `outputs('Compose_FolderSiteRel')`
   - File Name: `concat(body('Get_item_Permit')?['PermitNumber'], '_DraftPermit_v', outputs('Compose_Version'), '.docx')`
   - File Content: `body('Populate_a_Microsoft_Word_template')`
10. **Update file properties** (Permit Records)
    - Id: `body('Create_file')?['ItemId']`
    - PermitNumber: the permit number
    - DocType Value: `Draft Permit`
11. **Update item Permit** (Permits): Id = PermitId, Status Value = `Draft Permit`. F7b logs the status change.
12. **AUDIT(Document Added, ...)** with Detail: `concat('Draft permit generated: ', body('Create_file')?['Name'])`
13. **Respond to a PowerApp or flow**, with output `fileUrl` = `body('Create_file')?['{Link}']` (**verify** this output name).

### Standard-licence fallback (no Premium)
There is no Standard action that fills a Word template, so the fallback combines document properties with copy and paste:

1. Put the template on the Permit Records library as the content-type template (Library settings → Advanced → Document template), or keep it in `_Templates`.
2. In the template, use **Insert → Quick Parts → Document Property → Permit Number** (and Doc Type). These bind only to columns *of the library the document lives in*. To show applicant, location or dates this way, you must add matching library columns, which the spec does not define, and have the flow fill them with *Update file properties*.
3. **Flow:**
   1. **Copy file** copies `_Templates/<template>` to the permit folder.
   2. Rename the file to `{PermitNumber}_DraftPermit_v{n}.docx`. Use *Move file* with a new name, or *Send an HTTP request to SharePoint* `MoveTo`; **verify**.
   3. **Update file properties** sets PermitNumber and DocType to Draft Permit. The Quick Parts then show the values when the document opens in Word.
4. **Conditions** cannot be generated into the document on Standard. Instead:
   1. The flow builds a numbered plain-text block: `join(body('Select_ConditionLines'), decodeUriComponent('%0D%0A%0D%0A'))`, where `Select_ConditionLines` maps `concat(item()?['Title'], '  ', item()?['ConditionText'])`.
   2. The flow returns it to the app, which shows a **Copy** button (`Copy()` function).
   3. The coordinator pastes it into the Conditions section of the document.

This gives a correct, auditable draft, but it involves one manual paste per permit.

---

## F4: Signature routing

### F4 primary: e-signature provider
Write the flow against your chosen provider. Choose between:

- **SharePoint eSignature** (Microsoft Syntex pay-as-you-go).
  - At the time of writing, requests are started from the document in SharePoint (… → *Request signatures*).
  - **Verify** whether your tenant has a Power Automate action or trigger for it. If not, the coordinator starts the request manually, and F4 starts at step 4 (signed file arrives in the library).
  - **Verify** that it supports sequential signer order and external signers.
- **Adobe Acrobat Sign** connector.
  - Needs an Acrobat Sign licence. Check the connector tier (Standard or Premium) on its Learn connector page.
  - **Verify action names.** The author believes they include *Upload a document and get a document ID* and *Create an agreement from an uploaded document and send for signature*, plus trigger *When an agreement workflow is completed successfully*.

**F4a Send:** trigger is Power Apps (V2) with `PermitId`.
1. **Get item Permit**
2. **Get file content** of the latest `_DraftPermit_v{n}`. Use *Get files (properties only)* in the permit folder, ordered `Modified desc`, Top 1, then *Get file content*.
3. **Convert to PDF** if your provider needs it. Word Online (Business) has *Convert Word Document to PDF*; **verify** its tier and name.
4. **Send for signature** (provider action; **verify action name**)
   - Signer order 1: `body('Get_item_Permit')?['ApplicantEmail']`
   - Signer order 2: `body('Get_item_Permit')?['Superintendent']?['Email']`
   - Document name: `concat(<PermitNumber>, '_Executed.pdf')`
   - Signing order: **sequential**
5. **Update item Permit**
   - SignatureRequestId: the provider's agreement or envelope id output
   - Status Value: `Out for Permittee Signature`
6. **AUDIT(Signature Sent, ...)** with Detail: `concat('Sent to ', <ApplicantEmail>, ' then ', <SuperintendentEmail>, '. Request ', <id>)`

**F4b Status callback:** trigger is the provider's "participant signed" or "agreement completed" event, or a Recurrence every 1 hour that polls *Get agreement status* (**verify**).
1. **Get items Permit** (Permits): Filter Query `SignatureRequestId eq '<id from trigger>'`, Top 1
2. **Switch** on provider status:
   - **Permittee signed:**
     - Update PermitteeSigned = `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')`
     - Status = `Out for Superintendent Signature`
     - AUDIT(Signed, `'Permittee signed'`)
   - **Completed:**
     - Update SuperintendentSigned (same date expression)
     - Status = `Executed`
     - Get the signed PDF from the provider
     - Create file `{PermitNumber}_Executed.pdf` in the folder
     - Update file properties: DocType = `Executed Permit`
     - AUDIT(Signed, `'Superintendent signed; executed permit filed'`)
   - **Declined or cancelled:** Status = `Draft Permit`, email the coordinator, AUDIT(Field Changed, reason)

### F4 Standard fallback: signed upload plus Approvals
**Approvals is not a legal e-signature.** It records an auditable approve or reject decision (who, when, comments). Confirm with counsel whether a recorded approval satisfies the superintendent signature, or whether the superintendent must also sign the PDF (for example by hand, or with the Adobe Reader *Fill & Sign* tool) before upload.

**Process:**
1. The coordinator emails the draft PDF to the applicant.
2. The applicant signs and returns it.
3. The coordinator uploads it to the permit folder as `{PermitNumber}_DraftPermit_v{n}_PermitteeSigned.pdf`. This name follows the convention's DocType plus qualifier.

**Trigger:** SharePoint, *When a file is created (properties only)* on Permit Records.

Trigger condition:
```
@endsWith(triggerBody()?['{FilenameWithExtension}'], '_PermitteeSigned.pdf')
```

**Actions:**
1. **Compose PermitNumber:** `first(split(triggerBody()?['{FilenameWithExtension}'], '_'))`
2. **Get items Permit** (Permits): Filter Query `PermitNumber eq '@{outputs('Compose_PermitNumber')}'`, Top 1. Below, `P` means `first(body('Get_items_Permit')?['value'])`.
3. **Update file properties** on the uploaded file: PermitNumber, DocType = `Draft Permit`
4. **Update item Permit**
   - Id: `P?['ID']`
   - PermitteeSigned: `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')`
   - Status Value: `Out for Superintendent Signature`
5. **AUDIT(Signed, ...)** with Detail `'Permittee-signed copy uploaded'` and Actor `triggerBody()?['Author']?['Email']`
6. **Start and wait for an approval** (Approvals, Standard)
   - Type: *Approve/Reject – First to respond*
   - Assigned to: `P?['Superintendent']?['Email']`
   - Title: `concat('Approve and sign SUP ', outputs('Compose_PermitNumber'))`
   - Item link: `triggerBody()?['{Link}']`
   - Details: project, applicant, dates, and the link to the folder

   A flow run lasts at most 30 days. If no response arrives, the run times out; add a reminder or escalation branch with *Configure run after → has timed out*.
7. **Condition:** `body('Start_and_wait_for_an_approval')?['outcome']` *is equal to* `Approve`
   - **Yes:**
     1. **Copy file** to the same folder, then rename it to `{PermitNumber}_Executed.pdf`; or *Create file* with *Get file content*.
     2. **Update file properties** of the new file: DocType = `Executed Permit`
     3. **Update item Permit:** SuperintendentSigned = today, Status = `Executed`
     4. **AUDIT(Signed, ...)** with Detail
        ```
        concat('Approved by ', first(body('Start_and_wait_for_an_approval')?['responses'])?['responder']?['email'], ' at ', body('Start_and_wait_for_an_approval')?['completionDate'], '. Comments: ', first(body('Start_and_wait_for_an_approval')?['responses'])?['comments'])
        ```
   - **No:** Update Status = `Draft Permit`; email the coordinator with the comments; AUDIT(Field Changed, `'Superintendent rejected: ' + comments`)

---

## F5: Close Permit, moving the folder to Closed Projects

**Trigger:** SharePoint, *When an item or a file is modified* (Permits).

Trigger condition (enter on one line):
```
@and(contains(createArray('Closed','Withdrawn','Denied'), triggerBody()?['Status']?['Value']), not(empty(triggerBody()?['FolderPath'])), not(contains(triggerBody()?['FolderPath'], '/Closed Projects/')))
```
The flow's own update moves the folder path into `/Closed Projects/`, so the flow cannot retrigger itself.

**Actions:**
0. **Compose SiteRel** and **Compose TenantRoot** (see Conventions).
1. **Compose FolderSiteRel:** `replace(triggerBody()?['FolderPath'], outputs('Compose_SiteRel'), '')`. This gives `/PermitRecords/Open Projects/SUP-…`.
2. **Move folder** (SharePoint, Standard)
   - Current Site Address: the site
   - Folder to Move: `outputs('Compose_FolderSiteRel')`
   - Destination Site Address: the site
   - Destination Folder: `/PermitRecords/Closed Projects`
   - If another folder is already there: *Fail this action*
   - **Verify** the option labels, and whether the folder pickers want a library-relative or site-relative path.
3. **Compose NewFolderPath**
   ```
   replace(triggerBody()?['FolderPath'], '/PermitRecords/Open Projects/', '/PermitRecords/Closed Projects/')
   ```
4. **Update item Permit** (Permits)
   - Id: `triggerBody()?['ID']`
   - FolderPath: `outputs('Compose_NewFolderPath')`
   - FolderUrl: `concat(outputs('Compose_TenantRoot'), replace(outputs('Compose_NewFolderPath'), ' ', '%20'))`. Or use `body('Move_folder')?['{Link}']` if present; **verify**.
   - ClosedDate:
     ```
     coalesce(triggerBody()?['ClosedDate'], formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd'))
     ```
   - Status Value: `triggerBody()?['Status']?['Value']`. Re-send the status so the Update does not blank it.
5. **AUDIT(Moved to Closed, ...)** with Detail: `concat('Status ', triggerBody()?['Status']?['Value'], '. Folder moved to ', outputs('Compose_NewFolderPath'))`

**Notes:**
- Sharing links and the item IDs of the files survive the move. Bookmarked folder URLs do not.
- **Configure run after** on step 2: if the move fails (for example a name clash), email the coordinator and the program mailbox.

---

## F6: Daily Reminders

**Trigger:** *Recurrence*
- Interval: 1 Day
- Time zone: (UTC-05:00) Eastern Time
- At these hours: `7`
- At these minutes: `0`

**Why "exact-day match":** each query looks only for dates exactly N days out, for each N in Settings. A permit therefore matches once at 60 days, once at 30 and once at 7, and never in between. `LastReminderKey` guards against a second run on the same day, for example a manual re-run.

**Actions:**
1. **Get items Settings** (Settings), Top Count 50
2. **Compose Today**
   ```
   formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')
   ```
3. **Compose Mailbox**
   ```
   first(body('Filter_array_Mailbox'))?['Value']
   ```
   - Precede this with a **Filter array Mailbox** action: From `body('Get_items_Settings')?['value']`, condition `item()?['Title']` is equal to `ProgramMailbox`.
   - Use the same pattern for **Filter array Exp**, **Filter array COI** and **Filter array Start**, which match the keys `ReminderDaysPermitExpiry`, `ReminderDaysCOI` and `ReminderDaysStartUnexecuted`.
4. **Select ExpDates** builds the OData date clauses from the offsets.
   - From: `split(first(body('Filter_array_Exp'))?['Value'], ',')`
   - Map (text mode). The canonical expression is:
     ```
     concat('PermitExpiration eq ''', formatDateTime(addDays(utcNow(), int(trim(item()))), 'yyyy-MM-dd'), '''')
     ```
   - In the SharePoint OData string, `''` inside a WDL string is one literal `'`.
   - Better near midnight UTC: use `addDays(convertFromUtc(utcNow(), 'Eastern Standard Time'), int(trim(item())))`. At 07:00 Eastern the UTC date and the local date are the same, so either works.
5. **Select COIDates:** as above, from `Filter_array_COI`, with `COIExpiration`.
6. **Select StartDates:** as above, from `Filter_array_Start`, with `ProposedStart`.
7. **Get items Exp** (Permits), Top Count 500. Filter Query:
   ```
   (@{join(body('Select_ExpDates'), ' or ')}) and (Status eq 'Executed' or Status eq 'Active')
   ```
   With today = 2026-11-23, this resolves to:
   `(PermitExpiration eq '2027-01-22' or PermitExpiration eq '2026-12-23' or PermitExpiration eq '2026-11-30') and (Status eq 'Executed' or Status eq 'Active')`
8. **Get items COI** (Permits). Filter Query:
   ```
   (@{join(body('Select_COIDates'), ' or ')}) and Status ne 'Closed' and Status ne 'Withdrawn' and Status ne 'Denied'
   ```
9. **Get items Start** (Permits). Filter Query:
   ```
   (@{join(body('Select_StartDates'), ' or ')}) and (Status eq 'Received' or Status eq 'Under Review' or Status eq 'Draft Permit' or Status eq 'Out for Permittee Signature' or Status eq 'Out for Superintendent Signature')
   ```

   **Verify the date filter.** Date-only columns are stored as local midnight converted to UTC. In most tenants `Col eq 'yyyy-MM-dd'` matches date-only values, but if a test permit due in exactly 30 days is *not* returned, use one of these instead:
   - The range form `(Col ge 'D' and Col lt 'D+1')`. Build `D+1` with `addDays(..., add(int(trim(item())), 1))`.
   - Drop the date clauses from OData and filter in the flow: Filter array where `contains(variables('ExpDateList'), formatDateTime(item()?['PermitExpiration'], 'yyyy-MM-dd'))`.

10. **Select ExpRows**
    - From: `body('Get_items_Exp')?['value']`
    - Map:

    | Key | Value |
    |---|---|
    | `Id` | `item()?['ID']` |
    | `To` | `if(empty(item()?['Coordinator']?['Email']), outputs('Compose_Mailbox'), item()?['Coordinator']?['Email'])` |
    | `Permit` | `item()?['PermitNumber']` |
    | `Project` | `item()?['ProjectTitle']` |
    | `Reminder` | `Permit expires` |
    | `Date` | `formatDateTime(item()?['PermitExpiration'], 'yyyy-MM-dd')` |
    | `DaysOut` | `div(sub(ticks(formatDateTime(item()?['PermitExpiration'], 'yyyy-MM-dd')), ticks(outputs('Compose_Today'))), 864000000000)` |
    | `Key` | `concat('EXP:', outputs('Compose_Today'))` |
    | `PrevKey` | `coalesce(item()?['LastReminderKey'], '')` |
    | `Link` | `item()?['{Link}']` |

11. **Select COIRows** and **Select StartRows:** same shape, with Reminder `COI expires` / `Start date, not executed`, the matching date column, and Key prefix `COI:` / `START:`.
12. **Filter array Due** drops reminders already sent today.
    - From: `union(body('Select_ExpRows'), body('Select_COIRows'), body('Select_StartRows'))`
    - Condition (advanced): `@not(contains(item()?['PrevKey'], item()?['Key']))`
13. **Select Recipients**
    - From: `body('Filter_array_Due')`
    - Map (text mode): `item()?['To']`
14. **Compose UniqueRecipients:** `union(body('Select_Recipients'), body('Select_Recipients'))`. Using `union` with itself removes duplicates.
15. **Apply to each Recipient** over `outputs('Compose_UniqueRecipients')`
    1. **Filter array Mine:** From `body('Filter_array_Due')`, where `item()?['To']` equals `items('Apply_to_each_Recipient')`
    2. **Select Table:** map `Permit`, `Project`, `Reminder`, `Date`, `Days out` (from `DaysOut`), and `Link`
    3. **Create HTML table:** From `body('Select_Table')`, Columns Automatic
    4. **Send an email (V2)**
       - To: `items('Apply_to_each_Recipient')`
       - CC: `outputs('Compose_Mailbox')`
       - Subject: `concat('SUP reminders for ', outputs('Compose_Today'), ' (', length(body('Filter_array_Mine')), ')')`
       - Body: `<p>Permits needing attention:</p>@{body('Create_HTML_table')}`
       - Optional: wrap `Create_HTML_table` in `replace(..., '<table>', '<table border="1" cellpadding="4" style="border-collapse:collapse">')` for borders.
16. **Apply to each Sent** over `body('Filter_array_Due')`, with **Concurrency 1**. A permit can appear twice (EXP and COI on the same day), so the updates must not race.
    1. **Get item Fresh** (Permits): Id `items('Apply_to_each_Sent')?['Id']`
    2. **Compose NewKey.** This appends the key and keeps the last 12 entries. Each entry is about 15 characters, so 12 entries stay under the 255-character limit of a single-line column.
       ```
       join(skip(split(concat(coalesce(body('Get_item_Fresh')?['LastReminderKey'], ''), '|', items('Apply_to_each_Sent')?['Key']), '|'), max(0, sub(length(split(concat(coalesce(body('Get_item_Fresh')?['LastReminderKey'], ''), '|', items('Apply_to_each_Sent')?['Key']), '|')), 12))), '|')
       ```
       The first run leaves a leading empty entry. That is harmless.
    3. **Update item Key** (Permits)
       - Id: `items('Apply_to_each_Sent')?['Id']`
       - LastReminderKey: `outputs('Compose_NewKey')`
       - Status Value: `body('Get_item_Fresh')?['Status']?['Value']`
    4. **AUDIT(Reminder Sent, ...)** with Detail `concat(items('Apply_to_each_Sent')?['Reminder'], ' in ', items('Apply_to_each_Sent')?['DaysOut'], ' days, to ', items('Apply_to_each_Sent')?['To'])` and Actor `system`

Updating `LastReminderKey` fires the Permits *modified* triggers. F7b ignores it because Status is unchanged, and F5 ignores it because of its trigger condition.

---

## F7: Audit logging

### F7a: child flow
See the top of this page.

### F7b: Status Changed logger
**Trigger:** SharePoint, *When an item or a file is modified* (Permits). Versioning must be on; the script enables it.

**Actions:**
1. **Get changes** (rename *Get changes for an item or a file (properties only)*)
   - Id: `triggerBody()?['ID']`
   - Since: `triggerOutputs()?['body/{TriggerWindowStartToken}']`
   - Include minor versions: Yes
2. **Condition:** `body('Get_changes')?['ColumnHasChanged']?['Status']` *is equal to* `true`. If not, terminate with **Succeeded**.

   *Get changes* returns only **has-changed booleans**, not old values. The previous Status comes from the version history in step 3.
3. **Send an HTTP request to SharePoint** (Standard)
   - Method: `GET`
   - Uri:
     ```
     _api/web/lists/getbytitle('Permits')/items(@{triggerBody()?['ID']})/versions?$select=VersionLabel,Status&$top=2
     ```
   - Headers: `Accept: application/json;odata=nometadata`
   - **Verify:** the versions collection should be newest first. If `$top` is rejected, drop it.
4. **Compose PreviousStatus**
   ```
   coalesce(body('Send_an_HTTP_request_to_SharePoint')?['value']?[1]?['Status'], '(none)')
   ```
5. **AUDIT(Status Changed, ...)**
   - Detail: `concat(outputs('Compose_PreviousStatus'), ' → ', triggerBody()?['Status']?['Value'])`
   - Actor: `triggerBody()?['Editor']?['Email']`

If staff save two edits within one trigger polling window, they arrive as one run, and only the net change is logged. When a flow made the change, Actor is the flow's service account; the parent flow's own AUDIT entry carries the human context.

---

## Summary

| Flow | Trigger | Connectors | Premium? |
|---|---|---|---|
| F1a | Forms: new response | Forms, SharePoint | No |
| F1b | SharePoint: item created (concurrency 1) | SharePoint, Outlook | No |
| F2 | SharePoint: item modified, with Get changes; or Power Apps (V2) | SharePoint | No |
| F3 | Power Apps (V2) | SharePoint, **Word Online (Business): Populate a Microsoft Word template** | **Yes** (Standard fallback described) |
| F4 primary | Power Apps (V2) plus provider trigger | SharePoint, e-sign provider | Depends on provider (**verify**) |
| F4 fallback | SharePoint: file created | SharePoint, Approvals, Outlook | No |
| F5 | SharePoint: item modified, with trigger condition | SharePoint | No |
| F6 | Recurrence 07:00 | SharePoint, Outlook | No |
| F7a | Manually trigger (child) | SharePoint | No (must be in a solution) |
| F7b | SharePoint: item modified | SharePoint (incl. HTTP request to SharePoint) | No |
