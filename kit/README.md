# SUP Provisioning Kit

> ## ⚠️ UNTESTED: validate in a test site first
> Nothing in this kit has been run against a live Microsoft 365 tenant. The PowerShell script passes a PowerShell 7 syntax parse, its PnP cmdlets and parameters were checked offline against PnP.PowerShell 3.5.0, and it was run against stand-ins for the PnP cmdlets. The CSVs and JSON parse. **No cmdlet, flow action or formatter has been executed in SharePoint.** Every **verify** and *Test in your tenant* note in `flows.md` still stands.
>
> First run: use `-SiteAlias SUP-Test -ImportSamplePermits` and work through the "Validate" checklist below. Only then run it against `SpecialUsePermits`.

All names come from `spec/data-model.md`. Do not rename lists or columns: the internal names are fixed at creation, and the flows and app depend on them.

The step-by-step build guide is `docs/build-guide.md`. This kit uses the same list, view, flow and action names. Where the two differ, the guide is the source of truth.

## Files

| File | What it is |
|---|---|
| `Provision-SUPSite.ps1` | Creates the communication site, 7 lists, the `PermitRecords` library with its three folders, the owners-only `SUPAdmin` library (display name **SUP Admin**, for solution backups), the five groups and permissions, the indexes, the six Permits views, the *Changed this year* view on ConditionLibrary and the column formatting. It seeds Settings, PermitTypes and ConditionLibrary, and optionally imports sample permits. Idempotent, and supports `-WhatIf`. |
| `PermitTypes-seed.csv` | The 6 permit types, with template path, default term and prefix. |
| `ConditionLibrary-seed.csv` | 24 generic sample conditions. `AppliesToTypes` and `TriggerImpacts` are `;`-separated; a blank `AppliesToTypes` means all types. **Have program staff and the agency biologist and archaeologist review every condition before use.** WLD-01 has date placeholders on purpose. |
| `Permits-sample.csv` | 12 fictitious permits covering all 10 statuses. Dates are relative to 2026-11-23, and the script shifts them to today. Test sites only. |
| `formatting/status-pill.json`, `formatting/date-overdue.json`, `formatting/date-start.json` | Column formatters, applied by the script. `date-start.json` (Proposed Start) only colours permits that are not yet executed. |
| `list-views.md` | View definitions (CAML plus UI equivalents) for the six Permits views and the ConditionLibrary view, and the formatting JSON. |
| `flows.md` | Action-by-action build sheets for every flow: F7a, F1b, F1a, F7b, F5, F6, F8, F2a, F2b, F3, F4a to F4d, F9 and the one-time F10. Same flow IDs, flow names, action names and expressions as the build guide. |

## The flows

Count rule, the same as the build guide: **13 flows** stay switched on when you use an e-signature connector (DocuSign or Adobe Acrobat Sign). Both F2 flows count. F10 runs once at migration and is not counted. With no e-signature service (path C), F4c replaces F4a and F4b, so 12 flows stay on. With SharePoint eSignature (path D), the optional F4d replaces them.

| ID | Flow name | What it does |
|---|---|---|
| F7a | `SUP – Write Audit` | Child flow: writes one AuditLog row. Every other flow calls it |
| F1b | `SUP – Number, Folder, Notify` | Numbers each new permit, creates its folder, emails the coordinator |
| F1a | `SUP – Form to Permits Item` | Turns a Forms response into a Permits item |
| F7b | `SUP – Status Changed Logger` | Logs each status change, old and new |
| F5 | `SUP – Close Permit` | Moves a closed permit's folder to Closed Projects |
| F6 | `SUP – Daily Reminders` | Daily digest: permit expiry, COI expiry, start date near and not executed |
| F8 | `SUP – Mailbox Attachments` | Files attachments from the shared mailbox into the permit folder |
| F2a | `SUP – Suggest Conditions (status)` | Suggests conditions when a permit goes to Under Review |
| F2b | `SUPSuggestConditions` | The same, from the app's button |
| F3 | `SUPGenerateDraft` | Creates the draft permit (standard version 1, Premium version 2) |
| F4a, F4b | `SUPSendForSignature`, `SUP – Signature Callback` | Paths A and B: send to DocuSign or Adobe Acrobat Sign, record the result |
| F4c | `SUP – Signed Upload and Approval` | Path C: permittee-signed upload, then an approval |
| F4d | `SUP – Signed Copy Arrived` | Path D, optional: records the SharePoint eSignature signed copy |
| F9 | `SUP – Stamp Permit Number` | Stamps the permit number on files people upload |
| F10 | `SUP – Migration Folder Match` | Run once at migration: links migrated folders to permits |

The three names without spaces matter: the app calls those flows by name.

## Prerequisites
1. **PowerShell 7.4 or later** and **PnP.PowerShell 3.x**: `Install-Module PnP.PowerShell -Scope CurrentUser`. Cmdlet and parameter names were checked offline against PnP.PowerShell 3.5.0.
2. **SharePoint Administrator** rights for the person running the script, because the site is created through the admin endpoint.
3. **Your own Entra ID app registration.** PnP's shared multi-tenant app was retired in September 2024. Run this once, with an admin consenting:
   ```powershell
   Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "SUP Provisioning" -Tenant contoso.onmicrosoft.com
   ```
   Pass the resulting Application (client) ID as `-ClientId`.

   **Government clouds:** add `-AzureEnvironment` to that command and pass the same value to the script: `USGovernment` (GCC), `USGovernmentHigh` (GCC High) or `USGovernmentDoD` (DoD). GCC tenants still use `.sharepoint.com` URLs, so the script cannot tell the cloud from the URL. For example:
   ```powershell
   Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "SUP Provisioning" -Tenant contoso.onmicrosoft.com -AzureEnvironment USGovernment
   ./Provision-SUPSite.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId <guid> -OwnerEmail you@contoso.com -AzureEnvironment USGovernment -SiteAlias SUP-Test -WhatIf
   ```
4. **A service account for flows**, for example `svc-sup-flows@agency`, with a licence, a mailbox and a OneDrive. It owns the solution, every connection, every flow, the form and the app. Ask IT to exempt it from interactive multi-factor prompts, and to give it **Full Access** and **Send As** on the shared mailbox.
5. **Licensing** (the same rules as the build guide's "Who needs Premium"):
   - Word Online (Business) is the only Premium connector. Only F3 version 2 (*Populate a Microsoft Word template*) needs it as built. F4a converts to PDF with Standard OneDrive actions; the Word Online *Convert Word Document to PDF* action is only the alternative.
   - A flow started from the app is licensed per person who runs it. For F3 version 2 (and F4a with the alternative PDF action), either every coordinator who runs it needs Power Apps Premium, or the flow carries one Power Automate Process licence. A Premium licence on the service account alone does not cover it; one licensed account shared by many users is not compliant.
   - If neither is in budget, use F3 version 1. It needs one manual paste of conditions per permit.
   - Every other flow, the app and the site run on standard Microsoft 365 licences.
   - Ask IT whether the environment is a **Managed Environment**. If it is, everyone who runs a flow needs Premium, even with standard connectors.
   - E-signature, by cloud:
     - **DocuSign (path A):** Standard connector; commercial, GCC, GCC High and DoD. The only connector listed for GCC High and DoD. Needs a DocuSign licence.
     - **Adobe Acrobat Sign (path B):** Standard connector; commercial and GCC only. Needs an Acrobat Sign licence.
     - **Signed upload plus Approvals (path C):** Standard. Approvals is not a legal e-signature; confirm with counsel.
     - **SharePoint eSignature (path D):** $2 per request (pay-as-you-go, billed to an Azure subscription), PDF only, no Power Automate action or trigger. Documented for the commercial cloud only; treat it as unavailable in government clouds.
   - Power BI: Pro for every person who views the report.

## Run order (setup script)
1. `./Provision-SUPSite.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId <guid> -OwnerEmail you@contoso.com -SiteAlias SUP-Test -WhatIf`. This is a dry run: create steps are reported but not performed. On a new alias the site does not exist yet, so the dry run previews only the site creation line and stops; on an existing site it previews every step.
2. Run the same command without `-WhatIf`. Read the summary; any `FAIL` lines are listed at the end, and the script exits with code 1.
3. Set **Site settings → Regional settings → Time zone** to the office time zone. Do this *before* importing samples, because date-only values can shift a day if the site time zone is wrong.
4. *(Test site only)* Re-run with `-ImportSamplePermits`. The script is idempotent, so existing objects are skipped.
5. > **⚠️ Add the flow service account to SUP Owners. The script does not do this.** Select the gear, then **Site permissions → Advanced permissions settings → SUP Owners → New → Add users**. Without it, F1b fails at *Update item Settings* (the permit number counter) and every audit write fails with error 403. `-OwnerEmail` is added to SUP Owners, but that is a person, not the service account.
6. Add people to the other four groups: SUP Coordinators, SUP Compliance, SUP Approving Officials and SUP Viewers. Use one Entra security group per role. Empty or remove the communication site's two default groups, "*Special Use Permits* Members" and "*Special Use Permits* Visitors". ComplianceItems, Permit Records, AuditLog, Settings, ConditionLibrary and SUP Admin no longer inherit from them, but the site does.
7. Fill the optional Settings rows if you use them: `Approvers` (approving officials' emails, separated by `;` with no spaces; read by the app) and `DefaultCoordinator`, `DefaultSuperintendent` (one email each; F1b add-on A). The script creates all three blank, or with the values of `-Approvers`, `-DefaultCoordinator` and `-DefaultSuperintendent` on the run that first creates them. Later runs skip rows that exist, so after that edit the rows in the Settings list.
8. Upload the Word templates to `Permit Records/_Templates`. If your file names differ from `PermitTypes-seed.csv`, fix `PermitTypes.TemplateFile`.
9. Work through "Validate (test site)" below, then build the flows in the order of the next section.

For production, run without `-SiteAlias` and without `-ImportSamplePermits`, and pass `-ProgramMailbox` with the real shared mailbox address. If the test site itself becomes production, delete the sample items, folders and AuditLog rows, and set this year's `NextSeq_<year>` row back to `1`.

## Build order: delivery stages

Build in the build guide's six delivery stages. Each stage leaves a system staff can use, and you can go live after stage 1. Within a stage, build the flows in the order listed (the "Build order" column in `flows.md`).

| Stage | What you build | Flows | Licence |
|---|---|---|---|
| 1. Minimum working system | Site, lists, views and permissions (this script). The form. | F7a → F1b → F1a → F7b → F5 → F6 → F8 | Standard |
| 2. Conditions | The tagged condition library | F2a | Standard |
| 3. Draft permit | Standard-licence version first, then the Premium version | F3 | Standard, then Premium |
| 4. Signatures | The one signature path you chose | F4a and F4b (paths A, B), or F4c (path C), or F4d (path D, optional) | Standard, plus the e-signature service |
| 5. Coordinator app | The Power Apps app | F2b, F9 | Standard |
| 6. Reporting | The Power BI report | none | Power BI Pro per person |

After stage 1, staff can run the program on list views and list forms. F10 is built and run once during migration (build guide Step 9.3), then deleted.

## Validate (test site)
- [ ] All lists and both libraries (Permit Records, SUP Admin) exist, and their column **internal** names match the spec. Check List settings → click a column → the URL shows `Field=<InternalName>`.
- [ ] `Status` shows 10 choices. `Impacts` and `TriggerImpacts` show 10 choices each.
- [ ] ConditionLibrary has 24 rows. OPS-04 shows two Applies To Types; WAT-01 shows five. Its *Changed this year* view exists.
- [ ] Settings has `ReminderDaysPermitExpiry`, `ReminderDaysCOI`, `ReminderDaysStartUnexecuted`, `ProgramMailbox`, `NextSeq_<this year>`, `NextSeq_<next year>`, `Approvers`, `DefaultCoordinator` and `DefaultSuperintendent`.
- [ ] Each view returns what `list-views.md` says it should. With the samples:
  - "Expiring in 60 days" shows 0005, 0006 and 0007.
  - "COI expiring" shows 0006 and 0007.
  - "Unexecuted, start within 30 days" shows 0009 and 0010.
  - "Closed in last 365 days" shows 0001–0004 (Closed, Withdrawn and Denied all count as closed).
  - Proposed Start is red or amber only on unexecuted permits (0009, 0010); Executed, Active and closed permits show it uncoloured.
- [ ] Permissions:
  - A SUP Compliance member can edit ComplianceItems and upload to Permit Records, but cannot edit Permits.
  - A coordinator cannot edit AuditLog, Settings or ConditionLibrary, and cannot open SUP Admin.
  - **The flow service account is in SUP Owners.** The script does not add it; without it F1b fails at *Update item Settings* and every audit write fails with 403.
  - The two default site groups are empty.
- [ ] F1b: create two items within a few seconds of each other. They must get consecutive numbers with no duplicates. Sample permits (imported with a number) must not be renumbered.
- [ ] Condition rule on the samples. Run F2b with **Test → Manually** on each sample's ID; it applies the same rule as F2a at any status, so the samples keep the statuses the view and F6 checks need. (To test F2a itself, use a new permit, or set a sample back to its original status afterwards.) Every permit gets the six standard conditions (GEN-01–04, INS-01–02). 0005 adds only OPS-05 (7 total); 0011 adds SAF-03 and OPS-05 (8); 0012 adds WAT-01, SAF-01 and SAF-02 (9), and no WAT-02; 0006 adds SOI-03, WAT-02, OPS-03 and OPS-06 (10). A second run adds no duplicates.
- [ ] F3: on a permit with a blank Permit Expiration, the draft is named `{PermitNumber}_DraftPermit_v1.docx`, the Permits item now has Proposed Start + the type's default term, and the AuditLog entry says it was set. With Proposed Start also blank, the flow returns the "enter Proposed Start" message and no file is created.
- [ ] F6, run on the anchor date: it should flag 0006 (expiry, 60 days), 0005 (expiry, 30 days), 0006 (COI, 30 days), 0007 (COI, 7 days), 0009 (start, 30 days) and 0010 (start, 14 days).
- [ ] F6: run manually twice on the same day. The second run must send nothing.
- [ ] Every *Test in your tenant* note in `flows.md` (the build guide's Step 9.1 lists them as one checklist).

## Assumptions and doubts
- **Unique `PermitNumber`.**
  - The spec says unique, so the script sets `EnforceUniqueValues`. Items are created blank and numbered by F1b.
  - If SharePoint rejects a second item while the first still has an empty PermitNumber, remove uniqueness (List settings → PermitNumber → Enforce unique values: No) and rely on F1b's concurrency setting.
  - Test this first.
- **Communication site, not a team site.** Permissions stay purely in the SharePoint groups the spec defines, with no M365-group members getting Edit implicitly.
- **Extra indexes beyond the spec:** `ProposedStart`, `SourceSubmissionId`, `ConditionLibrary.ConditionCode`, `AuditLog.PermitId`, the `Permit` lookups, and `Settings.Title`. Versioning is on for Permits and the library, because F7b and F2a need it.
- **Extra folder:** `_Templates` under Permit Records, for the Word templates. F3 version 1 reads the template from there.
- **SUP Admin library:** owners-only (SUP Owners is the only SUP group granted). It holds solution exports (build guide Step 8.4).
- **Title optional:** `Title` is made not-required on Permits, PermitConditions, ComplianceItems and AuditLog, because flows fill it.
- **Unique permissions:** ComplianceItems, Permit Records, AuditLog, Settings, ConditionLibrary and SUP Admin get unique permissions. Inheritance is broken without copying on the first run only. The SUP group grants are re-applied on every run, so a half-finished first run is repaired; a grant an owner removed by hand comes back.
- **Site owner:** the account running the script creates the site and is its primary owner, so it keeps access to finish provisioning. `-OwnerEmail` is added as a site collection administrator and to SUP Owners.
- **Library versioning:** the script turns off automatic version trimming on Permit Records (`-EnableAutoExpirationVersionTrim $false`) so the 100-version limit can be set. If your tenant default is Automatic, this overrides it for this library only.
- **Site path in flows:** the flows take the site path from `Compose SiteRel` and `Compose TenantRoot`, so the same build sheets work on `SUP-Test` and `SpecialUsePermits`.
- **English role names:** role names are the English defaults (Full Control, Contribute, Read). Non-English sites need the localized names.
- **Folder name sanitizing:** the spec's characters and spaces are stripped, repeated dots are collapsed to one, and a trailing `.` is dropped after the 30-character cut, because SharePoint rejects folder names that end in `.` or contain `..`. Commas and other characters are kept. The script and F1b use the same rule.
- **"Closed in last 365 days" and "Changed this year" views:** rolling windows, so they need no yearly edit. For a calendar-year closed view, see option B in `list-views.md`.
- **Permit Expiration:** F3 sets it to Proposed Start + `PermitTypes.DefaultTermDays` when it is blank, writes it to the permit and logs it. If Proposed Start is blank too, F3 stops and asks the coordinator to enter the dates.
- **NextSeq rows:** Settings gets `NextSeq_<this year>` **and** `NextSeq_<next year>`, so the January rollover has a row. F1b also creates the row if it is missing.
- **ProgramMailbox:** seeded from `-ProgramMailbox` (default `sup-permits@agency.example`). Set the real address. F1b, F5 and F6 read it.
- **Optional Settings rows:** `Approvers`, `DefaultCoordinator` and `DefaultSuperintendent` are created blank unless you pass values. A blank value is ignored. A wrong email in a default row makes F1b add-on A fail.
- **F3 version 1:** creates the draft under its final name with *Get file content using path* and *Create file*. The older *Copy file* plus rename is kept in `flows.md` only as an alternative, because no standard action renames a file.
- **F4:** provider tiers and clouds are settled (see Licensing above). F4a uses the Standard OneDrive *Convert file* route; the Premium Word Online action is the alternative. Provider action and field names are marked **verify** in `flows.md`.
- **F7b:** reads the previous Status from version history through *Send an HTTP request to SharePoint*, because *Get changes* returns only changed/unchanged flags. It takes the newest version whose Status differs, not simply the previous version.
