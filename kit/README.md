# SUP Provisioning Kit

> ## ⚠️ UNTESTED: validate in a test site first
> Nothing in this kit has been run against a live Microsoft 365 tenant. The PowerShell script passes a PowerShell 7 syntax parse and an offline test of its helper functions. The CSVs and JSON parse. **No cmdlet, flow action or formatter has been executed in SharePoint.**
>
> First run: use `-SiteAlias SUP-Test -ImportSamplePermits` and work through the "Validate" checklist below. Only then run it against `SpecialUsePermits`.

All names come from `spec/data-model.md`. Do not rename lists or columns: the internal names are fixed at creation, and the flows and app depend on them.

## Files

| File | What it is |
|---|---|
| `Provision-SUPSite.ps1` | Creates the communication site, 7 lists, the `PermitRecords` library with its folders, the groups and permissions, the indexes, the Permits views and column formatting. It seeds Settings, PermitTypes and ConditionLibrary, and optionally imports sample permits. Idempotent, and supports `-WhatIf`. |
| `PermitTypes-seed.csv` | The 6 permit types, with template path, default term and prefix. |
| `ConditionLibrary-seed.csv` | 22 generic sample conditions. `AppliesToTypes` and `TriggerImpacts` are `;`-separated; a blank `AppliesToTypes` means all types. **Have program staff and the agency biologist and archaeologist review every condition before use.** WLD-01 has date placeholders on purpose. |
| `Permits-sample.csv` | 12 fictitious permits covering all 10 statuses. Dates are relative to 2026-11-23, and the script shifts them to today. Test sites only. |
| `formatting/status-pill.json`, `formatting/date-overdue.json` | Column formatters, applied by the script. |
| `list-views.md` | View definitions (CAML plus UI equivalents) and the formatting JSON. |
| `flows.md` | Action-by-action build sheets for flows F1–F7, with expressions, connectors and Premium flags. |

## Prerequisites
1. **PowerShell 7.2 or later** and **PnP.PowerShell 2.x or 3.x**: `Install-Module PnP.PowerShell -Scope CurrentUser`
2. **SharePoint Administrator** rights for the person running the script, because the site is created through the admin endpoint.
3. **Your own Entra ID app registration.** PnP's shared multi-tenant app was retired in September 2024. Run this once, with an admin consenting:
   ```powershell
   Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "SUP Provisioning" -Tenant contoso.onmicrosoft.com -Interactive
   ```
   Pass the resulting Application (client) ID as `-ClientId`.
4. **A service account for flows.** It needs a licence and a mailbox, and must be added to **SUP Owners** after provisioning, because AuditLog is owners-only for edits.
5. **Licensing:**
   - Standard Microsoft 365 is enough for every flow except F3's *Populate a Microsoft Word template*, which is **Premium**. A Standard fallback is described in `flows.md`.
   - E-signature needs SharePoint eSignature (pay-as-you-go) or Adobe Acrobat Sign.

## Run order
1. `./Provision-SUPSite.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId <guid> -OwnerEmail you@contoso.com -SiteAlias SUP-Test -ImportSamplePermits -WhatIf`. This is a dry run: the site steps are reported only.
2. Run the same command without `-WhatIf`. Read the summary; any `FAIL` lines are listed at the end, and the script exits with code 1.
3. Set **Site settings → Regional settings → Time zone** to the office time zone.
4. Add people to the groups: SUP Coordinators, SUP Compliance, SUP Approving Officials and SUP Viewers. Empty or remove the communication site's default "*Special Use Permits* Members/Visitors" groups. The script prints a reminder.
5. Upload the Word templates to `Permit Records/_Templates`. If your file names differ from `PermitTypes-seed.csv`, fix `PermitTypes.TemplateFile`.
6. Build the flows in `flows.md` in this order: **F7a → F1b → F7b → F5 → F2 → F6 → F3 → F4** (then F1a, if you use Forms).
7. Test with the sample permits. Then, on production, run **without** `-ImportSamplePermits`. On a test site that will become production, delete the sample items, folders and AuditLog rows, and reset `NextSeq_<year>` to `1`.

## Validate (test site)
- [ ] All lists exist, and their column **internal** names match the spec. Check List settings → click a column → the URL shows `Field=<InternalName>`.
- [ ] `Status` shows 10 choices, with the en dash in `Active – Compliance Monitoring`. `Impacts` and `TriggerImpacts` show 10 choices each.
- [ ] ConditionLibrary has 22 rows. OPS-04 shows two Applies To Types.
- [ ] Each view returns what `list-views.md` says it should. With the samples:
  - "Expiring in 60 days" shows 0005, 0006 and 0007.
  - "COI expiring" shows 0006 and 0007.
  - "Unexecuted, start within 30 days" shows 0009 and 0010.
  - "Closed this year" shows 0001–0004 (Closed, Withdrawn and Denied all count as closed).
- [ ] Permissions:
  - A SUP Compliance member can edit ComplianceItems and upload to Permit Records, but cannot edit Permits.
  - A coordinator cannot edit AuditLog.
- [ ] F1b: create two items within a few seconds of each other. They must get consecutive numbers with no duplicates.
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
- **English role names:** role names are the English defaults (Full Control, Edit, Contribute, Read). Non-English sites need the localized names.
- **Folder name sanitizing:** characters are stripped exactly per spec. Commas, periods and other characters are kept. A leading or trailing `.` would make SharePoint reject the folder name; this is noted in F1.
- **"Closed this year" view:** it is hard-coded to 1 January of the year the script ran. Edit it each January, or switch it to a rolling 365 days (see `list-views.md`).
- **NextSeq rows:** Settings gets `NextSeq_<this year>` **and** `NextSeq_<next year>`, so the January rollover has a row. F1b also creates the row if it is missing.
- **ProgramMailbox:** seeded from `-ProgramMailbox` (default `sup-permits@agency.example`). Set the real address.
- **F4:** e-signature action names and tiers are deliberately generic; they are marked **verify** in `flows.md`.
- **F7b:** reads the previous Status from version history through *Send an HTTP request to SharePoint*, because *Get changes* returns only changed/unchanged flags.
