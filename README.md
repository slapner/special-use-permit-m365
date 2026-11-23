# Special Use Permit System

This folder contains everything needed to replace the current permit process
(email, an Excel tracker, and folders made by hand) with one system built on
tools your office already has in Microsoft 365.

You do not need to be technical to read this page.

## What the new system does

- **Applicants fill in an online form.** Nobody retypes their details into Excel.
- **Each application gets a permit number and its own folder automatically**, named the same way every time.
- **The system suggests permit conditions.** For example, if the project involves digging, it suggests the archaeological and soil conditions. Staff still review and decide.
- **It creates the draft permit** from your Word template.
- **It sends the permit for signature**: first to the permittee, then to the Superintendent.
- **It sends reminder emails** before a permit expires, before insurance expires, and when a start date is close but the permit is not signed.
- **It moves finished permits** to the Closed Projects folder.
- **It shows a dashboard** of where every permit stands, and keeps a history of who did what and when.

All documents stay in SharePoint.

## Where to start

| If you want to... | Open this |
| --- | --- |
| See what the system will look like | Download [`prototype/index.html`](prototype/index.html) and double-click it. It opens in your web browser and uses made-up permits, so click anything. The same preview is also [online](https://claude.ai/artifact/SN7CS7UKucuSFbMYWqkggf), if the owner has shared it with you. |
| Read the full plan, step by step | [`docs/build-guide.md`](docs/build-guide.md) |
| Hand the work to the person who will build it | Give them this whole folder. The files they need are in `kit/`. |

## What is in each folder

| Folder | In plain words |
| --- | --- |
| `docs/` | The step-by-step guide. Start here. |
| `prototype/` | The clickable preview. `index.html` is the one to open. |
| `kit/` | Ready-made pieces for the builder: a setup script, sample permit conditions, sample permits for testing, and instructions for each automation. |
| `spec/` | Background notes: the Microsoft facts we checked, and the outside experts' reviews. |
| `scripts/` | Two small helper programs that keep the copies in this folder up to date. You can ignore them. |

## Three things to know before anyone builds

1. **This has not been tried in your Microsoft 365 yet.** Everything here was prepared without access to your systems. The builder should try it in a practice site first.
2. **The preview is a picture of the system, not the system.** Nothing you click in it is saved or sent.
3. **A few decisions are needed first**, such as which e-signature tool your office is allowed to use. They are listed at the start of the guide, under "Phase 0".

## Who does what

- **Program lead:** makes the decisions in Phase 0 and tags each permit condition with what should trigger it.
- **IT:** provides a shared account for the system to run under and confirms which licenses the office has.
- **Builder** (someone comfortable with SharePoint and Power Automate): follows the guide, phase by phase.

## Status

The guide, the setup kit and the preview are complete and agree with each other.
Outside experts reviewed the design, the preview, the setup script and the guide,
and their corrections are included. Their reports are in `spec/`.

What has not happened yet: nobody has tried any of this in a real Microsoft 365
account. Expect some steps to need small adjustments the first time through.
