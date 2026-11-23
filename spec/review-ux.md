# UX/UI review: SUP Coordinator prototype

Reviewed `prototype/sup-coordinator.html` on 2026-11-23. The prototype file was not edited.

## Verdict

The workflow is all there and it runs: permit 0013 went from Under Review to Closed with no console errors, the folder moved to Closed Projects, and the audit trail recorded every step. The visual base is calm and both themes hold up.

It is not ready to put in front of the Superintendent yet. Three things would undermine the demo:

- **The Superintendent cannot open the permit they are asked to sign**, and signing is one unconfirmed click (finding 1).
- **A permit can go out for signature in a state it should not**: stale draft, unfilled `[START DATE]` placeholders, expired insurance (findings 2 and 4).
- **The mock-up promises things Power Apps on SharePoint will not do as shown**: in-app signing, live signature status, a rendered permit preview, public file upload (findings 17–20).

## How it was tested

- Headless Chrome through Playwright, with the file wrapped in the minimal HTML shell and loaded over `file://`. IBM Plex Sans and Mono loaded, so the type judgments are about the intended fonts.
- Every route and every record tab, at 1280 px and 400 px, in light and dark.
- The full 0013 flow with real clicks, switching roles for the Superintendent signature and the compliance items, at both widths.
- Separate fresh-page probes for edge cases: stale draft, COI dates, withdraw and deny, a new application, role gating, keyboard focus, and a faked clock.
- A computed contrast audit of all visible text in both themes.

The 109 screenshots are in `/private/tmp/claude-501/-Users-bclapner--t3-scratch-2026-11-23-i-need-this-built-as-e4975909/0528aa15-5174-473b-866b-f01e9bee2534/scratchpad/ux/`. I looked at about 30 of them, covering every screen in at least one theme and width. The rest were checked by measurement only (overflow, contrast, state).

Each finding is tagged **Observed** (seen in the browser) or **Source** (read in the code, not exercised).

---

## 1. Bugs

### 1. The Superintendent cannot view the draft, and signs with one click — High, Observed
- As Approving official, the button reads "View draft v1 · Coordinator only" and is disabled. `preview` is missing from `PERM` (line 572), so it falls back to coordinator-only. Compliance staff are locked out the same way.
- "Superintendent signs" executes the permit immediately. No confirmation, no summary of what is being signed.
- After execution the button still says "View draft v1", although an `_Executed.pdf` now exists.

**Fix:** add `preview: ["coord","comp","appr"]` to `PERM`. In `ACT["sup-sign"]`, open a confirm step first that shows permittee, dates, condition count and a "View permit" link. Relabel the button "View executed permit" once `p.supSigned` is set.

### 2. A permit can be sent for signature in the wrong state — High, Observed
- **Stale draft.** On 0010 I unticked GEN-01. The warning "Conditions changed since DraftPermit_v2. Regenerate the draft before sending" appeared, but "Send for signature" stayed enabled and went through.
- **Preview lies about the version.** `openPreview` renders the live conditions under the old file name. It showed 16 conditions labelled `DraftPermit_v2.docx`, a file generated with 17.
- **Unfilled placeholders.** 0013 went out for signature with WLD-01 still reading `[START DATE – confirm with biologist]`. The placeholder is highlighted but nothing stops it.

**Fix:**
- In `primaryActions`, disable `send-sig` when `p.condDirty`, with the reason "Regenerate the draft first".
- In `ACT["gen-draft"]`, store a snapshot (`p.draftSnapshot`) and have `openPreview` render that.
- Block `gen-draft` and `send-sig` while any included condition matches `/\[[^\]]+\]/`, and show "1 condition still needs dates filled in" linking to it.

### 3. Toasts cover the controls people need next — High, Observed
- At 1280×900, two of four real clicks on "Mark complete" were intercepted by the toast stack. The stack also hides the signature status pills.
- At 400 px, three stacked toasts cover about half the screen, including "Mark COI received" and the action bar.
- Toasts stay 7 seconds and stack three deep (`toast()`, line 579).

**Fix:** show one message at a time, for about 4 seconds, in a strip directly under the record header (a "what just happened" line) instead of a floating stack. This is also closer to what Power Apps can do (see finding 20).

### 4. The insurance gate accepts any date — Medium, Observed
- I recorded a COI expiring 2025-01-01. The app answered "COI recorded… reminders scheduled at 30 and 7 days before 2025-01-01".
- With that expired certificate on 0008, "Superintendent signs" was enabled. The gate only checks `p.coiReceived`.
- The date field is prefilled with today + 365 days, so one click records an invented expiry date.

**Fix:** leave `#coi-exp` blank by default. In `ACT.coi`, reject dates in the past and warn when the date is before `p.end`. Replace the `!p.coiReceived` checks in `primaryActions` and `tabSigs` with a `coiValid(p)` helper that also checks the date.

### 5. Keyboard focus is lost after every action — Medium, Observed
- `render()` replaces `#app`'s HTML, so after Suggest, Generate, Send, Close and the rest, `document.activeElement` is `<body>`. A keyboard user starts from the top of the page each time.
- The draft preview has no focus trap. The first Tab leaves the dialog and lands on links behind it. Esc closes it but does not return focus to the button that opened it. No scroll lock is applied to the page behind (Source).
- "Close permit" shows its confirmation without moving focus to it (Withdraw and Deny do focus their reason field).
- The record tabs have `role="tab"` but no arrow-key support.
- New-application errors ("Required") are not tied to their fields with `aria-describedby`, so a screen reader will not announce them.
- There is no skip link past the header.

**Fix:**
- In `render()`, remember the focused element's `data-act`, `data-arg` or `id` and refocus the matching element afterwards.
- Build the preview as a `<dialog>` opened with `showModal()`.
- In `ACT.close`, focus `[data-act="close-yes"]`.
- Add ArrowLeft and ArrowRight handling with a roving `tabindex` on `.tabs`.
- In the `f()` helper in `viewNew`, add `aria-describedby="${id}-err"` to each input.

### 6. State that is wrong or sticks — Medium, Observed
- **Withdrawn and denied steppers are wrong.** `stepper()` guesses with `reached = p.conditions.length ? 2 : 1`. 0009, withdrawn while out for permittee signature, shows progress only to Draft Permit. A new application withdrawn at Under Review shows "Draft Permit" as done although no draft was ever made.
- **0006 contradicts itself.** The Compliance tab shows 2 of 2 complete; Details shows "Compliance complete: No". Nothing tells the coordinator the permit is ready to close.
- **The open tab follows you.** After viewing 0013's Audit trail, 0005 opens on Audit trail.
- **"New application" gets stuck.** After a submit, the nav item keeps showing "Application submitted" until "Enter another" is clicked.
- **The demo decays in January.** With the clock set to 20 Jan 2027, 0011–0013 renumber to `SUP-2027-…` and the hard-coded `number === "SUP-2026-00xx"` checks in `buildSample` stop matching: 0013 loses its site plan and 0011 loses all eight conditions. By 1 Mar 2027, 0008–0010 are affected too and 0010 loses draft v2. Renumbering starts around 4 January 2027; 0013 first loses data around 11 January.

**Fix:**
- Save `p.lastStatus` in `ACT["offramp-yes"]` and use it in `stepper()`.
- Derive "compliance complete" from the items instead of a separate flag.
- Reset `state.tab = "details"` when the permit id changes in `render()`.
- Clear `state.newResult` on leaving `#new`.
- In `buildSample`, keep the original number (`const key = r[0]`) and compare against that.

### 7. Content cut off with no cue — Medium, Observed
- **Condition library at 1280 px.** The table is 899 px wide in a 689 px container. "Always" and "Active" are off-screen; the Active checkbox sits at x=899 against a right edge of 746. Nobody will find the on/off switch.
- **Mobile nav.** At 400 px "Condition library" and "Reports" are off-screen and the scrollbar is hidden (`scrollbar-width:none`, line 80).
- **Mobile stepper.** On an Active permit the current step sits at x=609 in a 367 px strip and is never scrolled into view.
- **Mobile tabs.** After "Begin compliance monitoring" the selected tab is off-screen (466–642 in a 384 px strip).
- **Preview notice.** `.notice` is a flex row, so "Generated from / file name / and saved to…" renders as three separate columns.

**Fix:**
- Make "Active" the second column of `.libtable` and drop the 300 px minimum on `td.ctxt`.
- Replace the mobile nav with a menu button or a two-row wrap.
- Call `scrollIntoView({inline:"center"})` on `.stepper .cur` and the selected tab after each render.
- Wrap the notice text in a single `<div>`.

---

## 2. UX

### 8. The next step is not obvious on the permit record — High, Observed
- **Under Review.** The highlighted button is "Generate draft permit", and it is disabled. The real next step, "Suggest conditions", is styled as secondary.
- **Active.** "Close permit" is the highlighted action from the first second, with four compliance items open.
- **Waiting on someone else.** As coordinator on a permit awaiting the Superintendent, the only prominent control is a disabled button. Nothing says "Waiting on R. Okafor since Nov 23; you still need to record the COI."
- **The hint line describes the role, not the task.** "Coordinator: you can move the permit through every step except…" repeats on every record.
- **Stalled permits are invisible.** 0011 has been Under Review for two weeks and appears nowhere in Needs attention.

**Fix:** replace `roleHint` with a `nextStep(p, role)` sentence and exactly one primary button per status. Examples: "Next: suggest conditions, then generate the draft." / "Waiting on the permittee, sent 9 days ago." / "2 of 4 compliance items open. Close when all are done." Add an "Under review for N days" reason to `reasons()`.

### 9. All three roles see the coordinator's app — High, Observed
- The Superintendent lands on "Permit desk" with coordinator KPIs and a "New application" button that leads to a form they can fill in but not submit.
- There is no "Waiting for your signature" list and no "My compliance items" list.
- On a record, the Superintendent sees four buttons, three of them disabled with "· Coordinator only". The toast says the real app hides these, so the mock-up should hide them too.
- The Superintendent has no way to decline or send a permit back. The kit already plans for this (`kit/flows.md` line 402 logs "Superintendent rejected" with comments), so the mock-up is behind the design here.
- Once sent, conditions are locked with only a note that "the real app would create a new draft version".

**Fix:**
- In `viewDashboard`, branch on `state.role`: the approver gets "Waiting for your signature" first, compliance gets items sorted by due date.
- In `btn()`, return an empty string when the role lacks permission instead of a disabled button.
- Hide "New application" for non-coordinators.
- Add a "Return for changes" action for the approver that sets the status back to Draft Permit with a required note.

### 10. Irreversible steps are not confirmed — Medium, Observed (Regenerate: Source)
- No confirmation on: Send for signature (emails an outside party), Superintendent signs, Regenerate draft, and switching a library condition off.
- Switching off GEN-01, a standard condition on every permit, is one checkbox click with no audit entry.
- Unticking an "Always included" condition on a permit gives no warning.
- Withdraw and Deny accept an empty reason. The audit trail records "No reason given" and the toast says the applicant was emailed.
- Close permit does confirm, and warns about open compliance items. That pattern is right; reuse it.

**Fix:** reuse the `.confirm` strip for `send-sig`, `sup-sign` and `lib-active` ("This removes GEN-01 from all future permits"). Make `#offramp-reason` required in `ACT["offramp-yes"]`.

### 11. There is nothing to review and nowhere to attach a file — Medium, Observed
- The Details tab has no editable fields. A coordinator cannot correct the impacts, which drive the conditions, or the dates.
- Documents are plain text rows: no link to open a file, no upload.
- "Mark COI received" and "Mark complete" each create a PDF from nothing. Staff will ask where they attach the certificate or inspection record.
- A compliance item due 1 March 2027 could be marked complete today, with no note.

**Fix:**
- Add "Edit details" covering at least impacts and dates, and after a change to impacts show "Impacts changed. Re-run condition suggestions?".
- Put a mock "Attach file" picker in front of `ACT.coi` and `ACT["complete-item"]`.
- Ask for a completion date and note on compliance items.
- Make file names look and behave like links.

### 12. Builder language is shown to program staff — Medium, Observed
- **Toasts:** "PermitConditions.Included updated", "The e-sign webhook flow sets PermitteeSigned", "SignatureRequestId is stored on the permit".
- **Screens:** "ComplianceComplete = Yes", "FolderPath:", column headers "DocType" and "PermitNumber", audit actors such as "flow: SUP-SignatureWebhook", and the library subtitle "Rule: Active AND (type matches or…)".
- **Terms never explained:** "executed" and "unexecuted", "COI" (spelled out once, on Details), and "Proposed end" against "Permit expiration". 0005 expires before its proposed end, which makes the difference more confusing.
- **Ambiguous button:** "Record permittee signed" does not say whether the coordinator does this or the system does.

**Fix:**
- Split each message into a plain line ("GEN-01 removed from this permit") and a builder note behind a header switch, "Show how it's built", off by default.
- Rename the KPI "Unexecuted, start ≤ 30 days" to "Not fully signed, starts within 30 days".
- Show audit actors as "Automatic (signature service)".
- Label the simulated steps "Simulate: permittee signs".

### 13. Condition reasons are clear, but the list around them needs work — Medium, Observed
- **What works:** each condition shows "Triggered by: Ground disturbance" or "Always included", and the green banner names the permit type and impacts used. A coordinator can see why each one is there.
- **Type limits are not mentioned.** OPS-04 applies only to two permit types, but its reason names only the trigger.
- **Nothing shows what was left out,** so staff cannot check for a missing condition without opening the library.
- **Re-running reads as a failure.** On a permit that already has its conditions, the toast says "0 condition(s) suggested".
- **New applications arrive with conditions; the sample permits 0012 and 0013 arrive with none.** The demo shows two different behaviours for the same step.
- **Sixteen conditions in one flat list** is a lot to scan. Six of them are the same standard set every time.
- **Staff-added conditions say it twice:** an "Added by staff" pill and an "Added by staff (edited)" reason line.

**Fix:**
- In `suggestFor`, append "for Construction / Access permits" when `c.types.length`.
- Group the list by category and collapse "Standard conditions (6)".
- Add a "Not suggested (6)" disclosure with a one-line reason each.
- Change the zero case to "Conditions are up to date".
- Pick one intake behaviour and seed the sample data to match.

---

## 3. UI and visual design

### 14. The dashboard has too many colour systems, and the KPI row is the template tell — Medium, Observed
- Status pills, reason pills, date tiles, KPI borders and the pipeline bar all use colour independently. Amber means both "Out for signature" (a status) and "warning" (a reason). A green "Active" pill sits beside a red "Compliance overdue" pill on the same row.
- The date tile mixes two meanings in one slot: a deadline ("Dec 7, in 14d") and an elapsed time ("Nov 14, 9d ago").
- Five equal cards with a coloured left border is the stock dashboard pattern. "10 Open permits" is not something anyone acts on.
- Status counts appear three times: the pipeline bar, its legend, and the Reports chart.
- The page subtitle spends the best spot on "reminders run daily at 7:00 (60/30/7-day expiry…)", which is configuration.

**Fix:**
- Keep colour for urgency only. Make status pills neutral, outlined, with no dot.
- Label the tile "Due" or "Waiting" above the date.
- Replace the KPI row with filter chips on the queue itself ("3 start within 30 days, unsigned", "2 COIs expiring", "2 awaiting signature") that filter Needs attention in place.
- Drop the pipeline bar and keep the legend as the clickable list.
- Move the reminder schedule to a footnote.

### 15. The record page gives every field the same weight — Medium, Observed
- Details is a 14-field grid of uppercase micro-labels. The dates that drive the work (start, expiry, COI expiry) look the same as the phone number.
- Four date formats are in use: `2026-12-21` in Details and tables, "Dec 21" on the dashboard, "Nov 23, 2026" in signatures, `mm/dd/yyyy` in inputs.
- Monospace is used for permit numbers, file names, list names, paths and audit times. Together with the uppercase labels this reads as a developer admin panel, not a staff tool.
- The text explaining why a button is disabled is the least readable text on the page: `.lock` is 11.5 px at 2.0:1 contrast, and 1.2:1 on a primary button, in both themes.
- Marginal contrast in light mode: `.pill.good` 4.45:1, `.actions .hint` 4.41:1, the "4d ago" tile text 4.1:1 at 11 px. Dark mode passes apart from disabled controls.
- The permits table is sorted by received date but has no Received column and no sort indicator, so the numbers look shuffled (0012, 0013, 0011… 0007, 0014, 0003).

**Fix:**
- Put a "Key dates" strip (Start, Ends, Permit expires, COI expires, each with days remaining) above the grid.
- Use one date format everywhere, such as "Dec 21, 2026".
- Keep monospace for permit numbers and file names only.
- Move the lock reason out of the button into normal-contrast caption text, or hide the button (finding 9).
- Darken `--good` to about `#256b41` and `--muted` to about `#5a655f`.
- Add a Received column and a sort arrow.

### 16. The mobile layout is the desktop layout squeezed — Medium, Observed
- **Permits list.** A 965 px table in a 366 px viewport. Only the number and project are visible; status needs a sideways scroll.
- **Record page.** Tab content starts at y=720 of an 800 px screen. Above it sit the banner (50 px, wrapped as "MOCK-/UP"), the sticky header (95 px), the title card, the stepper, four buttons and the hint.
- **Condition library.** The page is about 10,000 px tall on a phone, shows only the Code and Condition columns, and puts "Test the rules" at the very bottom, under all 22 rows.
- **Charts.** The monthly chart is cut off at June with no cue that it scrolls sideways. The two bar charts scale their text down to 7.2 px on a phone. On desktop the top chart's text is 21 px while the two charts below it are 11.6 px, because each SVG scales by its `viewBox`.

**Fix:**
- Under 640 px, render permits as cards: number and status pill, title, start and expiry.
- Collapse the stepper to "Step 2 of 8 · Under Review", and move Withdraw and Deny into a "More" menu.
- Shorten the banner to "Mock-up · sample data".
- On the condition library, put "Test the rules" above the table under 900 px and collapse each condition's wording behind its title.
- In `svgBarsV` and `svgBarsH`, size the SVG to its container's pixel width so text stays 12 px.

---

## 4. Fidelity to Power Apps on SharePoint

Confidence is marked on each finding. "facts.md" means the project's own verified notes in `spec/facts.md`. "Docs/community" means this session's searches. "Unverified" means my working knowledge, not checked against a tenant.

### 17. Signing is shown as buttons inside the app with instant status updates — High (facts.md)
- With Adobe Acrobat Sign or DocuSign, people sign in the provider's email or web page, not with a button in the app. The Superintendent role in the mock-up implies otherwise.
- SharePoint eSignature has no documented Power Automate trigger or action. With that option, "permittee signed" would not update by itself. A person or a scheduled check would have to set it. It is also $2 per request, and government-cloud availability is unverified.
- Adobe and DocuSign connectors are Standard tier but need a paid provider subscription.
- An Approvals step is not a legal signature.
- In the kit's standard-licence fallback (`kit/flows.md`, F4 fallback), the coordinator uploads the permittee's signed PDF and the Superintendent answers an Approvals request. The mock-up shows neither the upload nor the approval.

**Change in the mock-up:** label the buttons "Simulate: permittee signs in [e-sign tool]". Under Signature routing add "Status updates automatically only if the chosen e-sign tool supports it; otherwise the coordinator records it."

### 18. Draft generation and the in-app permit preview — High (facts.md; preview from docs/community)
- "Populate a Microsoft Word template" is a Premium connector (facts.md). The mock-up presents it as a given.
- `kit/flows.md` says a template path chosen per permit type may not be mappable at design time, which would mean one branch per template. The kit marks this "verify".
- The preview modal shows a formatted permit inside the app. Microsoft documents the canvas PDF viewer as PDF-only. Community reports say it cannot open an authenticated SharePoint link directly. I found no confirmation that it can show a `.docx`. The safe assumption is that the button opens the file in Word in a new browser tab.

**Change in the mock-up:** rename the button "Open draft in Word", and mark the preview "Illustration of the generated Word file". Add "Requires one Power Automate Premium licence" to the generate toast.

### 19. Intake claims Forms cannot meet — High (facts.md and kit/flows.md)
- The New application page says it has "the same fields the public Microsoft Forms application collects", and intake produces `_Application.pdf` and `_SitePlan_1.pdf`.
- Forms does not allow file upload when anyone outside the organisation can respond. A public applicant cannot attach a site plan.
- No flow in `kit/flows.md` creates an application PDF. F1 writes the Forms response to a Permits list item and creates the folder. The `_Application.pdf` in every sample folder is something the kit does not build.
- Outside applicants cannot use a canvas app without guest accounts.

**Change in the mock-up:** show the application as a list record, not a PDF. Show the site plan as "requested by email / file request link".

### 20. Canvas-app behaviours the mock-up takes for granted — Medium (mixed)
- **Role-based buttons (docs/community).** Power Apps has no built-in "is this user in a SharePoint group" function. It needs a workaround: a flag item with restricted permissions, a flow calling SharePoint, or Microsoft 365 groups. Hiding a button is not security.
- **Permissions do not match what the mock-up's roles can do (kit/Provision-SUPSite.ps1, lines 354–389).** The script gives Coordinators Contribute on the site but Read on ConditionLibrary, Settings and AuditLog. Compliance staff get Contribute on ComplianceItems and Permit Records and Read elsewhere. Approving officials get Read everywhere. That means:
  - A coordinator cannot switch a library condition on or off. The mock-up lets them.
  - A Superintendent with Read cannot write a signature date from an in-app button. Signing has to come through the e-sign tool or Approvals.
  - Compliance staff cannot set "Compliance complete" on the permit. A flow has to.
  - Coordinators *can* complete compliance items in SharePoint. The mock-up's toast, "the SharePoint permission blocks the write", is wrong for that case.
  - `spec/data-model.md` line 8 still says Coordinators have Edit; the script uses Contribute. One of them needs correcting.
- **The audit trail shows more than the flows write (kit/flows.md).** The kit's flows log creation, the suggestion run, generated documents, signatures, reminders, status changes and the move to Closed. They do not log a condition being ticked or reworded, a COI being recorded, or a compliance item being completed, and users cannot write to AuditLog themselves. The mock-up shows all of those as audit entries.
- **One layout for desktop and phone, automatic dark mode (unverified).** Canvas apps are fixed-size by default. A layout that reflows from 1280 to 400 px means building every screen with responsive containers, or building separate phone and tablet apps. There is no automatic dark theme. Show the dark and mobile views to staff only if the team intends to build them.
- **Stacked toasts, sticky headers, hover states, IBM Plex (unverified).** `Notify()` shows one banner at the top. Fonts come from a built-in list.
- **Search and counts (docs, partly conflicting; SharePoint specifics unverified).** A query that cannot be delegated to SharePoint only sees the first 500 rows by default. One Microsoft article says `CountRows` on SharePoint is not delegated; whether multi-column search and multi-choice filters (Impacts) delegate was not confirmed. The dashboard counts will be right while the Permits list is small and silently wrong after that, so decide the limit up front.
- **Charts (unverified).** Canvas chart controls are basic: no value labels, no muted current month. Reports like these usually mean Power BI, which needs a Pro licence per viewer (facts.md).

---

## What I could not test

- **The real platform.** No Power Apps, SharePoint or Power Automate tenant was used. Section 4 rests on `spec/facts.md`, three documentation searches and my working knowledge, marked per finding.
- **Screen readers.** I inspected roles, labels and focus in the DOM, but did not run VoiceOver or NVDA.
- **Other browsers and real devices.** Headless Chrome only. 400 px was emulated at 2× with mouse events, not touch. Safari and Firefox were not run.
- **The hosted wrapper.** The file was loaded from disk in the minimal shell, not as it would be published. Fonts came from Google Fonts; the offline fallback was not viewed.
- **Zoom, high-contrast mode, reduced motion, print, and colour-blindness simulation.**
- **Every combination.** I did not exercise every permit × role × tab, and did not test long lists or performance.
- **Role gating through forced events** is noted only in passing: removing `disabled` in dev tools lets Compliance staff toggle a condition or deactivate a library entry, because the `change` handlers at lines 1032–1033 have no role check. That is low risk in a mock-up.

## Sources for section 4

- `spec/facts.md`, `spec/review-architecture.md`, `kit/flows.md` and `kit/Provision-SUPSite.ps1` in this repo
- [Understand delegation in a canvas app](https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/delegation-overview)
- [Small data payloads in Power Apps](https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/small-data-payloads)
- [PDF viewer control in Power Apps](https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-pdf-viewer)
- [Power Apps: view a PDF stored in a SharePoint document library](https://www.matthewdevaney.com/?p=4481)
- [Role based security in Power Apps using Flow and SharePoint groups](https://microsoft.com/en-us/power-platform/blog/?p=756)
- [Power Apps: check if the current user is in a SharePoint group](https://collab365.com/blog/power-apps-check-is-current-user-is-in-a-sharepoint-group)
