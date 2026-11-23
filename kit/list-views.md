# Permits list — views and column formatting

> **UNTESTED against a live tenant.** `Provision-SUPSite.ps1` creates every view and applies both formatters automatically. This page is the reference if you need to rebuild them by hand or check what the script did.

Status groups used below:

- **Open** (7): Received, Under Review, Draft Permit, Out for Permittee Signature, Out for Superintendent Signature, Executed, Active – Compliance Monitoring
- **Unexecuted** (5): Received, Under Review, Draft Permit, Out for Permittee Signature, Out for Superintendent Signature
- **Closed** (3): Closed, Withdrawn, Denied

`Active – Compliance Monitoring` uses an **en dash (–)**, not a hyphen. A view filter typed with a hyphen matches nothing.

**Why the script uses CAML:** the classic "Filter" section of view settings evaluates AND/OR strictly left to right with no parentheses, and allows at most 10 conditions. "Status is one of 7 values AND a date range" cannot be expressed reliably there. The script writes CAML (`<In>` plus nested `<And>`), and the UI recipes below are simplified equivalents. If you edit a script-created view in the classic UI, SharePoint may rewrite or drop its `<In>` clause, so re-check it afterwards.

Common columns: Title (permit number, linked), Project Title, Applicant Organization, Permit Type, Status, Coordinator. All views: 100 items per page.

## 1. My open permits
| | |
|---|---|
| Filter | Coordinator = **[Me]** AND Status in **Open** |
| Sort | Proposed Start ascending |
| Group by | Status (expanded) |
| Extra columns | Proposed Start, Permit Expiration |
| UI recipe | Coordinator *is equal to* `[Me]` AND Status *is not equal to* Closed AND Status *is not equal to* Withdrawn AND Status *is not equal to* Denied (all-AND, so this one is safe in the UI) |

```xml
<GroupBy Collapse='FALSE'><FieldRef Name='Status'/></GroupBy>
<OrderBy><FieldRef Name='ProposedStart' Ascending='TRUE'/></OrderBy>
<Where><And>
  <Eq><FieldRef Name='Coordinator' LookupId='TRUE'/><Value Type='Integer'><UserID Type='Integer'/></Value></Eq>
  <In><FieldRef Name='Status'/><Values><!-- 7 Open values --></Values></In>
</And></Where>
```

## 2. Expiring in 60 days
| | |
|---|---|
| Filter | Status in (Executed, Active – Compliance Monitoring) AND Permit Expiration ≥ **[Today]** AND Permit Expiration ≤ **[Today]+60** |
| Sort | Permit Expiration ascending |
| Extra columns | Permit Expiration, COI Expiration |
| UI recipe | Permit Expiration *≥* `[Today]` AND Permit Expiration *≤* `[Today]+60` AND Status *is not equal to* Closed AND Status *is not equal to* Withdrawn AND Status *is not equal to* Denied |

```xml
<OrderBy><FieldRef Name='PermitExpiration' Ascending='TRUE'/></OrderBy>
<Where><And><And>
  <In><FieldRef Name='Status'/><Values><Value Type='Text'>Executed</Value><Value Type='Text'>Active – Compliance Monitoring</Value></Values></In>
  <Geq><FieldRef Name='PermitExpiration'/><Value Type='DateTime'><Today/></Value></Geq></And>
  <Leq><FieldRef Name='PermitExpiration'/><Value Type='DateTime'><Today OffsetDays='60'/></Value></Leq>
</And></Where>
```

## 3. COI expiring
This view includes COIs that have **already** expired, which are the most urgent.

| | |
|---|---|
| Filter | Status in **Open** AND COI Expiration is not blank AND COI Expiration ≤ **[Today]+30** |
| Sort | COI Expiration ascending |
| Extra columns | COI Received, COI Expiration, Permit Expiration |
| UI recipe | COI Expiration *≤* `[Today]+30` AND COI Expiration *is not equal to* (blank) AND Status ≠ Closed AND Status ≠ Withdrawn AND Status ≠ Denied |

```xml
<OrderBy><FieldRef Name='COIExpiration' Ascending='TRUE'/></OrderBy>
<Where><And><And>
  <In><FieldRef Name='Status'/><Values><!-- 7 Open values --></Values></In>
  <IsNotNull><FieldRef Name='COIExpiration'/></IsNotNull></And>
  <Leq><FieldRef Name='COIExpiration'/><Value Type='DateTime'><Today OffsetDays='30'/></Value></Leq>
</And></Where>
```

## 4. Awaiting signature
| | |
|---|---|
| Filter | Status = Out for Permittee Signature OR Status = Out for Superintendent Signature |
| Sort | Proposed Start ascending |
| Group by | Status (expanded) |
| Extra columns | Superintendent, Permittee Signed, Superintendent Signed, Proposed Start |
| UI recipe | Status *is equal to* Out for Permittee Signature OR Status *is equal to* Out for Superintendent Signature (all-OR, safe in the UI) |

```xml
<GroupBy Collapse='FALSE'><FieldRef Name='Status'/></GroupBy>
<OrderBy><FieldRef Name='ProposedStart' Ascending='TRUE'/></OrderBy>
<Where><In><FieldRef Name='Status'/><Values>
  <Value Type='Text'>Out for Permittee Signature</Value><Value Type='Text'>Out for Superintendent Signature</Value>
</Values></In></Where>
```

## 5. Unexecuted, start within 30 days
This view also includes permits whose start date has **already passed** without execution, which is the worst case.

| | |
|---|---|
| Filter | Status in **Unexecuted** AND Proposed Start ≤ **[Today]+30** |
| Sort | Proposed Start ascending |
| Extra columns | Proposed Start, COI Received |
| UI recipe | Proposed Start *≤* `[Today]+30` AND Status ≠ Executed AND Status ≠ Active – Compliance Monitoring AND Status ≠ Closed AND Status ≠ Withdrawn AND Status ≠ Denied |

```xml
<OrderBy><FieldRef Name='ProposedStart' Ascending='TRUE'/></OrderBy>
<Where><And>
  <In><FieldRef Name='Status'/><Values><!-- 5 Unexecuted values --></Values></In>
  <Leq><FieldRef Name='ProposedStart'/><Value Type='DateTime'><Today OffsetDays='30'/></Value></Leq>
</And></Where>
```

## 6. Closed this year
CAML and the view UI have no "start of this year" token. Pick one of these options:

- **(A) Script default:** the date is hard-coded to 1 January of the year the script ran. **Edit the date every January.**
- **(B) No maintenance:** rename the view "Closed – last 365 days" and use Closed Date ≥ `[Today]-365`.

| | |
|---|---|
| Filter | Status in **Closed** AND Closed Date ≥ `2026-01-01` (A) *or* ≥ `[Today]-365` (B) |
| Sort | Closed Date descending |
| Extra columns | Closed Date, Folder |
| UI recipe | Closed Date *≥* `1/1/2026` (or `[Today]-365`) AND Status ≠ Received … (simpler: Closed Date is not blank, because only closing sets it) |

```xml
<OrderBy><FieldRef Name='ClosedDate' Ascending='FALSE'/></OrderBy>
<Where><And>
  <In><FieldRef Name='Status'/><Values><Value Type='Text'>Closed</Value><Value Type='Text'>Withdrawn</Value><Value Type='Text'>Denied</Value></Values></In>
  <Geq><FieldRef Name='ClosedDate'/><Value Type='DateTime'>2026-01-01T00:00:00Z</Value></Geq>
  <!-- option B: <Geq><FieldRef Name='ClosedDate'/><Value Type='DateTime'><Today OffsetDays='-365'/></Value></Geq> -->
</And></Where>
```

---

## Column formatting

To apply a formatter by hand: open the list, click the column header, then **Column settings → Format this column → Advanced mode**, and paste the JSON. The script applies the same JSON from `formatting/*.json`.

### Status: colored pills (`formatting/status-pill.json`)

| Status | Background | Text |
|---|---|---|
| Received | light blue | dark blue |
| Under Review | light yellow | dark yellow |
| Draft Permit | light orange | brown |
| Out for Permittee / Superintendent Signature | light purple | purple |
| Executed / Active – Compliance Monitoring | light green | dark green |
| Denied | light red | dark red |
| Closed / Withdrawn | grey | dark grey |

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "2px 10px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "white-space": "nowrap",
    "background-color": "=if(@currentField == 'Received', '#deecf9', if(@currentField == 'Under Review', '#fff4ce', if(@currentField == 'Draft Permit', '#fde7d9', if(@currentField == 'Out for Permittee Signature', '#efd9fd', if(@currentField == 'Out for Superintendent Signature', '#e3d0f5', if(@currentField == 'Executed', '#dff6dd', if(@currentField == 'Active – Compliance Monitoring', '#c4e8c1', if(@currentField == 'Denied', '#fde7e9', '#edebe9'))))))))",
    "color": "=if(@currentField == 'Received', '#004578', if(@currentField == 'Under Review', '#6d5700', if(@currentField == 'Draft Permit', '#8a3a00', if(@currentField == 'Out for Permittee Signature', '#5c2e91', if(@currentField == 'Out for Superintendent Signature', '#4b1f7a', if(@currentField == 'Executed', '#0b6a0b', if(@currentField == 'Active – Compliance Monitoring', '#0b5a0b', if(@currentField == 'Denied', '#a4262c', '#323130'))))))))"
  }
}
```

### Dates: red when past, amber within 30 days (`formatting/date-overdue.json`)
Apply this to Permit Expiration, COI Expiration and Proposed Start.

- **Blank values:** `Number(@currentField) == 0` shows nothing, so a blank date is never treated as overdue.
- **When a date turns red:** a date-only value is midnight of that day. A date turns red once a full day has passed (`date + 86400000 ms <= now`), so it shows red from the day *after* the date. That means "< today".
- **Amber:** the 30-day amber window is `2592000000` ms. Delete the inner `if(...)` if you want red only.

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "=if(Number(@currentField) == 0, '', toLocaleDateString(@currentField))",
  "style": {
    "color": "=if(Number(@currentField) == 0, '', if(Number(@currentField) + 86400000 <= Number(@now), '#a4262c', if(Number(@currentField) <= Number(@now) + 2592000000, '#8a5a00', '')))",
    "font-weight": "=if(Number(@currentField) == 0, '', if(Number(@currentField) + 86400000 <= Number(@now), '700', ''))"
  }
}
```

Verify after applying: put a blank date, yesterday, today, today+10 and today+90 on test items, then check the colors are none, red, amber, amber and none.
