# SUP Provisioning Kit

> ## ⚠️ UNTESTED: validate in a test site first
> Nothing in this kit has been run against a live Microsoft 365 tenant. The PowerShell script passes a PowerShell 7 syntax parse, its PnP cmdlets and parameters were checked offline against PnP.PowerShell 3.5.0, and it was run against stand-ins for the PnP cmdlets. The CSVs and JSON parse. **No cmdlet, flow action or formatter has been executed in SharePoint.**
>
> First run: use `-SiteAlias SUP-Test -ImportSamplePermits` and work through the "Validate" checklist below. Only then run it against `SpecialUsePermits`.

All names come from `spec/data-model.md`. Do not rename lists or columns: the internal names are fixed at creation, and the flows and app depend on them.

## Files

| File | What it is |
|---|---|
| `Provision-SUPSite.ps1` | Creates the communication site, 7 lists, the `PermitRecords` library with its folders, the groups and permissions, the indexes, the Permits views and column formatting. It seeds Settings, PermitTypes and ConditionLibrary, and optionally imports sample permits. Idempotent, and supports `-WhatIf`. |
| `PermitTypes-seed.csv` | The 6 permit types, with template path, default term and prefix. |
| `ConditionLibrary-seed.csv` | 24 generic sample conditions. `AppliesToTypes` and `TriggerImpacts` are `;`-separated; a blank `AppliesToTypes` means all types. **Have program staff and the agency biologist and archaeologist review every condition before use.** WLD-01 has date placeholders on purpose. |
| `Permits-sample.csv` | 12 fictitious permits covering all 10 statuses. Dates are relative to 2026-11-23, and the script shifts them to today. Test sites only. |
| `formatting/status-pill.json`, `formatting/date-overdue.json`, `formatting/date-start.json` | Column formatters, applied by the script. `date-start.json` (Proposed Start) only colours permits that are not yet executed. |
| `list-views.md` | View definitions (CAML plus UI equivalents) and the formatting JSON. |
| `flows.md` | Action-by-action build sheets for flows F1–F7, with expressions, connectors and Premium flags. |

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
4. **A service account for flows.** It needs a licence and a mailbox, and must be added to **SUP Owners** after provisioning, because AuditLog, Settings (the permit number counter) and ConditionLibrary are owners-only for edits. Add the program lead who maintains condition wording to SUP Owners too, or grant them Contribute on ConditionLibrary.
5. **Licensing:**
   - Standard Microsoft 365 is enough for every flow except the Word Online (Business) steps, which are **Premium**: F3's *Populate a Microsoft Word template* and F4a's *Convert Word Document to PDF*. Standard fallbacks are described in `flows.md`.
   - E-signature, by cloud:
     - **SharePoint eSignature:** $2 per request (pay-as-you-go), PDF only, no Power Automate action or trigger (requests are started by hand). No government-cloud statement.
     - **Adobe Acrobat Sign:** Standard connector; commercial and GCC only.
     - **DocuSign:** Standard connector; commercial, GCC, GCC High and DoD.

## Run order
1. `./Provision-SUPSite.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId <guid> -OwnerEmail you@contoso.com -SiteAlias SUP-Test -WhatIf`. This is a dry run: create steps are reported but not performed. On a new alias the site does not exist yet, so the dry run previews only the site creation line and stops; on an existing site it previews every step.
2. Run the same command without `-WhatIf`. Read the summary; any `FAIL` lines are listed at the end, and the script exits with code 1.
3. Set **Site settings → Regional settings → Time zone** to the office time zone. Do this *before* importing samples, because date-only values can shift a day if the site time zone is wrong.
4. *(Test site only)* Re-run with `-ImportSamplePermits`. The script is idempotent, so existing objects are skipped.
5. Add people to the groups: SUP Coordinators, SUP Compliance, SUP Approving Officials and SUP Viewers. Empty or remove the communication site's default "*Special Use Permits* Members/Visitors" groups. ComplianceItems, Permit Records, AuditLog, Settings and ConditionLibrary no longer inherit from them, but the site does.
6. Upload the Word templates to `Permit Records/_Templates`. If your file names differ from `PermitTypes-seed.csv`, fix `PermitTypes.TemplateFile`.
7. Build the flows in `flows.md` in this order: **F7a → F1b → F7b → F5 → F2 → F6 → F3 → F4** (then F1a, if you use Forms).
8. Test with the sample permits. Then, on production, run **without** `-ImportSamplePermits`. On a test site that will become production, delete the sample items, folders and AuditLog rows, and reset `NextSeq_<year>` to `1`.

## Validate (test site)
- [ ] All lists exist, and their column **internal** names match the spec. Check List settings → click a column → the URL shows `Field=<InternalName>`.
- [ ] `Status` shows 10 choices. `Impacts` and `TriggerImpacts` show 10 choices each.
- [ ] ConditionLibrary has 24 rows. OPS-04 shows two Applies To Types; WAT-01 shows five.
- [ ] Each view returns what `list-views.md` says it should. With the samples:
  - "Expiring in 60 days" shows 0005, 0006 and 0007.
  - "COI expiring" shows 0006 and 0007.
  - "Unexecuted, start within 30 days" shows 0009 and 0010.
  - "Closed in last 365 days" shows 0001–0004 (Closed, Withdrawn and Denied all count as closed).
  - Proposed Start is red or amber only on unexecuted permits (0009, 0010); Executed, Active and closed permits show it uncoloured.
- [ ] Permissions:
  - A SUP Compliance member can edit ComplianceItems and upload to Permit Records, but cannot edit Permits.
  - A coordinator cannot edit AuditLog, Settings or ConditionLibrary.
  - The flow service account is in SUP Owners. The script does not add it; without it F1b fails at *Update item Settings* and every audit write fails with 403.
- [ ] F1b: create two items within a few seconds of each other. They must get consecutive numbers with no duplicates. Sample permits (imported with a number) must not be renumbered.
- [ ] F2 on the samples: every permit gets the six standard conditions (GEN-01–04, INS-01–02). 0005 adds only OPS-05 (7 total); 0011 adds SAF-03 and OPS-05 (8); 0012 adds WAT-01, SAF-01 and SAF-02 (9), and no WAT-02; 0006 adds SOI-03, WAT-02, OPS-03 and OPS-06 (10).
- [ ] F3: on a permit with a blank Permit Expiration, the draft shows Proposed Start + the type's default term, the Permits item now has that date, and the AuditLog entry says it was set. With Proposed Start also blank, the app shows the "enter Proposed Start" message and no file is created.
- [ ] F6, run on the anchor date: it should flag 0006 (expiry, 60 days), 0005 (expiry, 30 days), 0006 (COI, 30 days), 0007 (COI, 7 days), 0009 (start, 30 days) and 0010 (start, 14 days).
- [ ] F6: run manually twice on the same day. The second run must send nothing.

## Assumptions and doubts
- **Unique `PermitNumber`.**
  - The spec says unique, so the script sets `EnforceUniqueValues`. Items are created blank and numbered by F1b.
  - If SharePoint rejects a second item while the first still has an empty PermitNumber, remove uniqueness (List settings → PermitNumber → Enforce unique values: No) and rely on F1b's concurrency setting.
  - Test this first.
- **Communication site, not a team site.** Permissions stay purely in the SharePoint groups the spec defines, with no M365-group members getting Edit implicitly.
- **Extra indexes beyond the spec:** `ProposedStart`, `SourceSubmissionId`, `ConditionLibrary.ConditionCode`, `AuditLog.PermitId`, the `Permit` lookups, and `Settings.Title`. Versioning is on for Permits and the library, because F7b needs it.
- **Extra folder:** `_Templates` under Permit Records, for the Word templates.
- **Title optional:** `Title` is made not-required on Permits, PermitConditions, ComplianceItems and AuditLog, because flows fill it.
- **Unique permissions:** ComplianceItems, Permit Records, AuditLog, Settings and ConditionLibrary get unique permissions. Inheritance is broken without copying on the first run only. The five SUP group grants are re-applied on every run, so a half-finished first run is repaired; a grant an owner removed by hand comes back.
- **Site owner:** the account running the script creates the site and is its primary owner, so it keeps access to finish provisioning. `-OwnerEmail` is added as a site collection administrator and to SUP Owners.
- **Library versioning:** the script turns off automatic version trimming on Permit Records (`-EnableAutoExpirationVersionTrim $false`) so the 100-version limit can be set. If your tenant default is Automatic, this overrides it for this library only.
- **Site path in flows:** the flows take the site path from `Compose SiteRel` and `Compose TenantRoot`, so the same build sheets work on `SUP-Test` and `SpecialUsePermits`.
- **English role names:** role names are the English defaults (Full Control, Contribute, Read). Non-English sites need the localized names.
- **Folder name sanitizing:** the spec's characters and spaces are stripped, repeated dots are collapsed to one, and a trailing `.` is dropped after the 30-character cut, because SharePoint rejects folder names that end in `.` or contain `..`. Commas and other characters are kept. The script and F1b use the same rule.
- **"Closed in last 365 days" view:** a rolling window, so it needs no yearly edit. For a calendar-year view, see option B in `list-views.md`.
- **Permit Expiration:** F3 sets it to Proposed Start + `PermitTypes.DefaultTermDays` when it is blank, writes it to the permit and logs it. If Proposed Start is blank too, F3 stops and asks the coordinator to enter the dates.
- **NextSeq rows:** Settings gets `NextSeq_<this year>` **and** `NextSeq_<next year>`, so the January rollover has a row. F1b also creates the row if it is missing.
- **ProgramMailbox:** seeded from `-ProgramMailbox` (default `sup-permits@agency.example`). Set the real address.
- **F4:** provider tiers and clouds are settled (see Licensing above). Provider action names are marked **verify** in `flows.md` except DocuSign's *Add recipient to an envelope (V2)* (`routingOrder`).
- **F7b:** reads the previous Status from version history through *Send an HTTP request to SharePoint*, because *Get changes* returns only changed/unchanged flags. It takes the newest version whose Status differs, not simply the previous version.
