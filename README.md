# Special Use Permit System on Microsoft 365

A build kit for replacing an email + Excel + manual-folder permit process with
SharePoint lists, Power Automate flows, a Power Apps coordinator app and Power BI.

> **Untested against a live tenant.** Scripts and flow expressions were written
> without access to the target Microsoft 365 tenant. Run everything in a test
> site first.

## Contents

| Path | What it is |
| --- | --- |
| `spec/data-model.md` | Lists, columns, statuses, impact tags and naming convention every other file uses |
| `spec/facts.md` | Licensing and connector facts checked against Microsoft documentation, with sources |
| `spec/review-architecture.md` | Independent architecture review and recommended hardening |
| `kit/Provision-SUPSite.ps1` | PnP PowerShell script that creates the site, lists, library, groups and seed data |
| `kit/flows.md` | Action-by-action build sheets for the Power Automate flows |
| `kit/list-views.md`, `kit/formatting/` | SharePoint views and column formatting JSON |
| `kit/*.csv` | Sample condition library, permit types and fictitious test permits |
| `prototype/sup-coordinator.html` | Clickable mock-up of the coordinator app with sample data |

The step-by-step build guide lives in a separate shared document.

## Status

Work in progress. The data model in `spec/data-model.md` predates the
architecture review; some of the review's changes are not yet applied to the kit
and prototype.
