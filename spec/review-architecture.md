# SUP System — Architecture Review

Reviewer: independent M365 / Power Platform architect. Reviewed: `spec/data-model.md` (line refs as `L#`). Date: 2026-11-23.

## Verdict

SharePoint lists + Power Automate is the right platform call. Volume is small, the "stay in SharePoint" constraint is explicit, and Dataverse / Power Pages would add premium licensing (per staff user for Dataverse apps, capacity-based for Power Pages **[T — get a licensing quote before ruling it in or out]**) and move the system of record out of SharePoint. What lists do not give you: transactions, enforced state transitions, real row-level security, and a tamper-evident audit trail. The design must compensate for each of those explicitly; today it does not.

The data model is a reasonable first draft, but **it should not be frozen yet**. Three headline features (external intake with attachments, permit generation, e-signature) depend on licensing and tenant facts nobody has confirmed, and the model hard-codes one answer to each. Fix items 1–5 below before building anything.

Evidence labels: **[V]** = checked against Microsoft/vendor documentation today (sources at end). **[T]** = not confirmed; the one-line tenant test is given.

## Top 10 changes (ranked)

### 1. Intake: Microsoft Forms cannot take attachments from outside applicants
**Problem.** `SourceSubmissionId` = "Forms response id" (L54) commits to Forms. The file-upload question only works when the form is restricted to people inside the organisation; adding one disables "Anyone can respond" **[V — consistent Microsoft Q&A moderator answers; no official Learn page found. Test: add an upload question, look at the sharing options]**. Applications need site plans and COIs. An anonymous form also has no identity check or spam control, and government tenants often disable external Forms sharing entirely **[T — ask the M365 admin]**.

**Do.**
- Split intake into data and files. A group-owned Form (not a personal one) captures fields only. The flow creates the record and folder, then emails the applicant from the shared mailbox: "reply with your attachments, keep `[SUP-2026-0042]` in the subject". A second flow on the shared mailbox files attachments into the permit folder by permit number; unmatched mail lands in a triage view.
- Add `IntakeChannel` (Choice: Online form, Email, Staff entry) and keep `SourceSubmissionId` as a generic source reference. Staff entry must create an identical record, because it is the fallback if external Forms is blocked.
- Power Apps is not an external-intake option: a canvas app requires the user to sign in to the tenant, so applicants would need guest accounts. Use it only for the staff-entry path, as a customised SharePoint list form (standard connector, covered by seeded licences).
- Do not adopt Power Pages unless the customer funds Dataverse and accepts leaving SharePoint.

### 2. E-signature: no guaranteed native option, and the model cannot represent a real signing process
**Problem.** L46–47 and L52 give two dates and an id. There is no declined / voided / expired state, no link to the signed file, and no record of who actually signed. `Superintendent` as a per-item Person column (L43) ignores acting officials.
- SharePoint eSignature is documented as a public-cloud service; nothing found confirms GCC **[V for "public cloud"; T for GCC — check whether the eSignature setting exists in the M365 admin center]**. It is pay-as-you-go (needs an Azure subscription), and outside signers become Entra B2B guests, so guest sharing must be enabled **[V]**. Conditional access can stop an outside signer; forum reports say the failure is silent **[T]**. PDF-only, and whether a flow can start a request, are unconfirmed **[T — try both on a test file]**.
- DocuSign connector: Standard tier, listed for GCC / GCC High / DoD **[V, page is old]**. Adobe Acrobat Sign Government connector: GCC only, not GCC High, user-level connections only, no web-form trigger **[V]**; its tier is unconfirmed **[T]**. Both need a separately purchased (FedRAMP, if government) e-sign subscription, and tenant DLP policy often blocks third-party connectors **[T]**.

**Do.**
- Customer picks the provider first (see Decisions). Send one envelope with signing order 1 = permittee, 2 = official; never two separate requests.
- Keep one fact in one place. `Status` says whose turn it is (`Out for Permittee Signature`, `Out for Superintendent Signature`, `Executed`). A new `SignatureStatus` (Choice: Not sent, In progress, Completed, Declined, Voided, Expired) holds only the envelope outcome. Both are written by the provider-event flow, never by hand.
- Add `SignatureSentDate`, `ExecutedFileUrl`, `SigningOfficialName`, `SigningOfficialTitle` (text, captured at signing). Put the default approving official in `Settings`; keep `Superintendent` as a per-permit override.
- Zero-licence fallback: permittee returns a signed PDF by email; the official signs with a certificate/PIV in Acrobat or via a Power Automate approval. Counsel must confirm an approval counts as a signature.

### 3. Document generation is a premium action, and `TemplateFile` as a text path is fragile
**Problem.** "Populate a Microsoft Word template" is in the Word Online (Business) connector, which is Premium **[V]**. Microsoft 365 seeded licences include standard connectors only **[V]**. Separately, when the template file is chosen dynamically (L64 stores a path per type), the action cannot show named fields; you must pass raw content-control IDs, which change whenever someone re-creates a control **[T — from experience, not re-checked; pick the template through dynamic content and see whether named fields remain]**.

**Do.**
- Preferred: one Power Automate Premium licence on the service account that owns the flows **[T — confirm with the licensing rep that owner-licensing covers this automated flow]**. Use a `Switch` on permit type with a statically selected template per branch, and a repeating content control for conditions.
- No-premium fallback: flow copies the template into the folder and sets library columns; the template shows them through Quick Parts bound to those columns. Conditions arrive as one plain-text block. It is uglier; say so to the customer.
- Store templates in a dedicated `PermitTemplates` library with versioning, and reference them by item, not a typed path.
- Drop `DraftPermit_v{n}` (L15); library versioning already does this, and two version schemes will disagree.

### 4. Ownership and ALM: as written, the system dies with the builder
**Problem.** Nothing in the model covers environment, solution, ownership or monitoring. Flows whose owner leaves become orphaned and fail when their connections die **[V]**. Flows not triggered for 90 days are switched off when the owner has no premium licence, and an unused SharePoint connection expires after 90 days **[V]**. Failure emails go to the owner only.

**Do.**
- A licensed, non-personal service account owns every flow, connection, the Form (group form), and has Send As on the shared mailbox. Program lead + IT are co-owners. Agree with IT up front how MFA and password rotation apply to it; each forced reset breaks every connection.
- Build in a solution, in a non-default environment if IT allows **[T — a solution needs Dataverse in the environment; confirm seeded licences are acceptable there]**. Use connection references and environment variables for site URL, list names and mailbox. L7 hard-codes `.sharepoint.com`; GCC High is `.sharepoint.us`, and the maker portals differ per cloud.
- Script the site (PnP provisioning template) and keep a test site, `/sites/SpecialUsePermits-Test`.
- Every flow: try/catch scope writing to a `FlowErrors` list plus an email to the program lead. No flow may run less often than monthly (so no once-a-year rollover flow).
- Deliver a runbook: add a permit type / condition / template, change the approving official, re-authenticate connections, recover a failed run.
- Other single points of failure to remove: sole site owner, report in a personal Power BI workspace, templates in personal OneDrive, e-sign account in one person's name, the builder's address hard-coded in flows.

### 5. Permissions: "Edit" is too much, config lists are unprotected, and sensitive content is unaddressed
**Problem.** L8 gives Coordinators **Edit**, which includes Manage Lists: they can delete lists, change columns, and edit `Settings` (the counter), `ConditionLibrary` (legal wording) and `AuditLog`. "Read + sign" is not a SharePoint permission. Nothing addresses archaeological site locations (legally protected from disclosure in many jurisdictions) or applicant PII / tax IDs.

**Do.**
- Coordinators get **Contribute**, not Edit. Break inheritance at list level only: `Settings`, `Counters`, `AuditLog`, `ReminderLog` = service account writes, everyone else reads. `ConditionLibrary` = a named steward group writes, with versioning on.
- Never use per-item or per-permit-folder unique permissions. One allowed exception: a single break on the `Closed Projects` top folder making it read-only for coordinators.
- Sensitive documents go in a second library, `PermitRecordsRestricted`, with its own group. Do not collect tax IDs through the public form.
- No external user gets site access. The e-sign provider and email are the only external surfaces.
- If the customer truly needs "coordinator A cannot see coordinator B's permits", lists are the wrong platform. Ask now.

### 6. Permit numbering has a race and no rollover
**Problem.** `NextSeq_2026` in `Settings` (L92) is read-increment-write on a text value. Two near-simultaneous submissions get the same number. There is no path to 2027, and "year of receipt" computed with `utcNow()` is wrong on the evening of 31 December.

**Do.**
- New list `Counters`: `Title` (year key), `NextSeq` (Number).
- The mechanism is a conditional update, not locking. The flow gets or creates the row for the year, then increments it through "Send an HTTP request to SharePoint" with an `If-Match` header carrying the row's ETag. A conflict returns 412; loop and retry (maximum 5). Assign the number in the same run that creates the Permits item (or, for staff-entered items, first processes it).
- Keep the unique index on `PermitNumber` (L26) as the backstop; on a duplicate error, retry.
- Optional hardening: set trigger concurrency to 1 on the intake flow. This cannot be switched off later. If the build ends up in a solution (item 4), move the allocation into one shared child flow.
- Derive the year from `ReceivedDate` in the site's time zone. Add `PermitYear` and `PermitSeq` (Number) for sorting and reporting.
- Customer decides calendar vs fiscal year, and how legacy numbers from the Excel tracker are preserved; seed the counter above the legacy maximum.

### 7. Folders: unstable names, a destructive move, and documents not actually tied to records
**Problem.**
- The folder name embeds applicant and location (L12). Both change; renames break every link.
- The move to `Closed Projects` invalidates `FolderUrl`, `FolderPath`, `ComplianceItems.EvidenceUrl` (L86), audit details and every link already emailed. A move fails part-way if anyone has a file open.
- The library's `PermitNumber` is plain text (L20), so documents are joined to records by a typed string.

**Do.**
- Folder name = `{PermitNumber}` plus an applicant short name frozen at creation. Never rename. Applicant and location belong in columns.
- Add a `Permit` lookup column (→ Permits) to the library. A flow stamps `Permit` and `PermitNumber` on every file from its parent folder. Enforce the file-naming rule only on flow-generated files; rely on `DocType` metadata for human uploads.
- `Status` is the source of truth. The move is a separate, idempotent step: add `FolderMoveState` (Choice: Pending, Done, Failed) and a daily sweeper that retries any closed permit still under `Open Projects`.
- Turn on the Document ID feature and store Document ID links, which survive moves **[T — move a test file between the two folders and open its Document ID link]**.
- Tell the customer plainly: views filtered on status give the same Open / Closed experience with none of this risk. They asked for the move, so it is their call.

### 8. Audit trail and records retention: the `AuditLog` list is not an audit trail, and retention is absent
**Problem.** `AuditLog` (L88–89) is an ordinary list. Site owners and the flow account can edit or delete rows. A "modified" trigger does not say what changed, and merges rapid edits into one run. The model has no retention or records design at all, though executed permits are official records.

**Do.**
- Call `AuditLog` an **activity log**. The authoritative trail is: list and library version history, the Purview unified audit log, and the e-sign provider's completion certificate saved beside the executed PDF. If tamper-evidence is a hard requirement, no SharePoint list can meet it.
- Use the "Get changes for an item or a file" action for field-level entries. Add `FieldName`, `OldValue`, `NewValue`, `Source` (User / Flow), `FlowRunId`.
- Set explicit version limits on `Permits` and `PermitRecords`; tenant automatic version trimming can otherwise delete history **[T — check the tenant version-history setting]**.
- Retention: the records officer names the schedule. Manual retention labels work on E3/G3; auto-apply policies need E5/G5 **[V]**. Event-based retention ("N years after permit closes") and record declaration are reported as E5/G5 **[T — check Microsoft's compliance licensing guidance]**. Apply the label in the close flow **after** the move and after final metadata is written, because a record label blocks later edits. Minimum fallback: a site-level retention policy.
- The Permits item and its log rows need the same retention as the documents.

### 9. Reminders: dedupe design is fragile and will send wrong or duplicate mail
**Problem.** `LastReminderKey` (L53) is a 255-character string that grows every time a date changes. Writing it back modifies the Permits item, which re-fires "item modified" flows and pollutes version history. "Exactly N days before" logic misses reminders after any outage. Date-only columns come back as UTC and produce off-by-one days.

**Do.**
- Replace it with a `ReminderLog` list: `Permit` (lookup), `ReminderType` (Choice), `ThresholdDays`, `TargetDate`, `SentTo`, `SentTime`, and `DedupeKey` (single line, **enforce unique**) = `{PermitId}|{type}|{threshold}|{targetDate}`. Create the row first; if the create fails as a duplicate, do not send. This survives retries and double runs.
- Logic is "due and not yet sent": send only the nearest unsent threshold, so an outage does not produce three catch-up emails. A changed target date naturally produces new keys.
- Stop conditions by status: no reminders once closed; start-date reminders only before execution; COI reminders only while active.
- Set the recurrence time zone explicitly and compare dates as `yyyy-MM-dd` in site-local time. Filter in the query, not in a loop: the seeded licence allows about 6,000 actions per day **[V]**.
- COI history: add `DocExpiration` (Date) on the library for COI files; treat `Permits.COIExpiration` as the current value copied from the newest COI.

### 10. Status model and condition engine
**Problem.**
- `Active – Compliance Monitoring` (L57) contains an en dash. Filters, switch cases and Power BI measures typed with a hyphen will silently not match.
- Missing states: returned incomplete, expired, revoked/suspended. `Withdrawn` and `Denied` are statuses, though they are really reasons for closing. Transitions are unenforced; anyone with edit rights can set `Executed`. No link for renewals or amendments.
- "Under Review" is one status with no per-discipline review tracking, yet reviewers are who confirm the conditions. "Compliance staff" may mean environmental/cultural reviewers before issuance, not post-permit monitoring as the model assumes.
- Impact tags are defined three times (L60: two lists, plus the form) and matched by label. `Near stream, river or wetland` contains commas.
- The rule (L80) is a single-tag OR. It cannot express seasonal windows (bat roosting season) or parameters (buffer width).

**Do.**
- Statuses: `Received`, `Returned Incomplete`, `Under Review`, `Draft Permit`, `Out for Permittee Signature`, `Out for Superintendent Signature`, `Executed`, `Active`, `Expired`, `Closed`. Add `CloseReason` (Choice: Completed, Expired, Withdrawn, Denied, Revoked), `StatusChangedDate`, `ParentPermit` (lookup → Permits), `ActionType` (Choice: New, Renewal, Amendment). A flow logs and reverts illegal transitions.
- Add a `Reviews` list (Permit, ReviewType, Reviewer, Status, DueDate, Determination) if the customer confirms pre-issuance reviews.
- Impacts: one site column used by both lists, labels without commas or parentheses, and an explicit form-answer → tag mapping in the flow.
- Keep the rule simple but honest: suggestions are advisory. Add `ConditionsReviewedBy` / `ConditionsReviewedDate` on Permits; conditions need a human accept step before the draft is generated. Use fill-in tokens (`{{BufferFeet}}`, `{{ClearingWindow}}`) in `ConditionText`, and add `GuidanceNote`, `Owner`, `LastReviewed`, `Authority` to `ConditionLibrary`.
- Re-suggestion after `Impacts` changes must upsert on (Permit, Condition), never overwrite staff-edited text or staff-added rows, flag rather than delete conditions no longer triggered, and stop once the permit is out for signature. Never delete a library condition; set `Active` = No.

## Smaller fixes

- **Indexes, created with the lists.** Permits: `Status`, `PermitExpiration`, `COIExpiration`, `ProposedStart`. `PermitConditions.Permit`, `ComplianceItems.Permit` and `DueDate`, `AuditLog.PermitId` and `EventTime`, library `Permit` and `DocType`. `PermitConditions` and `AuditLog` grow by tens of rows per permit and are the first to pass 5,000; at a few hundred permits a year that happens in year one.
- `Latitude / Longitude` (L36) is two columns; define both, six decimals.
- Multi-choice and multi-lookup columns (`Impacts`, `AppliesToTypes`) cannot be filtered server-side; filter in the flow.
- **Dashboard.** Power BI needs a Pro licence per viewer and is not part of E3/G3 **[T — check the licences assigned to the intended viewers]**; data is refreshed on a schedule, not live. Phase 1: a SharePoint page with formatted list views and chart web parts. Add Power BI only if every viewer is licensed.
- Fees, bonds and cost recovery are not modelled. Ask.
- **Migration.** There is no plan for the existing Excel tracker and Open/Closed folders. Decide: full backfill, open permits only, or start clean.

## Coverage of the questions asked

| Topic | Where |
|---|---|
| Lists vs Dataverse | Verdict |
| Forms vs Power Apps vs Power Pages | 1 |
| E-signature options | 2 |
| Document generation | 3 |
| Numbering concurrency | 6 |
| Reminder dedupe | 9 |
| Audit trail integrity | 8 |
| Permissions / item-level security | 5 |
| Folder move vs metadata views | 7 |
| Retention / records | 8 |
| Scale | Smaller fixes (indexes), 9 (action limits) |
| GCC gotchas | 1, 2, 4, Smaller fixes (Power BI) |
| ALM, environment, service account | 4 |
| Builder leaves | 4 |

## Decisions the customer must make up front

1. **Tenant and licences.** Commercial, GCC or GCC High? E3/G3 or E5/G5? Any Power Automate Premium or Power BI Pro? Is there an Azure subscription?
2. **Who submits applications.** Applicants directly through a public form, or staff keying in what arrives by email? Is external Forms sharing permitted?
3. **Mandated forms.** If this is a federal unit, are the application and permit fixed agency forms (for example NPS Forms 10-930 / 10-114 — confirm), and do paperwork, accessibility and privacy rules apply to a public form?
4. **E-signature.** Which tool is approved and already paid for? Must the official sign with a PIV/CAC certificate? Will counsel accept a workflow approval as a signature?
5. **Literal folder move or status-driven views** for Closed Projects.
6. **Records.** Which retention schedule applies, what starts the clock, and who is the records officer?
7. **Roles.** Who is "compliance staff" — pre-issuance reviewers or post-permit monitors? Who owns condition wording? Who signs when the Superintendent is away?
8. **Visibility.** May every coordinator see every permit? Which content is sensitive?
9. **Numbering.** Calendar or fiscal year; treatment of legacy numbers.
10. **Ownership.** Will IT provide a service account, an environment and a DLP exception for the e-sign connector? Who maintains the system after the builder?
11. **Migration scope** for existing permits.

## Impact on the "frozen" model

| Change | Type |
|---|---|
| Rename `Active – Compliance Monitoring`; add statuses; move Withdrawn/Denied to `CloseReason` | Breaking |
| Folder naming rule; drop `DraftPermit_v{n}` | Breaking |
| Impact tag labels; single site column | Breaking |
| `LastReminderKey` → `ReminderLog` list | Breaking |
| `NextSeq_2026` → `Counters` list | Breaking |
| Coordinators Edit → Contribute; list-level breaks | Breaking (permissions) |
| `TemplateFile` path → `PermitTemplates` library reference | Breaking |
| New Permits columns (`IntakeChannel`, `SignatureStatus` (envelope outcome only), `SignatureSentDate`, `ExecutedFileUrl`, `SigningOfficialName`, `SigningOfficialTitle`, `CloseReason`, `StatusChangedDate`, `ParentPermit`, `ActionType`, `FolderMoveState`, `PermitYear`, `PermitSeq`, `ConditionsReviewedBy`, `ConditionsReviewedDate`) | Additive |
| Library columns `Permit` (lookup), `DocExpiration`; `PermitRecordsRestricted` library | Additive |
| New lists `Reviews`, `FlowErrors`; extra `AuditLog` and `ConditionLibrary` columns; indexes | Additive |

## Sources checked

- Forms external file upload: [Microsoft Q&A 5608206](https://learn.microsoft.com/en-us/answers/questions/5608206/file-upload-option-is-greyed-out-when-anyone-can-r), [Tech Community thread](https://techcommunity.microsoft.com/discussions/microsoftforms/file-upload-option-not-available-for-external-users-/4388010)
- SharePoint eSignature: [overview](https://learn.microsoft.com/en-us/microsoft-365/syntex/esignature-overview), [setup](https://learn.microsoft.com/en-us/microsoft-365/syntex/esignature-setup)
- Word template action tier: [Word Online (Business) connector](https://learn.microsoft.com/en-us/Connectors/wordonlinebusiness/)
- DocuSign connector: [connector page](https://learn.microsoft.com/en-us/connectors/docusign/), [connector list](https://learn.microsoft.com/en-us/connectors/connector-reference/connector-reference-powerautomate-connectors)
- Adobe Acrobat Sign Government connector: [Adobe guide](https://helpx.adobe.com/sign/using/sign-power-automate-integration.html)
- Retention labels: [publish and apply](https://learn.microsoft.com/en-us/purview/create-apply-retention-labels), [declare records](https://learn.microsoft.com/en-us/purview/declare-records)
- Orphaned flows: [Microsoft troubleshooting article](https://learn.microsoft.com/en-us/troubleshoot/power-platform/power-automate/flow-management/manage-orphan-flow-when-owner-leaves-org)
- Licence limits and 90-day rules: [licence types](https://learn.microsoft.com/en-us/power-platform/admin/power-automate-licensing/types), [licensing FAQ](https://learn.microsoft.com/en-us/power-platform/admin/power-automate-licensing/faqs), [flow limits](https://learn.microsoft.com/en-us/power-automate/limits-and-config), [Get items guidance](https://learn.microsoft.com/en-us/sharepoint/dev/business-apps/power-automate/guidance/working-with-get-items-and-get-files)
