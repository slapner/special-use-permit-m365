# Build guide validation 2: review of the rewrite

Reviewed: `docs/build-guide.md` (2,925 lines, commit `da61878`), against `kit/flows.md`, `kit/Provision-SUPSite.ps1`, `kit/README.md`, `kit/list-views.md`, the seed CSVs, `spec/data-model.md` and `spec/facts.md`. Date: 2026-11-23. Nothing was run in a tenant.

## Verdict

**Buildable by a first-time builder: yes, with the listed fixes.**

The rewrite is a large improvement on the version the first report reviewed. Every action an expression refers to is defined earlier in its flow under the exact name, every expression is syntactically valid, and the guide and kit agree expression for expression. The flows a builder meets first (F7a, F1b, F1a, F7b, F5, F6, F8, F9) should work as written, subject to the tenant tests the guide already lists.

This report holds 55 find-and-replace pairs: 19 WRONG, 24 INCOMPLETE and 12 VERIFY. Nine things would stop or mislead a builder and need fixing before the guide is used:

1. **F3's default expiration fails** (A1). `empty()` is called on a Number column, so the run stops on every permit with a blank Permit Expiration.
2. **The app's role flag does not work on SharePoint** (B1 to B1f). `DataSourceInfo` checks permissions only for Dataverse, so every viewer sees every action button.
3. **The generated app may not have the three screens Phase 6 is written against** (B2). Microsoft's current page describes different templates.
4. **Path A (DocuSign) cannot be built from the tables** (A2, A2b, A3, A4): the document field takes Base64 text and a type, the callback trigger has three required fields the guide does not give and carries one event, and DocuSign Connect must be enabled first (C2).
5. **Path B (Adobe Acrobat Sign) is missing a required field** on the create action and the trigger's settings (A5, A5c).
6. **Migrated files are never stamped** (A9 to A9d). F9 does not run for files that are moved in, so the app's Documents screen is empty for every migrated permit.
7. **Run only users omits the e-signature connection** (A6), and the Step 8.1 check that is meant to prove the setting cannot detect it (C1).
8. **Path C cannot be restarted the way the guide says** (A7, A7b), and its rejection email fails when there is no comment (A8).
9. **The F6 fallback for the date filter is not a usable expression** (A10).

Everything else is low severity or a tenant test. The most useful of the new tenant tests are A23 (does F5's folder move restart F4c) and B4 (a status button pressed on a record a flow has just changed).

## How to read this report

- **Verdicts:** WRONG (exact replacement given), INCOMPLETE (what to add), VERIFY (what to test in the tenant, with a fallback). OK items are counted, not listed.
- **Evidence tags:** `doc` means a Microsoft or vendor page opened today says so, and the quote is given. `trace` means the guide's own text, the kit or the script proves it. `pk` means product knowledge that no page opened today confirms; treat those as tenant tests.
- **Guide text** blocks are copied from the guide. A script confirmed that each one occurs exactly once in the guide, starting on the line cited, and that all 55 pairs can be applied to one copy of the guide together, in any of six random orders tried, without one breaking another.
- **WRONG and INCOMPLETE pairs** can be applied as they stand. **VERIFY pairs** add a tenant test, usually with a fallback to use only if the test fails; they are safe to apply now. B4 is the one VERIFY pair that changes a formula, and it behaves like the original when nothing is wrong.
- An item that already carries an accurate "Test in your tenant" note in the guide is counted as OK and not repeated here.
- `kit/flows.md` repeats the guide's flow text. Any fix to a flow in sections A and C must be applied to both files.


## A. Flows (Phase 4, Phase 5 and F10)

Scope: F8, F9, F10, all four F4 paths, F3 in both versions, F4a's PDF step, F5's failure path, F1b's counter and add-ons, and F6, each read row by row. F7a, F1a, F2a, F2b and F7b had the lighter pass.

| ID | Line | Verdict | Severity | Item |
| --- | --- | --- | --- | --- |
| A1 | 1341 | WRONG [doc + pk] | High | F3-A (Compose Expiration): `empty()` and `int()` on a Number column |
| A2 | 1607 | WRONG [doc] | High (path A) | Path A, action A3: **Add documents to an envelope** fields |
| A2b | 1622 | INCOMPLETE [doc] | High (path A) | Path A: **Account ID** is required on every DocuSign action |
| A3 | 1674 | INCOMPLETE [doc] | High (path A) | F4b path A trigger: required fields missing, and V3 carries one event |
| A4 | 1696 | INCOMPLETE [doc] | Medium (path A) | F4b 8C.1: **Get documents from an envelope** needs **Output format** |
| A5 | 1634 | INCOMPLETE [doc] | Medium (path B) | Path B, action B2: **State** is required |
| A5c | 1675 | INCOMPLETE [doc + pk] | Medium (path B) | F4b path B trigger: required fields missing |
| A6 | 673 | INCOMPLETE [trace] | Medium | Step 4.4 Run only users: DocuSign / Adobe connection missing; stated reason is wrong |
| A7 | 1844 | WRONG [trace + doc] | Medium (path C) | F4c timeout email: "Upload the signed copy again" does not restart the flow |
| A7b | 1765 | INCOMPLETE [trace] | Medium (path C) | F4c: same-name upload note |
| A8 | 1836 | WRONG [doc] | Medium (path C) | F4c 8N.2: email Body is null when the Superintendent rejects without a comment |
| A9 | 2751 | WRONG [doc] | Medium (migration) | Step 9.3: F9 does not run for files that are moved in |
| A9b | 2781 | INCOMPLETE [doc] | Medium (migration) | F10: add the stamping actions |
| A9c | 2740 | INCOMPLETE [doc] | Medium (migration) | Step 9.3, item 9: say that F10 stamps the files |
| A9d | 1940 | INCOMPLETE [doc] | Medium (migration) | F9 notes: files moved in are not covered |
| A10 | 2129 | INCOMPLETE [trace] | Low-Medium | F6: the D+1 alternative is not a pasteable expression |
| A11 | 1585 | INCOMPLETE [trace] | Low-Medium | F4a: no check for applicant email or Superintendent before `PENDING` is set |
| A11b | 1561 | INCOMPLETE [trace] | Low-Medium | F4a 5N.1: message to match the wider check |
| A23 | 1107 | VERIFY [doc + pk] | Low-Medium | F5: does the folder move restart F4c or F9? |
| A5b | 1641 | WRONG [doc] | Low (path B) | Path B: fallback action name |
| A12 | 1777 | WRONG [trace] | Low | F4c: the second trigger condition does not do what the text says |
| A12b | 1780 | WRONG [trace] | Low | F4c: explanation of the second trigger condition |
| A13 | 1058 | INCOMPLETE [trace] | Low | F5 failure path: the item is "repaired" when the failure email itself fails |
| A14 | 1512 | INCOMPLETE [doc] | Low | F3 version 2: a one-minute Delay against the two-minute response limit |
| A15 | 1467 | INCOMPLETE [doc] | Low | F3 version 2: **Location** when the site is not in the dropdown |
| A16 | 1119 | INCOMPLETE [doc] | Low | F8 and F1b add-on B: mailbox rights take time to apply |
| A17 | 1171 | VERIFY [doc] | Low | F8-A: `substring` when the subject ends with the permit number |
| A18 | 1291 | VERIFY [doc] | Low | F2b: sequential loop against the two-minute response limit |
| A19 | 1592 | VERIFY [pk] | Low | F4a: Convert file straight after Create file |
| A20 | 1010 | VERIFY [pk] | Low | F7b (lighter pass): `$select` on the versions endpoint |
| A21 | 1274 | VERIFY [pk] | Low | Trigger name **Power Apps (V2)** (lines 1274, 1303, 1541) |
| A22 | 1741 | VERIFY [pk] | Low | F4b: the DocuSign sandbox test |
| A24 | 1889 | INCOMPLETE [trace] | Low (path D) | F4d: the final Update item has no Id and no date expression |

### A1 — F3-A (Compose Expiration): `empty()` and `int()` on a Number column

**WRONG** [doc + pk] · High · line 1341

`DefaultTermDays` is a Number column, so **Get item Type** returns a number. Microsoft's function reference gives `empty` the parameter types "String, Array, or Object" and `int` the type "String". `empty(30)` stops the run with a type error on every permit that has a blank Permit Expiration and a Proposed Start, which is exactly the case the default exists for. The replacement tests for null and converts through text, so it works whether the connector returns `30` or `30.0`.

Guide text:

````
if(or(empty(body('Get_item_Permit')?['ProposedStart']), empty(body('Get_item_Type')?['DefaultTermDays'])), '', addDays(body('Get_item_Permit')?['ProposedStart'], int(body('Get_item_Type')?['DefaultTermDays']), 'yyyy-MM-dd'))
````

Replace with:

````
if(or(empty(body('Get_item_Permit')?['ProposedStart']), equals(body('Get_item_Type')?['DefaultTermDays'], null)), '', addDays(body('Get_item_Permit')?['ProposedStart'], int(first(split(string(body('Get_item_Type')?['DefaultTermDays']), '.'))), 'yyyy-MM-dd'))
````

Same expression in `kit/flows.md`. The "Check it works" test at line 1516 covers this case; it would have failed.

### A2 — Path A, action A3: **Add documents to an envelope** fields

**WRONG** [doc] · High (path A) · line 1607

The DocuSign connector page lists this action's required fields as "Document Base64 \*" ("Base64 of document content"), "Document type \*" ("pdf, docx etc.") and "Document name \*". There is no "Document content" field, and the PDF from **Convert file** is binary, not Base64 text. Every DocuSign action also has a required **Account ID**. *Test in your tenant:* open the sent envelope and confirm the PDF opens; if it is corrupt, use `outputs('Compose_PdfContent')?['$content']` instead of `base64(...)` [pk].

Guide text:

````
|  |  | Document content | `outputs('Compose_PdfContent')` |
````

Replace with:

````
|  |  | Document Base64 | `base64(outputs('Compose_PdfContent'))` |
|  |  | Document type | Text `pdf` |
````

Also add the sentence in A2b so the builder fills **Account ID** on A3 to A6 and 8C.1.

### A2b — Path A: **Account ID** is required on every DocuSign action

**INCOMPLETE** [doc] · High (path A) · line 1622

The connector page marks "Account ID" required on **Add documents to an envelope**, **Add recipient to an envelope (V2)**, **Send envelope** and **Get documents from an envelope**. The tables give it only on A1.

Guide text:

````
*Test in your tenant:* ask the DocuSign administrator how signers place their signature.
````

Replace with:

````
Every DocuSign action has a required **Account ID** field. Choose the same account in each one. In A4 and A5 the name and email fields appear after you choose **Recipient type**.

*Test in your tenant:* ask the DocuSign administrator how signers place their signature.
````

### A3 — F4b path A trigger: required fields missing, and V3 carries one event

**INCOMPLETE** [doc] · High (path A) · line 1674

The connector page gives **When an envelope status changes (Connect) (V3)** three required fields: "Account", "Connect name" and "Envelope event" (type string, one value). The guide gives none of them, and F4b's Switch expects completed, declined and voided in one flow, which a single-event trigger cannot deliver. The V3 payload is documented (`data.envelopeSummary.envelopeId`, `data.envelopeSummary.status`), so it stays the main route here. The page's other trigger, **When a Docusign Connect event occurs (Account-level)**, takes "Trigger events" as a list ("To include another event, select 'Add new item.'"), which would keep one F4b, but the page does not show its payload or event names, so it is offered as a tenant test. The page also says: "DocuSign Connect must be enabled in your DocuSign account. It is not enabled by default."

Guide text:

````
- **Path A trigger:** DocuSign **When an envelope status changes (Connect) (V3)**.
````

Replace with:

````
- **Path A trigger:** DocuSign **When an envelope status changes (Connect) (V3)**. Account: the agency account. Connect name: Text `SUP completed`. Envelope event: choose the completed event.
- This trigger carries one event. For declined and voided requests, either save two copies of F4b with **Envelope event** changed (each needs actions 1 to 8 and its own case), or let the coordinator handle a decline by hand, as on path B.
- *Test in your tenant:* the trigger **When a Docusign Connect event occurs (Account-level)** accepts several **Trigger events** in one flow. If its dynamic content offers the envelope ID and the envelope status, use it instead and keep a single F4b.
- Either trigger needs DocuSign Connect switched on for the account. It is off by default.
````

If you build the two extra copies, path A keeps 15 flows switched on, not 13. Say so in the count rule at line 583 and in `kit/README.md`.

### A4 — F4b 8C.1: **Get documents from an envelope** needs **Output format**

**INCOMPLETE** [doc] · Medium (path A) · line 1696

The connector page lists "Output format" as required ("Enter 'string(document ID)' to get a single document, or select a format"), plus "Account ID". The action returns binary file content, so `body('Get_signed_PDF')` is right.

Guide text:

````
| 8C.1 | Path A: Get documents from an envelope. Path B: Get a PDF of a signed agreement → **Get signed PDF** | Envelope or Agreement ID | `outputs('Compose_RequestId')` |
````

Replace with:

````
| 8C.1 | Path A: Get documents from an envelope. Path B: Get a PDF of a signed agreement → **Get signed PDF** | Envelope or Agreement ID | `outputs('Compose_RequestId')` |
|  |  | Path A only: Output format | Choose the combined PDF option |
````

### A5 — Path B, action B2: **State** is required

**INCOMPLETE** [doc] · Medium (path B) · line 1634

The Adobe Acrobat Sign connector page marks seven fields required on this action: Agreement Name, ID, Signature Type, Email, Order, Role and **State** ("The state in which the agreement should land"). State is a required field with no row in the table. The page documents one flat Email / Order / Role set; the guide's existing tenant test for a second participant stays necessary.

Guide text:

````
|  |  | Signature type | Choose the e-signature option |
````

Replace with:

````
|  |  | Signature type | Choose the e-signature option |
|  |  | State | Choose the option that sends the agreement now (in process), not draft |
````

### A5c — F4b path B trigger: required fields missing

**INCOMPLETE** [doc + pk] · Medium (path B) · line 1675

The connector page gives this trigger required fields "Name", "Scope" and an events list, and returns the agreement ID at `agreement.id`. The guide gives no trigger settings. The Scope option's wording is from product knowledge.

Guide text:

````
- **Path B trigger:** Adobe Acrobat Sign **When an agreement workflow is completed successfully**.
````

Replace with:

````
- **Path B trigger:** Adobe Acrobat Sign **When an agreement workflow is completed successfully**. Name: Text `SUP completed`. Scope: choose the option that covers every agreement the service account sends. If an events field shows, keep its default. The agreement ID token is the trigger's `agreement.id`.
````

### A6 — Step 4.4 Run only users: DocuSign / Adobe connection missing; stated reason is wrong

**INCOMPLETE** [trace] · Medium · line 673

F4a uses SharePoint, OneDrive for Business and DocuSign or Adobe Acrobat Sign. The list omits the e-signature connection, so it stays "Provided by run-only user" and every coordinator is asked to sign in to DocuSign with their own account. The stated consequence is also not what happens: the audit row is written by child flow F7a on its own connection, and no app-started flow writes Settings. Coordinators have Contribute on Permits, PermitConditions and Permit Records, so F2b and F3 would run on their own connections but create rows and files in their names.

Guide text:

````
For SharePoint, and for Word Online, OneDrive and Outlook where used, choose **Use this connection**. Otherwise the flow runs with the coordinator's own rights and cannot write AuditLog or Settings.
````

Replace with:

````
For every connection listed (SharePoint, and Word Online, OneDrive, Outlook, DocuSign or Adobe Acrobat Sign where used), choose **Use this connection**. Otherwise each coordinator is asked to sign in to those services with their own account, rows and files are created in their name, and F4a looks for `SUP-temp` in their own OneDrive.
````

Same sentence in `kit/flows.md` line 107.

### A7 — F4c timeout email: "Upload the signed copy again" does not restart the flow

**WRONG** [trace + doc] · Medium (path C) · line 1844

F4c's trigger is **When a file is created (properties only)** ("Triggers when an item is created in a library"). Uploading the same file name again replaces the existing file, which is a modification, so nothing starts. The same applies after a rejection if the draft version number has not changed.

Guide text:

````
The approval request expired. Upload the signed copy again to restart it.
````

Replace with:

````
The approval request expired. Delete the signed copy from the permit folder, then upload it again to restart the approval.
````

### A7b — F4c: same-name upload note

**INCOMPLETE** [trace] · Medium (path C) · line 1765

Companion to A7, at the place the coordinator reads first.

Guide text:

````
The upload starts F4c. Renaming a file already in the folder does not start it, so upload a copy.
````

Replace with:

````
The upload starts F4c. Renaming a file already in the folder does not start it, so upload a copy. Uploading over a file of the same name does not start it either: delete the old signed copy first.
````

### A8 — F4c 8N.2: email Body is null when the Superintendent rejects without a comment

**WRONG** [doc] · Medium (path C) · line 1836

The Office 365 Outlook connector page marks **Body** required on **Send an email (V2)**. A rejection with no comment gives a null body, the action fails, and action 8N.3 (the audit row) is skipped after the status has already been reset.

Guide text:

````
|  |  | Body | `first(body('Start_and_wait_for_an_approval')?['responses'])?['comments']` |
````

Replace with:

````
|  |  | Body | `concat('Superintendent comments: ', coalesce(first(body('Start_and_wait_for_an_approval')?['responses'])?['comments'], '(none)'))` |
````

### A9 — Step 9.3: F9 does not run for files that are moved in

**WRONG** [doc] · Medium (migration) · line 2751

Microsoft's SharePoint connector guidance says, under "Move files and flow runs": "Moving the file doesn't alter any custom metadata, including when the file was created and modified. Hence, this action doesn't trigger any flows for those file updates associated with the library where it was moved." Migrated files therefore keep a blank Permit Number, and the app's Documents screen (Step 6.8) shows nothing for migrated permits. F10 is the natural place to stamp them.

Guide text:

````
Flow F9 stamps the permit number on every moved file, about three actions per file. A standard licence allows a limited number of actions a day. Move a few hundred files at a time if you have thousands.
````

Replace with:

````
Flow F9 does not run for files that are moved in. Microsoft's connector guidance says a move keeps each file's created date and starts no flow in the destination library. F10 therefore stamps the permit number on the files itself, one action per file. A standard licence allows a limited number of actions a day, so run F10 after each batch of a few hundred files if you have thousands. *Test in your tenant:* move five files first and check whether F9 runs; if it does, F10 simply finds nothing left to stamp.
````

Same paragraph in `kit/flows.md` line 1670. Apply A9b to A9d with it. Microsoft's statement is about moves between libraries; whether a move inside one library behaves the same is a tenant test (A23).

### A9b — F10: add the stamping actions

**INCOMPLETE** [doc] · Medium (migration) · line 2781

Follows from A9. The three actions sit after **Condition Needs path**, inside **Apply to each Folder**, so a second run stamps a later batch even when the folder path is already filled. `Include Nested Items` defaults to true (connector page), so subfolders are covered. Every referenced action is defined earlier in F10.

Guide text:

````
|  |  | Status Value | `first(body('Get_items_Permit')?['value'])?['Status']?['Value']` |
````

Replace with:

````
|  |  | Status Value | `first(body('Get_items_Permit')?['value'])?['Status']?['Value']` |
| 3.2.4 | Get files (properties only) → **Get files Unstamped** | Library Name | Choose **Permit Records** |
|  |  | Filter Query | Text `FSObjType eq 0 and PermitNumber eq null` |
|  |  | Limit Entries to Folder | `concat('/PermitRecords/', items('Apply_to_each_Top'), '/', items('Apply_to_each_Folder')?['{FilenameWithExtension}'])` |
|  |  | Top Count | Text `5000` |
| 3.2.5 | Apply to each → **Apply to each File** | Select an output from previous steps | `if(greater(length(body('Get_items_Permit')?['value']), 0), body('Get_files_Unstamped')?['value'], json('[]'))` |
| 3.2.5.1 | Update file properties → **Update file properties Stamp** | Library Name | Choose **Permit Records** |
|  |  | Id | `items('Apply_to_each_File')?['ID']` |
|  |  | Permit Number | `outputs('Compose_LegacyNumber')` |
````

The `PermitNumber eq null` clause is from product knowledge; if the filter is rejected, shorten it to `FSObjType eq 0`. Stamping a file twice is harmless.

### A9c — Step 9.3, item 9: say that F10 stamps the files

**INCOMPLETE** [doc] · Medium (migration) · line 2740

Follows from A9.

Guide text:

````
9. Build and run flow F10 below. It fills **Folder** and **Folder Path** on each permit.
````

Replace with:

````
9. Build and run flow F10 below. It fills **Folder** and **Folder Path** on each permit and stamps the permit number on the files in each folder.
````

### A9d — F9 notes: files moved in are not covered

**INCOMPLETE** [doc] · Medium (migration) · line 1940

Follows from A9. It also applies after go-live, when staff use **Move to** to bring a file into a permit folder.

Guide text:

````
- A file outside a permit folder, such as a template, matches no permit and is left alone.
````

Replace with:

````
- A file outside a permit folder, such as a template, matches no permit and is left alone.
- F9 runs for files that are uploaded or newly created. Microsoft says a file moved in from another library starts no flow. Tell staff to upload, not move, or to type the **Permit Number** on a moved file. F10 stamps moved files at migration.
````

### A10 — F6: the D+1 alternative is not a pasteable expression

**INCOMPLETE** [trace] · Low-Medium · line 2129

The fallback for the documented F6 tenant test gives a clause pattern and half an expression (no `formatDateTime`, no `concat`, no quoting). A first-time builder cannot assemble it. The replacement is a complete drop-in for expression F6-A; it yields `(PermitExpiration ge '2026-12-23' and PermitExpiration lt '2026-12-24')`, which joins correctly inside Text F6-B to F6-D.

Guide text:

````
- A date range in each clause: `(PermitExpiration ge 'D' and PermitExpiration lt 'D+1')`. Build `D+1` with `addDays(convertFromUtc(utcNow(), 'Eastern Standard Time'), add(int(trim(item())), 1))`.
````

Replace with:

````
- A date range in each clause. Replace expression F6-A in actions 8 to 10 with this, changing the column name for COI and start dates as before:

```
concat('(PermitExpiration ge ''', formatDateTime(addDays(convertFromUtc(utcNow(), 'Eastern Standard Time'), int(trim(item()))), 'yyyy-MM-dd'), ''' and PermitExpiration lt ''', formatDateTime(addDays(convertFromUtc(utcNow(), 'Eastern Standard Time'), add(int(trim(item())), 1)), 'yyyy-MM-dd'), ''')')
```
````

### A11 — F4a: no check for applicant email or Superintendent before `PENDING` is set

**INCOMPLETE** [trace] · Low-Medium · line 1585

Line 1544 says each permit needs both, but F4-B does not test them. A missing value fails at the DocuSign or Adobe action after action 6 has written `PENDING`, and the permit is then stuck until the draft is regenerated. `empty()` is safe here: both values are text or null.

Guide text:

````
and(greater(length(body('Get_files_Draft')?['value']), 0), empty(body('Get_item_Permit')?['SignatureRequestId']))
````

Replace with:

````
and(greater(length(body('Get_files_Draft')?['value']), 0), empty(body('Get_item_Permit')?['SignatureRequestId']), not(empty(body('Get_item_Permit')?['ApplicantEmail'])), not(empty(body('Get_item_Permit')?['Superintendent']?['Email'])))
````

Apply A11b with it. Same expression in `kit/flows.md`.

### A11b — F4a 5N.1: message to match the wider check

**INCOMPLETE** [trace] · Low-Medium · line 1561

Follows from A11.

Guide text:

````
Text `Not sent. Generate a draft first, or this permit is already out for signature.`
````

Replace with:

````
Text `Not sent. The permit needs a draft, an applicant email and a Superintendent, and must not already be out for signature.`
````

### A23 — F5: does the folder move restart F4c or F9?

**VERIFY** [doc + pk] · Low-Medium · line 1107

Microsoft's statement that a move starts no flow in the destination is about moves between libraries. F5 moves a folder inside one library, which is not covered. F4c has no check on the permit's status, so if the move did count as "file created", a closed path C permit would be set back to `Out for Superintendent Signature` and a new approval sent.

Guide text:

````
Do not assume item IDs or version history survive the move. Bookmarked folder links break.
````

Replace with:

````
Do not assume item IDs or version history survive the move. Bookmarked folder links break.
- *Test in your tenant:* close a test permit whose folder holds a `_PermitteeSigned.pdf`, then check the run history of F4c and F9. Neither should start. If F4c starts, add a **Condition** after its action 3 that ends the run unless the permit's status is `Out for Permittee Signature`.
````

### A5b — Path B: fallback action name

**WRONG** [doc] · Low (path B) · line 1641

The action is named "Create an agreement from a workflow and send for signature" on the connector page.

Guide text:

````
use **Create an agreement from a workflow** instead.
````

Replace with:

````
use **Create an agreement from a workflow and send for signature** instead.
````

### A12 — F4c: the second trigger condition does not do what the text says

**WRONG** [trace] · Low · line 1777

Line 1780 says the second row stops a reply that F8 filed from starting the approval. It does not. F8 names a filed reply `{PermitNumber}_Correspondence_{date}_{original name}`. If the applicant's file is called `SUP-2026-0042_DraftPermit_v2_PermitteeSigned.pdf`, the F8 copy still ends in `_PermitteeSigned.pdf` and still contains `_DraftPermit_v`, so both rows pass and the approval starts unchecked. The replacement keeps two rows and adds the missing test to the second.

Guide text:

````
@contains(triggerBody()?['{FilenameWithExtension}'], '_DraftPermit_v')
````

Replace with:

````
@and(contains(triggerBody()?['{FilenameWithExtension}'], '_DraftPermit_v'), not(contains(triggerBody()?['{FilenameWithExtension}'], '_Correspondence_')))
````

Apply A12b with it. Same condition in `kit/flows.md`.

### A12b — F4c: explanation of the second trigger condition

**WRONG** [trace] · Low · line 1780

Follows from A12.

Guide text:

````
The second row stops a reply that F8 filed from starting the approval before a person has checked it.
````

Replace with:

````
The second row limits the flow to files named by the convention and skips any reply that F8 filed, so the approval cannot start before a person has checked the signed copy.
````

### A13 — F5 failure path: the item is "repaired" when the failure email itself fails

**INCOMPLETE** [trace] · Low · line 1058

Traced: if action 9 fails (no Coordinator and a blank `ProgramMailbox` give a null To), action 10 is skipped, so action 11 runs and actions 12 and 13 write a Closed Projects path for a folder that is still under Open Projects. Letting the Terminate run after any result of action 9 except skipped keeps the three documented cases unchanged. The parallel-branch alternative at line 1106 was traced for all three cases and is correct as written.

Guide text:

````
|  |  | Message | Text `Folder move failed` |
````

Replace with:

````
|  |  | Message | Text `Folder move failed` |
|  |  | Run after | **Send an email (V2) Move failed**: tick **is successful**, **has failed** and **has timed out** |
````

### A14 — F3 version 2: a one-minute Delay against the two-minute response limit

**INCOMPLETE** [doc] · Low · line 1512

Power Automate's limits page: "Inbound request | 120 seconds", and flows with **Respond to a PowerApp or flow** "always return a response within this limit". A 60-second Delay plus the Word action can exceed it; the app then shows an error although the draft was created.

Guide text:

````
If action 14 fails, add a one-minute **Delay** before it.
````

Replace with:

````
If action 14 fails, add a **Delay** of 30 seconds before it. Keep it short: a flow that answers the app must respond within two minutes.
````

### A15 — F3 version 2: **Location** when the site is not in the dropdown

**INCOMPLETE** [doc] · Low · line 1467

The Word Online (Business) page says Location accepts a typed "SharePoint Site URL" as well as a dropdown choice. A Communication site the service account does not follow is often missing from the dropdown.

Guide text:

````
| Location | Choose the site |
````

Replace with:

````
| Location | Choose the site. If it is not listed, choose **Enter custom value** and paste the site's full address |
````

### A16 — F8 and F1b add-on B: mailbox rights take time to apply

**INCOMPLETE** [doc] · Low · line 1119

The Office 365 Outlook connector page: "After the permissions are granted for the account to access the shared mailbox, it can take about two hours until the permissions are replicated". A builder who tests straight after IT grants the rights sees a failing trigger and no reason.

Guide text:

````
- The service account needs **Full Access** on the mailbox (Phase 0).
````

Replace with:

````
- The service account needs **Full Access** on the mailbox (Phase 0). Allow about two hours after IT grants it before the trigger works.
````

### A17 — F8-A: `substring` when the subject ends with the permit number

**VERIFY** [doc] · Low · line 1171

The function reference says the sum of start index and length must be "less than the length of the string", otherwise "you get an error". A subject that ends exactly with the number, such as `Signed permit SUP-2026-0042`, sits on that boundary. Test that subject. Padding the subject removes the doubt and also turns the short-subject failure into a clean "no match".

Guide text:

````
- A subject with fewer than 13 characters after `SUP-` makes action 2 fail. The email stays in the Inbox.
````

Replace with:

````
- *Test in your tenant:* send one email whose subject ends with the permit number. If action 2 fails, change both `triggerOutputs()?['body/subject']` in expression F8-A to `concat(triggerOutputs()?['body/subject'], '             ')` (13 spaces). A short subject then ends at action 4N.1 instead of failing.
````

### A18 — F2b: sequential loop against the two-minute response limit

**VERIFY** [doc] · Low · line 1291

Same limit as A14. F2b runs five to seven actions per library row, one row at a time (the limits page: "Apply to each concurrency | 1 is the default"; range 1 to 50). With the 24 sample rows it finishes well inside two minutes; a real library of 100 or more rows may not. Time it with the real library.

Guide text:

````
Without the response action, the app refreshes before the new rows exist.
````

Replace with:

````
*Test in your tenant:* time F2b with your real library. If a run takes more than about 90 seconds, set **Degree of parallelism** on **Apply to each Condition** to `20` in F2b. The app waits at most two minutes for the answer.

Without the response action, the app refreshes before the new rows exist.
````

### A19 — F4a: Convert file straight after Create file

**VERIFY** [pk] · Low · line 1592

The OneDrive for Business page's known issues: conversion errors such as "Bad gateway" are worked around by "increasing the delay between the file creation and converting to PDF". It also says conversion does not support password-protected, digitally signed or IRM-restricted Word files. [doc for both; the need for a delay in this flow is a tenant test.]

Guide text:

````
**Convert file** works on files in the account's own OneDrive, not on SharePoint files.
````

Replace with:

````
**Convert file** works on files in the account's own OneDrive, not on SharePoint files. If it fails with "Bad gateway" or "not found", add a **Delay** of 10 seconds between actions 8 and 9.
````

### A20 — F7b (lighter pass): `$select` on the versions endpoint

**VERIFY** [pk] · Low · line 1010

The only call in the lighter-pass flows that could fail outright. The guide's test covers ordering and `$top` but not `$select=VersionLabel,Status`, which some tenants reject on version entries.

Guide text:

````
- *Test in your tenant:* the versions list should be newest first. If `$top` is rejected, remove `&$top=20` from the Uri.
````

Replace with:

````
- *Test in your tenant:* the versions list should be newest first. If the call is rejected, shorten the Uri to end at `/versions`, with no `$select` or `$top`.
````

### A21 — Trigger name **Power Apps (V2)** (lines 1274, 1303, 1541)

**VERIFY** [pk] · Low · line 1274

Not confirmed on a Microsoft page today: the canvas-app page only says "Have a Power Apps trigger". From product knowledge the current designer lists it under the Power Apps connector as **When Power Apps calls a flow (V2)**.

Guide text:

````
2. **Trigger:** **Power Apps (V2)**. Add one Number input named `PermitId`.
````

Replace with:

````
2. **Trigger:** **Power Apps (V2)**, which the current designer may list as **When Power Apps calls a flow (V2)**. Add one Number input named `PermitId`.
````

Lines 1303 and 1541 (F3 and F4a) name the trigger the same way and need the same clause.

### A22 — F4b: the DocuSign sandbox test

**VERIFY** [pk] · Low · line 1741

A DocuSign developer (demo) account signs in at a different address from production. The standard connector may not accept it; Microsoft lists a separate **Docusign Demo** connector, which `spec/facts.md` records as preview and GCC only.

Guide text:

````
*Test in your tenant:* in a sandbox account, send a test request and have the first signer sign. Watch F4b's run history.
````

Replace with:

````
*Test in your tenant:* send a test request to two test signers and have the first signer sign. Watch F4b's run history. A DocuSign developer sandbox needs the separate **Docusign Demo** connector; with the standard connector, test in the agency's real account.
````

### A24 — F4d: the final Update item has no Id and no date expression

**INCOMPLETE** [trace] · Low (path D) · line 1889

F4d is given as one sentence. F4c's actions 1 to 4 are reusable as described, but the closing **Update item** needs an Id and a date, and the audit row needs its fields. F4c's action 2 reads the permit number from the start of the file name, which works only if the signed copy keeps that start.

Guide text:

````
Finish with one **Update item** that sets **Superintendent Signed** and **Status Value** `Executed`, and one **Audit** row with EventType `Signed`.
````

Replace with:

````
Finish with one **Update item** on Permits: **Id** `first(body('Get_items_Permit')?['value'])?['ID']`, **Superintendent Signed** `formatDateTime(convertFromUtc(utcNow(), 'Eastern Standard Time'), 'yyyy-MM-dd')`, **Status Value** `Executed`. Then add one **Audit** row with EventType `Signed`, PermitNumber `outputs('Compose_PermitNumber')` and PermitId set to the same Id expression. If the signed copy's name does not start with the permit number, set **Compose PermitNumber** from `{Path}` as F9's action 3 does.
````


## B. Phase 6: the coordinator app

Scope: every formula and property value in Steps 6.2 to 6.11.

| ID | Line | Verdict | Severity | Item |
| --- | --- | --- | --- | --- |
| B1 | 2217 | WRONG [doc] | High | Formula 6-A: `DataSourceInfo(Permits, DataSourceInfo.EditPermission)` does not work on SharePoint |
| B1b | 2221 | WRONG [doc] | High | Step 6.3: explanation of `varCanEdit` |
| B1c | 2225 | WRONG [doc] | High | Step 6.3: tenant test for `varCanEdit` |
| B1d | 292 | INCOMPLETE [doc] | High | Step 1.2 Settings rows: add `Editors` |
| B1e | 295 | WRONG [doc] | High | Step 1.2: sentence under the Settings table |
| B1f | 2701 | WRONG [doc] | High | Step 9.1 tenant tests: the `varCanEdit` line |
| B2 | 2201 | INCOMPLETE [doc] | High | Step 6.2: the generated app may not have the three screens every later step names |
| B3 | 2194 | VERIFY [pk + doc] | Medium | Step 6.2: which environment the list-generated app lands in |
| B4 | 2294 | VERIFY [pk] | Medium | Formula 6-C: `Patch` on a stale `varPermit`, and no error handling |
| B5 | 2366 | VERIFY [pk] | Low-Medium | Formula 6-H: do the row's controls follow the gallery's DisplayMode? |
| B2b | 2187 | WRONG [doc] | Low | Step 6.1: "The generated app is phone-shaped" |
| B6 | 2196 | WRONG [doc] | Low | Steps 6.2 and 6.11: there is no **File** menu |
| B6b | 2496 | WRONG [doc] | Low | Step 6.11: Save and Publish |
| B7 | 2211 | INCOMPLETE [pk] | Low | Step 6.3: OnStart does not run by itself in Studio |
| B8 | 2301 | INCOMPLETE [trace] | Low | Formula 6-D: **Generate draft** offered on a permit F3 cannot process |
| B9 | 2497 | VERIFY [doc] | Low | Step 6.11: a security group as co-owner |
| B10 | 2340 | VERIFY [pk] | Low | Formula 6-E: `Launch` of a Word file may download it |
| B11 | 2348 | INCOMPLETE [trace] | Low | Step 6.6: Title stays on the edit form |

### B1 — Formula 6-A: `DataSourceInfo(Permits, DataSourceInfo.EditPermission)` does not work on SharePoint

**WRONG** [doc] · High · line 2217

Microsoft's `DataSourceInfo` page: "At this time, permissions checking with DataSourceInfo is only possible when using Microsoft Dataverse", and the function "returns true if it cannot determine whether the current user has the requested permission". `varCanEdit` is therefore true for everyone, so Viewers, compliance staff and approving officials see every action button. SharePoint still refuses their edits, but eight formulas (lines 2275 to 2301 and 2378) and two checklists depend on the flag, and the guide's own tenant test (line 2225) fails with no fallback. The fix reuses the pattern the guide already uses for `varIsApprover`.

Guide text:

````
Set(varCanEdit, DataSourceInfo(Permits, DataSourceInfo.EditPermission));
````

Replace with:

````
Set(varCanEdit, Lower(User().Email) in Split(Lower(LookUp(Settings, Title = "Editors").Value), ";").Value);
````

Apply B1b to B1f with it. The kit also needs the row: `Provision-SUPSite.ps1` seeds `Approvers` but no `Editors` row, and `kit/README.md` lists the Settings rows. The cost is one more list of emails to keep current when staff change; add it to the Step 8.4 runbook.

### B1b — Step 6.3: explanation of `varCanEdit`

**WRONG** [doc] · High · line 2221

Follows from B1.

Guide text:

````
`varCanEdit` is true for people whose SharePoint group can edit Permits.
````

Replace with:

````
`varCanEdit` is true for emails listed in the Settings row `Editors`: the coordinators and owners, in the same format as `Approvers`. Power Apps cannot read a person's SharePoint permission on a list, so the app needs this row. It only hides buttons; SharePoint permissions still decide what a person can change.
````

### B1c — Step 6.3: tenant test for `varCanEdit`

**WRONG** [doc] · High · line 2225

Follows from B1.

Guide text:

````
*Test in your tenant:* open the app as a Viewer and confirm `varCanEdit` is false, so the action buttons are hidden.
````

Replace with:

````
Check: open the app as a Viewer and confirm the action buttons are hidden. Open it as a coordinator listed in `Editors` and confirm they show.
````

### B1d — Step 1.2 Settings rows: add `Editors`

**INCOMPLETE** [doc] · High · line 292

Follows from B1.

Guide text:

````
| `Approvers` (optional) | Approving officials' emails, with no spaces, separated by `;` | The app (Phase 6). The script creates it blank; fill it in |
````

Replace with:

````
| `Approvers` (optional) | Approving officials' emails, with no spaces, separated by `;` | The app (Phase 6). The script creates it blank; fill it in |
| `Editors` | Coordinators' and owners' emails, with no spaces, separated by `;` | The app (Phase 6), to show the action buttons. Add this row by hand |
````

### B1e — Step 1.2: sentence under the Settings table

**WRONG** [doc] · High · line 295

Follows from B1d, which adds a row the script does not seed.

Guide text:

````
The script seeds every row, leaving the last two rows' values blank.
````

Replace with:

````
The script seeds every row except `Editors`, and leaves the values of `Approvers` and the two default rows blank.
````

### B1f — Step 9.1 tenant tests: the `varCanEdit` line

**WRONG** [doc] · High · line 2701

Follows from B1.

Guide text:

````
- [ ] `varCanEdit` is false for a Viewer, and flow output names in the app (Steps 6.3 and 6.5)
````

Replace with:

````
- [ ] The action buttons are hidden for a Viewer and shown for a person listed in `Editors`; flow output names in the app (Steps 6.3 and 6.5)
````

### B2 — Step 6.2: the generated app may not have the three screens every later step names

**INCOMPLETE** [doc] · High · line 2201

Microsoft's page for this exact path (updated 2026-11-04) no longer describes a three-screen phone app. It describes a "responsive single-screen template" and an "updated modern-controls template", and says: "The layout depends on the template available in your environment" and "The generated control and screen names can vary". Steps 6.4 to 6.6 are wired to `BrowseGallery1`, `TextSearchBox1`, `DetailForm1` and `EditForm1`. "Apply each formula to the matching control" is not something a first-time builder can do on a single-screen table-and-form app. A hand-build of the three screens takes ten minutes and makes every later step exact.

Guide text:

````
*Test in your tenant:* newer tenants may generate one screen with a table and a form instead of three screens. If so, the control names differ. Use the names you see, and apply each formula below to the matching control.
````

Replace with:

````
*Test in your tenant:* Microsoft says the generated layout depends on the template in your environment. If Studio does not show `BrowseScreen1`, `DetailScreen1` and `EditScreen1`, do not adapt the generated screens. Build the three by hand so the names below match:

1. Add three blank screens named `BrowseScreen1`, `DetailScreen1` and `EditScreen1`. Delete the generated screens.
2. On `BrowseScreen1`, insert a **Vertical gallery** named `BrowseGallery1` with data source **Permits** and the layout **Title, subtitle, and body**. Above it, insert a **Text input** named `TextSearchBox1` and an **Add** icon.
3. On `DetailScreen1`, insert a **Display form** named `DetailForm1` with data source **Permits**. Add an **Edit** icon and a back icon with **OnSelect** `Navigate(BrowseScreen1, ScreenTransition.None)`.
4. On `EditScreen1`, insert an **Edit form** named `EditForm1` with data source **Permits**. Add a **Check** icon with **OnSelect** `SubmitForm(EditForm1)` and a **Cancel** icon with **OnSelect** `ResetForm(EditForm1); Back()`.

The steps below that delete a generated icon do not apply to hand-built screens.
````

### B3 — Step 6.2: which environment the list-generated app lands in

**VERIFY** [pk + doc] · Medium · line 2194

Not stated on Microsoft's page. From product knowledge, **Integrate → Power Apps → Create an app** creates the app in the tenant's default environment. Phase 0 allows the SUP solution to live in another environment; if it does, step 6 cannot find the app and the Power Automate pane cannot list the three flows. The in-product path is quoted from Microsoft's page.

Guide text:

````
3. Select **Integrate → Power Apps → Create an app**. Name it `SUP Coordinator`.
````

Replace with:

````
3. Select **Integrate → Power Apps → Create an app**. Name it `SUP Coordinator`. When Studio opens, read the environment name at the top right. It must be the environment that holds the **SUP** solution. If it is not, close Studio without saving. Open Power Apps in the right environment, select **Start with data** on the home screen, choose **SharePoint**, enter the site address, pick **Permits** and select **Create app**.
````

### B4 — Formula 6-C: `Patch` on a stale `varPermit`, and no error handling

**VERIFY** [pk] · Medium · line 2294

From product knowledge: SharePoint rejects a Patch whose base record is older than the item on the server. That happens whenever a flow has changed the permit while the person stayed on the record, most visibly when someone enters a new application in the app, waits for F1b to number it, then presses **Start review**. As written, `varPermit` then becomes an error value, the screen empties, and "Status updated." still shows. The replacement patches a freshly read record and reports failure; it replaces both lines of formula 6-C. Test: create a permit in the app, stay on the record until F1b has numbered it, then press **Start review**.

Guide text:

````
Set(varPermit, Patch(Permits, varPermit, {Status: {Value: "Under Review"}}));
Notify("Status updated.", NotificationType.Success)
````

Replace with:

````
With({r: Patch(Permits, LookUp(Permits, ID = varPermit.ID), {Status: {Value: "Under Review"}})},
    If(IsError(r) || IsBlank(r),
        Notify("Status not updated. Reopen the permit and try again.", NotificationType.Error),
        Set(varPermit, r); Notify("Status updated.", NotificationType.Success)))
````

Safe to apply before the test: when there is no conflict it behaves exactly as the original.

### B5 — Formula 6-H: do the row's controls follow the gallery's DisplayMode?

**VERIFY** [pk] · Low-Medium · line 2366

Microsoft's gallery page describes DisplayMode but does not say that controls inside the template inherit it. Controls in a gallery default to `DisplayMode.Edit`. If they do not follow the gallery, conditions stay editable after the permit goes out for signature. Setting each row control explicitly removes the doubt.

Guide text:

````
| `galConditions` | DisplayMode | Formula 6-H |
````

Replace with:

````
| `galConditions` | DisplayMode | Formula 6-H |
| `tglIncluded`, `txtCondText`, save icon | DisplayMode | `Parent.DisplayMode` |
````

### B2b — Step 6.1: "The generated app is phone-shaped"

**WRONG** [doc] · Low · line 2187

Follows from B2. Microsoft's page describes the current templates as responsive.

Guide text:

````
The generated app is phone-shaped and opens in that shape on a desktop too.
````

Replace with:

````
An app generated from the older three-screen template is phone-shaped and opens in that shape on a desktop too.
````

### B6 — Steps 6.2 and 6.11: there is no **File** menu

**WRONG** [doc] · Low · line 2196

Microsoft's save-and-publish page: "Select **Save** on the command bar"; "On the command bar, select **Publish**", then "Select **Publish this version**".

Guide text:

````
5. Select **File → Save**.
````

Replace with:

````
5. Select **Save** on the command bar.
````

Apply B6b with it.

### B6b — Step 6.11: Save and Publish

**WRONG** [doc] · Low · line 2496

Same page as B6.

Guide text:

````
1. Select **File → Save**, then **Publish**.
````

Replace with:

````
1. Select **Save** on the command bar, then **Publish**, then **Publish this version**.
````

### B7 — Step 6.3: OnStart does not run by itself in Studio

**INCOMPLETE** [pk] · Low · line 2211

From product knowledge: after OnStart is typed, Studio does not run it until the app is reopened, so `varCanEdit` stays blank and every action button is hidden while the builder works.

Guide text:

````
3. In the tree view, select **App**. Set **OnStart** to formula 6-A.
````

Replace with:

````
3. In the tree view, select **App**. Set **OnStart** to formula 6-A. Then select **…** beside **App** and choose **Run OnStart**, so the two variables are set while you build.
````

### B8 — Formula 6-D: **Generate draft** offered on a permit F3 cannot process

**INCOMPLETE** [trace] · Low · line 2301

F3 action 3 fails on a blank Permit Type (a null Id), and action 7 fails on a blank Folder Path (`replace` needs text). Step 3.1 says a mistyped form option leaves the type blank "with no error", and a new application has no folder for a few minutes. The flow then fails and the app shows a raw error. Hiding the button is the smallest fix.

Guide text:

````
varCanEdit && (varPermit.Status.Value = "Under Review" || varPermit.Status.Value = "Draft Permit")
````

Replace with:

````
varCanEdit && (varPermit.Status.Value = "Under Review" || varPermit.Status.Value = "Draft Permit") && !IsBlank(varPermit.'Folder Path') && !IsBlank(varPermit.'Permit Type'.Value)
````

### B9 — Step 6.11: a security group as co-owner

**VERIFY** [doc] · Low · line 2497

Microsoft's sharing page: "In the sharing interface, you can't grant Co-owner permission to a security group if you created the app from within a solution." This app is created from the list and then added to the solution, so the panel may or may not allow it.

Guide text:

````
Add the owners group as co-owner.
````

Replace with:

````
Add the owners group as co-owner. If the panel refuses a group, add one named backup person as co-owner instead.
````

### B10 — Formula 6-E: `Launch` of a Word file may download it

**VERIFY** [pk] · Low · line 2340

From product knowledge: a direct link to a `.docx` often downloads the file instead of opening Word for the web, which contradicts Step 6.1 ("opens the document in a new browser tab"). Test with one draft.

Guide text:

````
*Test in your tenant:* Power Apps may show a flow's outputs in lower case, as in `fileurl`. Use the name the formula bar offers after `varDraft.`.
````

Replace with:

````
*Test in your tenant:* Power Apps may show a flow's outputs in lower case, as in `fileurl`. Use the name the formula bar offers after `varDraft.`.

*Test in your tenant:* press **Generate draft**. If the browser downloads the Word file instead of opening it, change the third line of formula 6-E to `If(!IsBlank(varDraft.fileurl), Launch(varDraft.fileurl & "?web=1"));`.
````

### B11 — Step 6.6: Title stays on the edit form

**INCOMPLETE** [trace] · Low · line 2348

Step 1.2 says F1b copies the permit number into Title, and the generated form shows a Title card first. Staff will type into it.

Guide text:

````
Remove the fields flows fill: Permit Number, Folder, Folder Path,
````

Replace with:

````
Remove the fields flows fill: Title, Permit Number, Folder, Folder Path,
````


## C. Step 1.6 and the rest of Phases 0 to 3 and 7 to 9

Scope: UI paths, licence rules, product behaviour and internal consistency.

| ID | Line | Verdict | Severity | Item |
| --- | --- | --- | --- | --- |
| C1 | 2605 | WRONG [trace] | Medium | Step 8.1: the audit row does not prove which connection the flow used |
| C2 | 158 | INCOMPLETE [doc] | Low-Medium | Phase 0, item 8: DocuSign Connect must be enabled |
| C3 | 228 | WRONG [trace] | Low | Option A run order, item 7 contradicts itself |
| C4 | 606 | WRONG [trace] | Low | Step 4.1: stale ID mapping sentence |

### C1 — Step 8.1: the audit row does not prove which connection the flow used

**WRONG** [trace] · Medium · line 2605

The audit row is written by child flow F7a, which always runs on its own embedded connection (line 709; Microsoft's child-flow page: "you can't pass connections from the parent flow to the child flow"). The row appears whether or not **Run only users** was set on F2b or F3, so the check passes when the setting is wrong.

Guide text:

````
The last check proves the app-started flows use the service account's connection (Step 4.4). If the audit step fails with "access denied", set **Run only users** on that flow.
````

Replace with:

````
The audit row is written by F7a on its own connection, so it does not show which connection the app-started flow used. To check that, open a row the flow just added to PermitConditions: **Created By** must be the service account, not the coordinator. If it shows the coordinator, set **Run only users** on that flow (Step 4.4).
````

### C2 — Phase 0, item 8: DocuSign Connect must be enabled

**INCOMPLETE** [doc] · Low-Medium · line 158

See A3. This is a request to the DocuSign administrator that takes time, so it belongs in the Phase 0 list.

Guide text:

````
ask whether a data loss prevention policy blocks the DocuSign or Adobe Acrobat Sign connector.
````

Replace with:

````
ask whether a data loss prevention policy blocks the DocuSign or Adobe Acrobat Sign connector. For path A, also ask the DocuSign administrator to enable **DocuSign Connect** on the account. Flow F4b's trigger needs it, and it is off by default.
````

### C3 — Option A run order, item 7 contradicts itself

**WRONG** [trace] · Low · line 228

This list is the script path, and the script creates both objects (`Provision-SUPSite.ps1` lines 406 to 410 and 580 to 590). `kit/README.md` has two different steps at this point, which the guide's list lacks.

Guide text:

````
7. Create the **SUP Admin** library and the *Changed this year* view by hand (Steps 1.3 and 2.4), unless you ran the script, which creates both.
````

Replace with:

````
7. Upload the Word templates to **Permit Records → _Templates** (Step 1.3), and fill the optional Settings rows you use (Step 1.2).
````

### C4 — Step 4.1: stale ID mapping sentence

**WRONG** [trace] · Low · line 606

The sentence says the kit calls the flows "F2 option A" and so on, then says the kit uses the same IDs. `kit/flows.md` line 36 says those are the names in older copies.

Guide text:

````
How the IDs map to `kit/flows.md`: F2a and F2b are the kit's "F2 option A" and "F2 option B". F4c is the kit's "F4 Standard fallback". F4d is the kit's file-arrival flow for SharePoint eSignature. The kit now uses these same IDs and includes F8, F9 and F10.
````

Replace with:

````
`kit/flows.md` uses these same IDs and includes F8, F9 and F10. Older copies of the kit called F2a and F2b "F2 option A" and "F2 option B", F4c "F4 Standard fallback", and F4d the file-arrival flow for SharePoint eSignature.
````

## What was checked and found OK

Counts come from a script over the guide: one "item" is an action row (or control property row) or a fenced expression.

| Part | Items checked | With a finding | OK |
| --- | --- | --- | --- |
| F7a | 2 | 0 | 2 |
| F1b, counter and both add-ons | 39 | 0 | 39 |
| F1a | 8 | 0 | 8 |
| F7b | 9 | 1 (A20) | 8 |
| F5, including the failure path | 18 | 1 (A13) | 17 |
| F8 | 14 | 1 (A17) | 13 |
| F2a and F2b | 20 | 1 (A18) | 19 |
| F3, both versions | 35 | 2 (A1, A15) | 33 |
| F4a and F4b, paths A and B | 50 | 5 (A2, A4, A5, A11, A11b) | 45 |
| F4c and F4d, paths C and D | 22 | 3 (A7, A8, A12) | 19 |
| F9 | 10 | 0 | 10 |
| F6 | 44 | 0 | 44 |
| F10 | 12 | 0 (A9b adds rows) | 12 |
| **Flows total** | **283** | **14** | **269** |
| Phase 6 formulas and property values | 55 | 4 (B1, B4, B5, B8) | 51 |
| Step 1.6 (6 steps, 5 group rows) | 11 | 0 | 11 |
| Phases 0 to 3, Steps 4.1 to 4.4, Phases 7 to 9: numbered steps, table rows and bullets | 365 | 10 (A6, A9, A9c, B1d, B1e, B1f, C1, C2, C3, C4) | 355 |

The remaining findings (16 in section A, 11 in section B) are against trigger settings, notes and step text, which the item counts above do not include.

Results of the specific checks asked for:

- **Action and trigger names.** Every SharePoint, Outlook, OneDrive, Forms, Approvals, Word Online, DocuSign and Adobe Acrobat Sign name in the guide exists on its connector page with that exact spelling, including **Create envelope (V2)**, **Add recipient to an envelope (V2)**, **Send envelope**, **Get documents from an envelope**, **Convert file**, **Run a Child Flow** and **Respond to a Power App or flow**. Two exceptions: the Adobe fallback action (A5b) and the unconfirmed label **Power Apps (V2)** (A21).
- **References between actions.** A script matched every `body()`, `outputs()`, `actions()`, `items()` and `variables()` reference in each flow to an action renamed to that name in the same flow: 129 references. It flagged one, `Populate_Filming` at line 1509, which reading resolves: the optional one-template-per-type note names that action in code format. Order of definition was checked by reading, including the inherited cases (F2b from F2a, F3 version 2, the path A and B closing actions, F4d from F4c).
- **Syntax.** Parentheses and quotes balance in every flow expression and in every replacement in this report.
- **Output names confirmed on a page:** `ItemId`, `Name`, `Id` and `Path` on **Create file**; `Id` on OneDrive **Create file**; `name`, `contentBytes` and `isInline` on mail attachments; `subject`, `from` and `attachments` on the shared-mailbox trigger; `outcome`, `responses`, `responder.email`, `comments` and `completionDate` on Approvals; `envelopeId` on **Create envelope (V2)**; `data.envelopeSummary.envelopeId` and `.status` on the DocuSign V3 trigger; `agreement.id` on the Adobe trigger; `transientDocumentId` and `id` on the two Adobe actions; `body/resourceData/responseId` on the Forms trigger; the **Since** field of **Get changes** accepting the trigger window start token. `{Link}`, `{Path}`, `{FilenameWithExtension}`, `{Identifier}` and `{IsFolder}` are not on any page (outputs are "dynamic"); they match product knowledge, and the guide already tests `{Link}` and `{Path}`.
- **Expression functions confirmed on the reference page:** `indexOf` is not case-sensitive, `contains` is, `dayOfWeek` gives Monday as 1, `max` accepts an array or a list, `addDays` takes an optional format, `union` removes duplicates.
- **Loops, Permits updates.** Every flow that updates a Permits item (F1b, F3, F4a, F4b, F4c, F5, F6, F10, and the app) was checked against the three item-modified flows. F2a acts only when **Get changes** reports Status changed; F5's own update puts `/Closed Projects/` in the path and fails its trigger condition; F7b writes only to AuditLog. No loop.
- **Loops, file triggers.** Every file-creating action (F1b folder, F3, F4b, F4c, F8, hand uploads, the F5 move) was checked against F9, F4c and F4d. F9 skips folders and files a flow has stamped; F4c's name conditions exclude everything a flow creates except the case in A12. Whether F5's folder move counts as "file created" is not documented for a move inside one library, so it is a tenant test (A23). F8 and F9 cannot start each other: F9 only updates properties, and F8 starts from mail.
- **Double-send guard (F4a).** Action 5 stops a second press once action 6 of the first run has written `PENDING`, about a second after the first press. It is not atomic: two presses inside that second both pass, and the Power Apps trigger offers no lock. That is an acceptable risk for one coordinator per permit; the appendix hardening list already has the confirmation prompt.
- **Reset on decline and reject.** Path A: the declined and voided cases clear **Signature Request Id** and **Permittee Signed** and return the status to `Draft Permit`, provided those events reach F4b (A3). Path B: no event; the coordinator resets the status, and regenerating the draft clears both fields (F3 action 16, or 15 in version 2). Path C: a rejection clears **Permittee Signed** and returns the status; **Signature Request Id** is never set on this path; the restart needs A7. Path D: by hand. A run of F4a that fails after `PENDING` is cleared by regenerating the draft, as the guide says. All of these rely on `null` clearing a column, which the guide already tests.
- **Null handling.** Every `empty()`, `int()`, `replace()`, `substring()`, `formatDateTime()` and `first()` argument was traced for null, wrong type and no rows. Findings: A1, A8, A11, A17, B8. One residual case: `replace()` on a blank Folder Path in F4a action 3, F4b action 7 and F4c action 8Y.2 fails the run, but a permit with a draft or a signed copy always has a folder.
- **OData filters.** All are valid. Free text that reaches a filter has its apostrophes doubled (F1a, F9, F10). F8's filter value is 13 characters cut from the subject and is not escaped, so a stray apostrophe fails that run and the email stays in the Inbox. `PermitId eq` on the lookup and the exact-date filters carry tenant tests in the guide.
- **Trigger conditions.** The seven conditions (F1b, F5, F2a, F4c twice, F9 twice) are valid, null-safe and each on its own row. A12 changes one.
- **Draft version (F3-B, F3-C, action 10).** Traced: no drafts gives v1; v1 and v2 give v3; deleting v1 still gives v3; a `_PermitteeSigned.pdf` is excluded by the `.docx` test; `max` over `union(..., createArray(0))` is valid for an empty list.
- **F4d.** See A24.
- **Connections and permissions.** Automated flows run on the service account's connections, so coordinators' Read on Settings, ConditionLibrary and AuditLog does not affect F1b's counter, F2a or any audit write. The app reads Settings (`Approvers`) and ConditionLibrary, which Read allows. App-started flows are covered in A6 and C1.
- **Licence statements.** Standard and Premium tiers, the per-person rule for app-started flows, the Process licence alternative, the Managed Environment rule, the 30-day run limit, the 90-day idle rule and Power BI Pro agree with `spec/facts.md` and the limits page. The limits page confirms the 120-second response limit used in A14 and A18.
- **Government notes.** The Adobe Acrobat Sign page excludes GCC High and DoD for Power Automate; the DocuSign page excludes only China. Both agree with the guide.
- **Step 1.6.** The site roles and the per-list grants in the table match `Provision-SUPSite.ps1` lines 424 to 453 exactly, including owners-only SUP Admin.
- **Names and counts.** All 57 internal column names agree across the guide, the script and `spec/data-model.md` (scripted). The six view names, five group names, flow IDs, "13 flows" and "12 flows" counts, and every step cross-reference resolve.
- **Sample data.** Recomputed from the CSVs at the anchor date: the Step 1.7 view results, F2a's nine conditions for permit 0012, and F6's six reminders are all correct.

## Where the guide and the kit disagree

The guide's flow sections and `kit/flows.md` are the same text: every expression in the guide's flow sections appears verbatim in the kit (scripted, 0 differences), and the kit has one expression the guide lacks. The disagreements are small.

| # | Guide | Kit | Which is right |
| --- | --- | --- | --- |
| 1 | Line 606: the kit calls the flows "F2 option A", "F4 Standard fallback" | `flows.md` line 36: those are names from older copies | Kit. See C4 |
| 2 | Line 228: create SUP Admin and *Changed this year* by hand "unless you ran the script" | `README.md` run order items 7 and 8: fill the optional Settings rows; upload the templates | Kit. See C3 |
| 3 | Line 870: "add rows `DefaultCoordinator` and `DefaultSuperintendent`" | `flows.md` line 306: "set the **Value** of rows … Add the rows if they are missing" | Kit. The guide's own line 868 says the script creates them |
| 4 | Step 1.2 gives no display name for `DefaultTermDays` | Script line 273: display name `Default Term (days)` | Neither is wrong; a hand-builder will not match the script |
| 5 | No mention | `flows.md` line 543: `body('Move_folder')?['{Link}']` as an alternative for Folder | Kit-only note, marked verify |
| 6 | No mention | `flows.md` line 1343: an hourly polling fallback for F4b; line 1174: the dates rely on `if()` evaluating one branch | Kit-only notes. The second is worth copying into the guide (see "Could not verify") |
| 7 | `spec/data-model.md` Settings keys | Guide and script add `NextSeq_` for next year, `Approvers`, `DefaultCoordinator`, `DefaultSuperintendent`; the library gains `_Templates` and SUP Admin | The data model is stale. It still calls itself the single source of truth |

Fixes in this report that the kit also needs: every pair in section A except A9c, which is guide-only text (`flows.md`); B1d (`Provision-SUPSite.ps1` and `README.md`, the `Editors` row); the count rule in `README.md` if A3's extra copies are built.

## Could not verify

Test each in the tenant. Items the guide already lists in Step 9.1 are not repeated.

1. Every item tagged `pk` above: A19 to A23, B3, B4, B5, B7 and B10, the option wording in A5c, and the `PermitNumber eq null` filter in A9b.
2. Whether `if()` evaluates only the branch it picks. The function reference says only "Parameters are evaluated from left to right". F3-A, F3-G and F1b-L depend on it. The guide's "blank Proposed End" test covers it; copy the kit's sentence (`flows.md` line 1174) into the guide so the builder knows why.
3. `int()` on a number, `concat()` with a null argument and `base64()` on binary content. The reference lists String parameters only. A1 avoids the first; F4c's audit Detail (line 1840) relies on the second; A2 relies on the third.
4. The DocuSign account-level trigger's payload and event names, and whether the V3 trigger's **Envelope event** accepts more than one value. The page lists neither. A3 gives both routes.
5. Adobe Acrobat Sign: whether the create action accepts a second participant, the Scope options, and which event reports a declined or cancelled agreement. The page has a trigger named **When the state of an agreement changes** ("Covers most common Agreement events") but lists no event names; it may give path B the declined event the guide says it lacks.
6. Whether **Update item** leaves unlisted fields unchanged. The connector page says nothing. F1b, F5, F6 and F10 re-send Status as a precaution, which is sound.
7. The options under **If another folder is already there** on **Move folder** (the page says only "Pick one of the options available"), and whether the file-created trigger fires for folders (F9 guards against it either way).
8. Whether a move inside the same library, or the SharePoint Migration Tool, starts the file-created trigger. Microsoft's statement is about moves between libraries. A9 includes a five-file test and A23 covers F5.
9. What happens to F1b runs beyond the waiting limit. The limits page gives "10 plus the degree of parallelism" waiting runs when concurrency control is on. More than 11 new permits inside a few seconds is unlikely, but a bulk paste of rows without permit numbers would reach it.
10. **Convert file**: the supported source formats and target types are on a linked page that was not opened. The connector page confirms the action, its two fields and that it returns file content.
11. In Power Apps: the display names of the library's built-in fields (the page lists the system fields as `Name`, `Link`, `FilenameWithExtension`), and whether the Permit Records library appears in the data picker or must be typed under **Enter custom table name**.
12. Phases 7 and 8 were checked for consistency only. Their product facts rest on the first report and `spec/facts.md`; those pages were not reopened.

## URLs opened

Pages were read through a fetch tool that truncates long pages; where a section was first returned as a summary, it was read again from an offset. Quotes in this report are from the text returned.

- https://learn.microsoft.com/en-us/connectors/docusign/ (read in two parts)
- https://learn.microsoft.com/en-us/connectors/adobesign/ (read in full, five parts)
- https://learn.microsoft.com/en-us/connectors/onedriveforbusiness/
- https://learn.microsoft.com/en-us/connectors/office365/ (the shared-mailbox trigger's parameter table came back as a summary; the definitions and both send actions were verbatim)
- https://learn.microsoft.com/en-us/connectors/sharepointonline/ (read in two parts)
- https://learn.microsoft.com/en-us/sharepoint/dev/business-apps/power-automate/sharepoint-connector-actions-triggers
- https://learn.microsoft.com/en-us/connectors/approvals/
- https://learn.microsoft.com/en-us/connectors/microsoftforms/
- https://learn.microsoft.com/en-us/connectors/wordonlinebusiness/
- https://learn.microsoft.com/en-us/azure/logic-apps/expression-functions-reference
- https://learn.microsoft.com/en-us/power-automate/limits-and-config (first half verbatim)
- https://learn.microsoft.com/en-us/power-automate/create-child-flows
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/working-with-flows
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/app-from-sharepoint
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/share-app
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/save-publish-app
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/connections/connection-sharepoint-online
- https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-gallery
- https://learn.microsoft.com/en-us/power-platform/power-fx/reference/function-datasourceinfo
- https://learn.microsoft.com/en-us/power-platform/admin/environments-overview (opened; says nothing about SharePoint-generated apps)

## Overall verdict

**Buildable by a first-time builder: yes, with the listed fixes.** Apply the 43 WRONG and INCOMPLETE pairs to the guide, and the flow ones to `kit/flows.md` as well. Add the `Editors` row to the script. Run the 12 VERIFY tests in the test site alongside the guide's own Step 9.1 list. Paths A and B need the most care: their connector actions are confirmed by name, but the trigger payloads and the second signer are still tenant tests.
