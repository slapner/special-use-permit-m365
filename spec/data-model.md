# SUP System — Original Data Model (historical)

> This was the starting design. It has not been kept up to date. The current names, lists, Settings keys, folder rules and flow IDs are in `docs/build-guide.md` (Phase 1 and Phase 4) and `kit/Provision-SUPSite.ps1`. Where this file disagrees with them, they win.

The first versions of the companion files, the guide and the prototype used these names.
Internal names have NO spaces (SharePoint internal names are fixed at creation).

## Site
- URL: `https://<tenant>.sharepoint.com/sites/SpecialUsePermits`
- Groups: `SUP Coordinators` (Contribute; Read on Settings, ConditionLibrary and AuditLog), `SUP Compliance` (Contribute on ComplianceItems + docs, Read on Permits), `SUP Approving Officials` (Read + sign), `SUP Viewers` (Read). `SUP Owners` = site owners.

## Naming convention
- Permit number: `SUP-{YYYY}-{NNNN}` (year of receipt, 4-digit sequence that resets each year). Example `SUP-2026-0042`.
- Folder: `{PermitNumber}_{ApplicantShort}_{LocationShort}` e.g. `SUP-2026-0042_RiverBendOutfitters_MillCreekTrail`.
  - Short = remove characters `~ " # % & * : < > ? / \ { | }` and spaces, max 30 chars each.
- Files: `{PermitNumber}_{DocType}[_{qualifier}].{ext}`
  - DocType values: `Application`, `DraftPermit_v{n}`, `COI_exp{yyyy-MM-dd}`, `SitePlan_{n}`, `Correspondence_{yyyy-MM-dd}`, `Compliance_{yyyy-MM-dd}`, `Executed`.

## Document library: `PermitRecords` (display "Permit Records")
- Top folders: `Open Projects`, `Closed Projects`
- Per-permit subfolder inside one of them.
- Extra library columns: `PermitNumber` (text), `DocType` (choice: Application, Draft Permit, COI, Site Plan, Correspondence, Compliance Record, Executed Permit, Other).

## List: `Permits`
| Internal name | Type | Notes |
|---|---|---|
| Title | Single line | = PermitNumber (set by flow) |
| PermitNumber | Single line | indexed, unique |
| PermitType | Lookup → PermitTypes | |
| Status | Choice | see Status values |
| ApplicantName | Single line | person or org contact |
| ApplicantOrg | Single line | |
| ApplicantEmail | Single line | |
| ApplicantPhone | Single line | |
| ProjectTitle | Single line | |
| ProjectDescription | Multi line (plain) | |
| LocationName | Single line | |
| Latitude / Longitude | Number | optional |
| Impacts | Choice (multi) | see Impact tags |
| ProposedStart | Date | |
| ProposedEnd | Date | |
| PermitExpiration | Date | |
| ReceivedDate | Date | |
| Coordinator | Person | |
| Superintendent | Person | |
| COIReceived | Yes/No | |
| COIExpiration | Date | |
| PermitteeSigned | Date | null until signed |
| SuperintendentSigned | Date | null until signed |
| ComplianceComplete | Yes/No | |
| ClosedDate | Date | |
| FolderUrl | Hyperlink | updated on close |
| FolderPath | Single line | server-relative path, updated on close |
| SignatureRequestId | Single line | e-sign envelope/agreement id |
| LastReminderKey | Single line | dedupe for reminders: "{type}:{yyyy-MM-dd}" pipe-joined |
| SourceSubmissionId | Single line | Forms response id |

### Status values (in order)
`Received` → `Under Review` → `Draft Permit` → `Out for Permittee Signature` → `Out for Superintendent Signature` → `Executed` → `Active` → `Closed`
Off-ramps: `Withdrawn`, `Denied` (both close and move folder).

### Impact tags (choice values on Permits.Impacts and ConditionLibrary.TriggerImpacts)
`Ground disturbance`, `Near stream, river or wetland`, `Tree clearing`, `Structures or temporary facilities`, `Motorized equipment or vehicles off road`, `Large group or public event`, `Night activity or lighting`, `Commercial filming or photography`, `Utility or right-of-way work`, `Use of drones (UAS)`

## List: `PermitTypes`
| Title (type name) | TemplateFile (single line, path to .docx) | DefaultTermDays (number) | Prefix (optional) |
Seed: Special Event; Commercial Filming / Photography; Right-of-Way / Utility; Research / Collection; Construction / Access; Agricultural Use.

## List: `ConditionLibrary`
| Internal | Type |
|---|---|
| Title | short name |
| ConditionCode | text e.g. `CUL-01` |
| Category | Choice: General, Insurance & Liability, Cultural Resources, Soils & Erosion, Water Resources, Wildlife, Vegetation, Public Safety, Operations |
| ConditionText | Multi line (plain) — exact permit wording |
| AppliesToTypes | Lookup (multi) → PermitTypes; empty = all types |
| TriggerImpacts | Choice (multi) — same values as Permits.Impacts; empty = not impact-triggered |
| AlwaysInclude | Yes/No — standard conditions on every permit of the applicable types |
| Active | Yes/No |
| SortOrder | Number |

Rule: suggest a condition if Active AND (AppliesToTypes empty OR contains permit's type) AND (AlwaysInclude OR TriggerImpacts ∩ permit.Impacts ≠ ∅).

## List: `PermitConditions` (junction)
| Title (=ConditionCode) | Permit (Lookup → Permits) | Condition (Lookup → ConditionLibrary) | ConditionText (snapshot, editable) | Source (Choice: Suggested, Added by staff) | Included (Yes/No) | SortOrder |

## List: `ComplianceItems`
| Title | Permit (Lookup) | DueDate | Completed (Yes/No) | CompletedDate | EvidenceUrl | AssignedTo (Person) |

## List: `AuditLog` (flows write; users read-only)
| Title (=PermitNumber) | PermitId (Number) | EventType (Choice: Created, Status Changed, Field Changed, Document Added, Signature Sent, Signed, Reminder Sent, Moved to Closed) | Detail (multi line) | Actor (single line, email) | EventTime (Date+time) |

## List: `Settings`
Title (key) / Value. Keys: `ReminderDaysPermitExpiry` = `60,30,7`; `ReminderDaysCOI` = `30,7`; `ReminderDaysStartUnexecuted` = `30,14,7`; `ProgramMailbox` = `sup-permits@<agency>`; `NextSeq_2026` = `1`.
