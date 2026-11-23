# SUP setup kit — code review

Reviewer: independent SharePoint / Power Platform engineer. Date: 2026-11-23. Scope: `kit/` against `spec/data-model.md`. Nothing here was run against a tenant.

## Verdict

The kit is close, but it will not complete a clean first run as written. Three script defects are confirmed (one import failure, one bad switch in the app-registration command, one crash on a dry run), and two flows will log or do the wrong thing in normal use (F7b's "previous status", F1b renumbering items that already have a number). Fix findings 1–7 before the first test run; work through 8–18 during the test-site pass.

## How this was checked

| Check | Result |
|---|---|
| PowerShell 7.4.6 parse of `Provision-SUPSite.ps1` | 0 parse errors |
| PnP.PowerShell 3.5.0 (exists on the Gallery, published 2026-11-11), loaded locally with no tenant | All 43 PnP calls use real cmdlets and real parameters, including the dynamic `New-PnPSite` parameters. The one bad parameter is in a comment and the README (finding 2). |
| PnP.PowerShell source at tag `v3.5.0` | Read for `Add-PnPListItem` value handling, `Set-PnPList`, `Add-PnPFieldFromXml`, the permission and group cmdlets, `Get-PnPFolder`, `Get-PnPView` |
| Script run against in-memory stand-ins for the PnP cmdlets | Normal run, `-WhatIf` on a new alias, `-WhatIf` on an existing empty site. Findings 1 and 3 reproduced; the fixes for 1, 3 and 4 were applied to a scratch copy and re-run cleanly. |
| CSVs and JSON | Choice values, type names and impact tags all match the spec. The two formatter files are identical to the copies in `list-views.md`. Contrast ratios computed. |
| README expectations (lines 50–53 and 58) | Recomputed from `Permits-sample.csv` for the anchor date; all hold. |
| Flows | Read and traced by hand only. No Power Automate runtime was available, so **no expression in `flows.md` was executed**. |

Tiers below: **A** = confirmed by parse, `Get-Command`, PnP source, or a trace of the kit's own text. **B** = likely to fail, from product knowledge I could not execute; verify in the test tenant. **C** = nits and consistency.

---

## A. Will fail or misbehave (confirmed)

### 1. `Provision-SUPSite.ps1:453` — multi-lookup import throws; 3 of 22 conditions are never created
`[int[]]` is passed for `AppliesToTypes`. `Add-PnPListItem` calls `ListItemHelper.SetFieldValues`, whose Lookup branch does `(object[])values[key]`, and an `Int32[]` cannot be cast to `object[]`. SAF-01, OPS-01 and OPS-04 fail with *"Unable to cast object of type 'System.Int32[]' to type 'System.Object[]'"*, the script exits 1, and README:48 ("22 rows; OPS-04 shows two Applies To Types") fails. Reproduced by running the kit's value through a copy of that branch.

```powershell
if ($typeNames) { $values.AppliesToTypes = @($typeNames | ForEach-Object { $TypeIds[$_] }) }
```
`@(…)` yields `object[]`; tested through the same branch for one and for two types. The single lookup at line 524 is fine (a scalar takes the other branch).

### 2. `Provision-SUPSite.ps1:18` and `README.md:27` — `-Interactive` is not a parameter
`Register-PnPEntraIDAppForInteractiveLogin` has an *Interactive parameter set* but no `-Interactive` switch. Running the README line gives *"A parameter cannot be found that matches parameter name 'Interactive'"*, so the builder is stopped at prerequisite 3.

```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "SUP Provisioning" -Tenant contoso.onmicrosoft.com
```

### 3. `Provision-SUPSite.ps1:106` and `:432` — script dies with "Cannot index into a null array"
`Get-OrNull` returns an explicit `$null` on error, and line 432 pipes that into `ForEach-Object`, which runs once with `$_ = $null`. `Get-PnPListItem` throws when the list is missing (`GetListItem.cs:70–72`), so whenever `PermitTypes` cannot be read, the script terminates at line 432 with no summary. This happens on README step 1 (`-WhatIf`) if IT pre-created the site, and on any run where the PermitTypes list failed to create. Reproduced. After that is fixed, the same dry run still reports three false "unknown permit type" failures and exits 1, because no types exist yet.

Line 106:
```powershell
function Get-OrNull([scriptblock]$Get) { try { & $Get } catch { Write-Verbose "lookup failed: $($_.Exception.Message)" } }
```
After line 431 (`$TypeIds = @{}`), add:
```powershell
if ($WhatIfPreference) { Import-Csv (Join-Path $KitPath 'PermitTypes-seed.csv') -Encoding utf8 | ForEach-Object { $TypeIds[$_.Title] = 0 } }
```
The first change also makes swallowed errors visible with `-Verbose`. Today a 403 or a throttled call looks identical to "does not exist", which can produce duplicate seed rows.

### 4. `Provision-SUPSite.ps1:392–399` — a half-finished permission step is never repaired
Inheritance is broken first, then the five groups are granted inside the same step. If any grant throws (for example a group failed to create), the list is left with only the account that ran the script. Every later run sees `HasUniqueRoleAssignments` and skips the list, so SUP groups never get access and flows get 403 on Settings or AuditLog.

Replace lines 394–399 with:
```powershell
    $grants = $UniquePerms[$l]
    if (-not $list.HasUniqueRoleAssignments) {
        Invoke-Step $l 'Break inheritance (no copy)' { Set-PnPList -Identity $l -BreakRoleInheritance | Out-Null }
    }
    # Grants are additive, so they run every time and repair a half-finished first run.
    foreach ($grp in $grants.Keys) {
        Invoke-Step "$l / $grp" "Grant $($grants[$grp])" { Set-PnPListPermission -Identity $l -Group $grp -AddRole $grants[$grp] | Out-Null }
    }
```
Side effect: a re-run re-adds a grant an owner removed by hand. Verify in the tenant that re-adding an existing grant is silent.

### 5. `flows.md:566–576` (F7b) — "previous status" is the previous *version*, not the previous status
`value[1]` is correct only if nothing else saved the item between the status change and this call.

- **Certain, from the sheet's own line 582:** a user changes Status, then edits any other field in the same polling window. The two saves arrive as one run; the top two versions carry the same status, and the log reads **`Closed → Closed`**.
- **Likely:** on every close, F5 moves the folder and updates the item (another version, still `Closed`). F7b polls on its own schedule, so whenever F5's update lands first the result is the same wrong entry.

Step 3 Uri: change `$top=2` to `$top=20`. Replace step 4 with:

- **Filter array OlderStatus** — From: `body('Send_an_HTTP_request_to_SharePoint')?['value']`; advanced condition:
  ```
  @not(equals(item()?['Status'], triggerBody()?['Status']?['Value']))
  ```
- **Compose PreviousStatus**
  ```
  coalesce(first(body('Filter_array_OlderStatus'))?['Status'], '(none)')
  ```

### 6. `flows.md:91` (F1b) — no guard for items that already have a permit number
F1b numbers every created item. `Provision-SUPSite.ps1:523` creates sample permits with `PermitNumber` already set, so importing samples (or any migration of legacy permits) while F1b is on overwrites `SUP-2026-0001…` with fresh numbers, creates a second folder for each, and advances the counter. README step 8 has the builder working with samples after the flows exist.

Add to the F1b trigger, under Settings → Trigger conditions:
```
@empty(triggerBody()?['PermitNumber'])
```

### 7. `Provision-SUPSite.ps1:501` + `formatting/date-overdue.json` — every issued permit shows a red, bold start date
The formatter turns any past date red. On `ProposedStart` that marks every Executed, Active and Closed permit as overdue (sample permits 0001–0007). The `list-views.md:183` check passes while the list looks wrong. Past start dates only matter before execution.

Script, after line 499 and replacing lines 501–503:
```powershell
    $start = Get-Content (Join-Path $KitPath 'formatting/date-start.json') -Raw -Encoding utf8
```
```powershell
    foreach ($d in 'PermitExpiration', 'COIExpiration') {
        Invoke-Step "Permits.$d" 'Apply overdue date formatting' { Set-PnPField -List Permits -Identity $d -Values @{ CustomFormatter = $date } | Out-Null }
    }
    Invoke-Step 'Permits.ProposedStart' 'Apply start-date formatting' { Set-PnPField -List Permits -Identity ProposedStart -Values @{ CustomFormatter = $start } | Out-Null }
```
New file `formatting/date-start.json` (parses; parentheses balance):
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "=if(Number(@currentField) == 0, '', toLocaleDateString(@currentField))",
  "style": {
    "color": "=if(Number(@currentField) == 0 || [$Status] == 'Executed' || [$Status] == 'Active' || [$Status] == 'Closed' || [$Status] == 'Withdrawn' || [$Status] == 'Denied', '', if(Number(@currentField) + 86400000 <= Number(@now), '#a4262c', if(Number(@currentField) <= Number(@now) + 2592000000, '#8a5a00', '')))",
    "font-weight": "=if(Number(@currentField) == 0 || [$Status] == 'Executed' || [$Status] == 'Active' || [$Status] == 'Closed' || [$Status] == 'Withdrawn' || [$Status] == 'Denied', '', if(Number(@currentField) + 86400000 <= Number(@now), '700', ''))"
  }
}
```
`[$Status]` needs Status in the view; it is in all seven. Consider the same Closed/Withdrawn/Denied exclusion for the two expiration columns.

Matching text edits: `list-views.md:165` → "Apply this to Permit Expiration and COI Expiration. Proposed Start uses `formatting/date-start.json`: the same rule, but only while the permit is not yet executed." `README.md:18` → add `formatting/date-start.json` to the file list.

---

## B. Likely fails — verify in the test tenant

### 8. `flows.md:286` (F3) — draft generation fails when a date is blank, and nothing ever sets `PermitExpiration`
`formatDateTime()` errors on null. No flow sets `PermitExpiration`, and `PermitTypes.DefaultTermDays` is never read anywhere in the kit, so every new permit reaches F3 with it blank unless a coordinator typed it. High confidence.

For each date field mapped in step 8:
```
if(empty(body('Get_item_Permit')?['PermitExpiration']), '', formatDateTime(body('Get_item_Permit')?['PermitExpiration'], 'MMMM d, yyyy'))
```
Also decide who sets the expiration: either tell the coordinator to enter it before generating, or have F3 default it from `DefaultTermDays`.

### 9. `flows.md:13`, `:55`, `:187`, `:248`, `:331` — app-triggered flows run with the clicking user's rights
F2 option B, F3 and F4a use the Power Apps trigger, which by default runs SharePoint actions on the caller's connection. Coordinators are now Read on AuditLog and Settings (`Provision-SUPSite.ps1:387–388`). With the non-solution fallback at line 55 (inline *Create item → AuditLog*), those flows fail with 403 for every coordinator. This is a direct consequence of the Edit → Contribute / owners-only change.

Add to line 13:
> For the flows started from the app (F2 option B, F3, F4a): after saving, open the flow's details page → **Run only users** → set SharePoint (and Word Online, Outlook) to **Use this connection (service account)**. Otherwise they run with the coordinator's own rights and cannot write AuditLog.

### 10. `flows.md:416–443` (F5) — not re-runnable, and line 442 contradicts `spec/facts.md` 7b
If the move succeeds and step 4 fails, `FolderPath` still points at Open Projects. Every later edit re-fires F5, the move fails because the source is gone, and the item never heals. Two edits in quick succession do the same. Line 442 states that file item IDs survive the move; facts.md 7b says to assume they do not.

- Trigger: Concurrency control on, degree 1.
- New step before 2 — **Get item Fresh** (Permits, Id `triggerBody()?['ID']`), then **Condition**: `contains(coalesce(body('Get_item_Fresh')?['FolderPath'], ''), '/Closed Projects/')` is true → Terminate, Succeeded.
- New step 2a — **Get folder metadata using path** on the **source**, `outputs('Compose_FolderSiteRel')`. *Configure run after*: Move folder **has failed**.
- New step 2b — **Send an email** to the coordinator and program mailbox, then **Terminate (Failed)**. *Configure run after*: 2a **is successful**. The source folder is still there, so the move really failed or stopped part-way and a person must look.
- Step 3 — *Configure run after*: 2b **is skipped**. That covers both good paths: the move worked, or it failed only because an earlier run had already moved the folder (2a fails with not-found). Steps 4 and 5 follow as written.
- This replaces the note on line 443.
- Line 442, replace with: "Do not assume file item IDs or version history survive the move (facts.md 7b is unverified). Test it: note a file's ID and version count, close the permit, compare. Bookmarked folder URLs break."

### 11. `Provision-SUPSite.ps1:345` — `-MajorVersions` throws on the library when version trimming is Automatic
Confirmed in the 3.5.0 source: on a document library whose trim mode is `AutoExpiration`, `Set-PnPList -MajorVersions` throws *"The parameter MajorVersions can't be set when AutoExpiration is enabled"*. Whether your tenant uses Automatic is the part to check (SharePoint admin center → Settings → Version history limits). Line 328 (a list) is not affected.

```powershell
Set-PnPList -Identity $LibTitle -EnableVersioning $true -EnableAutoExpirationVersionTrim $false -MajorVersions 100 -ExpireVersionsAfterDays 0 | Out-Null
```

### 12. `Provision-SUPSite.ps1:46`, `:202`, `:221` — `.sharepoint.us` is accepted but the sign-in targets the commercial cloud
The URL pattern allows GCC High / DoD, but neither `Connect-PnPOnline` passes `-AzureEnvironment` (facts.md #8), so sign-in fails there.

Add to the `param` block, and append `-AzureEnvironment $AzureEnvironment` to lines 202 and 221 and to the register command in finding 2:
```powershell
[ValidateSet('Production', 'USGovernment', 'USGovernmentHigh', 'USGovernmentDoD')] [string] $AzureEnvironment = 'Production',
```

### 13. `Provision-SUPSite.ps1:211` — if the person running the script is not `-OwnerEmail`, they may have no rights on the new site
The site is created with someone else as owner, then the script connects to it as the runner. A SharePoint Administrator has no automatic access to site content. If access is denied, every existence check returns "missing" (see finding 3) and every create fails.

Line 211, let the runner own the site, then add the named owner after line 221:
```powershell
New-PnPSite -Type CommunicationSite -Title $SiteTitle -Url $SiteUrl -Lcid 1033 -Wait | Out-Null
```
```powershell
Invoke-Step $OwnerEmail 'Add as site collection admin' { Add-PnPSiteCollectionAdmin -Owners $OwnerEmail | Out-Null }
```

### 14. `flows.md:298` (F3 step 13) — `Create file` has no `{Link}` output
`{Link}` comes from the properties actions. The app would receive an empty URL.
```
body('Update_file_properties')?['{Link}']
```

### 15. `flows.md:254–255` (F3) — "tagged" should be "titled"
facts.md 1b: the Word connector keys fields on the content control's **Title**, and duplicate titles are filled with the same value. A builder who sets only Tag gets no named fields.

> Plain-text content controls whose **Title** (Developer → Properties → Title) is `PermitNumber`, … Set Tag to the same value. A Repeating Section titled `Conditions`, containing plain-text controls titled `ConditionCode` and `ConditionText`.

### 16. `flows.md:333` (F4a) and `:275` (F3) — draft file selection
F4a sends "the latest file in the folder" with no filter, so a COI or site plan uploaded after the draft goes out for signature. F3's draft count also matches `…_DraftPermit_v1_PermitteeSigned.pdf` (line 367), and after any draft is deleted, count + 1 collides with an existing name and *Create file* fails.

Filter Query for both:
```
startswith(FileLeafRef, '@{body('Get_item_Permit')?['PermitNumber']}_DraftPermit_v') and substringof('.docx', FileLeafRef)
```
F4a: add Order By `Modified desc`, Top Count `1`, and *Limit Entries to Folder* = the permit folder.

This fixes the wrong-file and signed-PDF cases. It does **not** fix the collision after a draft is deleted; counting files cannot. Either tell staff not to delete drafts, or derive the number from the highest existing name instead of the count.

### 17. `flows.md:78` (F1a step 4) — "text mode" contradicts the key/value map
Text mode yields an array of strings; the multi-choice column needs `[{"Value":"…"}]`. As written, *Create item* rejects `Impacts`.

> Map: stay in key/value mode. Key `Value`, value `item()`.

### 18. `flows.md:321–334`, `:594`, `README.md:33` — "verify" on facts the spec already settled; DocuSign missing
- Line 325: facts.md 4c says SharePoint eSignature has **no** Power Automate action or trigger. Say so; F4 for eSignature is manual start plus the file-arrival half.
- Line 326: facts.md 4a/4b confirm sequential order and external (guest) signers.
- Line 328: Adobe Acrobat Sign is **Standard**, GCC only (5a, 5c).
- Line 334: *Convert Word Document to PDF* is **PREMIUM** (facts.md #2). SharePoint eSignature takes PDFs only, so without Premium the PDF is a manual *Save as PDF*.
- DocuSign is the only connector listed for GCC High and DoD (5f) and is absent from line 321–329 and README:33.
- Line 594, Premium column: "No for Adobe Sign / DocuSign; Yes if the flow converts to PDF".

---

## C. Nits and consistency

### 19. README is stale after the permission change
`Provision-SUPSite.ps1:384–390` gives unique permissions to **five** lists. Fix:
- `README.md:40` → "ComplianceItems, Permit Records, AuditLog, Settings and ConditionLibrary no longer inherit…"
- `README.md:70` → "…ComplianceItems, Permit Records, AuditLog, Settings and ConditionLibrary get unique permissions…"
- `README.md:56` → add "A coordinator cannot edit Settings or ConditionLibrary."
- `README.md:72` and `Provision-SUPSite.ps1:358` still list "Edit"; the script no longer uses it.
- `README.md:54–56` → add "The flow service account is in SUP Owners." Nothing in the script adds it; if the step at README:30 is missed, F1b fails at *Update item Settings* and every audit write fails with 403.

The "Active" rename is clean: no leftover of the old name in any kit file, and the status lists agree across the script, CSVs, formatter, views and flows.

### 20. `flows.md` wording a builder will trip on
- Line 20: F2 does not update Permits; F3 does (line 296). → "F1, F3, F4, F5 and F6 all update Permits items".
- Lines 175–189: a flow has one trigger. Say "build option A and option B as two flows, or build only one".
- Line 12: the sheets name columns by internal name, but the designer shows display names. Add: "`FolderUrl` appears as **Folder**, `LocationName` as **Location**, `EvidenceUrl` as **Evidence**; the rest are the internal name with spaces. Expressions always use the internal name."
- Line 141: `trim(replace(…, '..', ''))` does not remove a trailing `.` (a location such as "Park Rd." fails folder creation).
- Lines 485–489: steps 8 and 9 omit `Top Count 500`.

### 21. `flows.md:412` (F5 trigger condition) — null `FolderPath`
`contains(null, …)` errors if `and()` does not short-circuit (unverified). Use `coalesce`:
```
@and(contains(createArray('Closed','Withdrawn','Denied'), triggerBody()?['Status']?['Value']), not(empty(triggerBody()?['FolderPath'])), not(contains(coalesce(triggerBody()?['FolderPath'], ''), '/Closed Projects/')))
```

### 22. `flows.md:241`, `:290`, `:530`, `:544` — integers passed to `concat`
I could not confirm that `concat` coerces numbers. Wrapping costs nothing: `string(variables('varAdded'))`, `string(outputs('Compose_Version'))`, `string(length(body('Filter_array_Mine')))`, `string(items('Apply_to_each_Sent')?['DaysOut'])`.

### 23. Small script items
- `Provision-SUPSite.ps1:486` with `:512`: the view uses the run year, but sample closed dates are shifted relative to today. On a run between January and about mid-June, some or all of the four closed samples land in the previous year and README:53 fails.
- Lines 146–147: if the rename to "Permit Records" fails after the library is created, line 340 finds nothing and the library is silently left unconfigured. Use the URL `PermitRecords` as the identity at lines 339–345 and 386.
- `README.md:36`: on a new alias, `-WhatIf` previews the site line only and stops (script line 216). Say so.

### 24. `ConditionLibrary-seed.csv` — the rule gives mostly sensible suggestions; four are off
Simulated for the 12 sample permits. Construction, utility, event and filming permits get the conditions a reviewer would expect. Exceptions:
- **WAT-01 on 0005** (in-stream sampling): the condition forbids work within 100 ft of a stream, which is the permitted activity. The rule has no exclude list, so set `AppliesToTypes` on line 13 to `Special Event;Commercial Filming / Photography;Right-of-Way / Utility;Construction / Access;Agricultural Use`.
- **WAT-02 on 0005 and 0012** (refuelling, on a kick-net survey and a choir concert): line 14, set `TriggerImpacts` to `Motorized equipment or vehicles off road` only.
- **0011** (bat detectors) gets only SAF-03. Research / Collection and Agricultural Use have no type-specific condition; add at least one of each so the type path is exercised.
- 0004 and 0008 describe excavation and boring but lack the `Motorized equipment…` tag (sample data, not the rule).

### 25. `formatting/date-overdue.json:6` — fixed hex colours fail on dark backgrounds
On white: red 7.3:1, amber 5.9:1 (pass). On a dark theme (Teams dark mode, dark site theme): 2.0–2.8:1 (fail). Status pills carry their own background and pass everywhere (6.0:1 to 10.9:1). If lists will be viewed in Teams, replace `style.color` with theme classes:
```json
"attributes": { "class": "=if(Number(@currentField) == 0, '', if(Number(@currentField) + 86400000 <= Number(@now), 'sp-field-severity--blocked', if(Number(@currentField) <= Number(@now) + 2592000000, 'sp-field-severity--warning', '')))" }
```

---

## Checked and found sound

"No defect found" below means by reading and local checks; none of it ran in SharePoint.

**Script**
- **Field XML:** well-formed for every type (lookup, multi-lookup, multi-choice, person, hyperlink, date-only). Internal names are forced by `Name` + `DisplayName` and renamed afterwards. `Add-PnPFieldFromXml` does not add to the default view, so the script's own step for that is needed.
- **Ordering:** lookup targets are created before the lists that point at them.
- **Indexes:** `Indexed="TRUE"` in the XML for 11 columns plus `Set-PnPField … Indexed` for Settings.Title; the property exists. No defect found.
- **Role names:** `Full Control`, `Contribute`, `Read` are the default English names and the site is created with LCID 1033. No defect found.
- **Associated groups:** `Owners`, `Members`, `Visitors` are valid values and the cmdlet calls `AssociateDefaultGroups`. No defect found. The site's original three groups keep their site-level rights (README:40 tells the builder to empty them).
- **Lock-out:** breaking inheritance without copying should leave the running account with Full Control (see "could not verify" 2). Finding 4 is the real exposure.
- **Service account:** can write Settings and AuditLog only as a member of SUP Owners, which is a manual step (finding 19).
- **CSV import, from the PnP source:** multi-choice values go to SharePoint as a `string[]` with no splitting in PnP, so `Near stream, river or wetland` is not broken up there. Booleans are real `[bool]`. A person given as an email is resolved with `EnsureUser`. The hyperlink string `url, description` is passed through unchanged; folder names contain no spaces, so it has a single `, ` separator. Dates: see "could not verify" 3.
- **`-WhatIf`:** read-only calls run and every change goes through `ShouldProcess`; in the stand-in run no write cmdlet was reached on a dry run. Finding 3 is the only defect.

**Views and formatting**
- View CAML is well-formed and returns the README's expected sample rows on the anchor date.
- Both formatters use the v2 schema and only allowed style properties.

**Flows**
- **Syntax:** no malformed expression found; the 16-deep `replace` chain, the OData quote doubling and the `NewKey` expression all balance.
- **F6:** query strings, key format and the six expected reminders (README:58) trace correctly.
- **Loops:** F5's own update cannot retrigger it; F6's key update does not trip F5 or F7b; F2 makes no Permits changes.
- **Concurrency:** F1b at degree 1 serialises the counter, with the unique index as backstop.
- **Paging and threshold:** every *Get items* filters on an indexed column or reads a small list. PermitConditions is the one queried list that will pass 5,000 rows, and it is only queried by its indexed `Permit` lookup.
- **Time zones:** local dates use `convertFromUtc` with a Windows zone ID throughout; the one `utcNow()` in F6 step 4 is safe at 07:00 and the sheet says so.

## What I could not verify

Everything below needs the test tenant. None of it could be executed here.

1. Any live behaviour of the script: site creation, `Indexed` / `EnforceUniqueValues` from field XML, whether a unique column accepts several blank values (README:62–65), re-adding an existing role assignment.
2. That breaking inheritance without copying leaves the running account with Full Control (the script's line 401 assumes it; I believe it is true but did not confirm it).
3. `Provision-SUPSite.ps1:536`: dates are sent as `yyyy-MM-dd` strings. PnP passes them through unchanged; whether SharePoint reads them in the site time zone or the PC's is unconfirmed. Check sample dates after import. `New-PnPSite` has a `-TimeZone` parameter that would remove the manual step at README:38.
4. Every Power Automate output name and shape: `{Link}` on *Create new folder* and *Move folder*, `ColumnHasChanged`, the versions endpoint (`$select=Status`, newest-first order), choice / lookup / person shapes (line 16).
5. OData details the sheet already hedges: date-only `eq` (line 494), lookup filter `PermitId eq` versus `Permit/Id eq` (lines 202, 262), path form for *Limit Entries to Folder* and *Move folder*.
6. Findings 8, 9, 14, 15, 17 rest on connector behaviour I know but did not run.
7. Formatter rendering: the JSON parses and uses only allowed style properties; the expressions were not rendered in a list.
8. E-signature provider actions (F4 primary) — not reviewable until a provider is chosen.
