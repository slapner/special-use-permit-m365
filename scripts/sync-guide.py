#!/usr/bin/env python3
"""Rebuild docs/build-guide.md from a Markdown export of the shared build guide.

Usage: python3 scripts/sync-guide.py <export-result.json>

The export drops the two diagrams and leaves placeholders; this puts the
Mermaid versions back and replaces the byline. Keep the Mermaid blocks below
in step with the diagrams in the shared doc.
"""
import base64, json, pathlib, re, sys

ARCH = '''```mermaid
flowchart TB
  forms["Microsoft Forms<br/>Public application form"]
  app["Coordinator app<br/>Power Apps, where staff work"]
  pbi["Power BI report<br/>Dashboard and metrics"]
  subgraph sp["SharePoint site: the system of record"]
    permits["Permits<br/>one row per permit"]
    lib["Condition Library<br/>rules as trigger tags"]
    audit["Audit Log<br/>written by flows only"]
    records["Permit Records<br/>Open / Closed folders"]
  end
  subgraph pa["Power Automate: 13 flows, run as the service account"]
    f1["F1a, F1b · Intake"] ~~~ f2["F2a, F2b · Conditions"] ~~~ f3["F3 · Draft permit"] ~~~ f4["F4a, F4b · Signatures"]
    f5["F5 · Close and move"] ~~~ f6["F6 · Daily reminders"] ~~~ f7["F7a, F7b · Audit log"] ~~~ f8["F8, F9 · Filing"]
  end
  mail["Outlook shared mailbox<br/>Applicant mail in and out, reminder digests"]
  sign["E-signature or Approvals<br/>Permittee signs first, then the Superintendent"]
  forms --> sp
  app <--> sp
  sp --> pbi
  sp -- changes trigger flows --> pa
  pa -- flows write back --> sp
  pa <--> mail
  pa --> sign
```'''

LIFE = '''```mermaid
flowchart LR
  A["Received<br/>F1b: number and folder"] --> B["Under Review<br/>F2: suggest conditions"]
  B --> C["Draft Permit<br/>F3: document built"]
  C --> D["Permittee signs<br/>first · F4a sends"]
  D --> E["Superintendent signs<br/>second · F4b or F4c"]
  E --> F["Executed<br/>signed PDF filed"]
  F --> G["Active<br/>compliance items tracked"]
  G --> H["Closed<br/>F5: folder moved"]
  W["Withdrawn or Denied<br/>any stage · F5 moves it"] --> H
```

At every stage, F7b logs each status change and F6 sends daily deadline reminders.'''

DIAGRAMS = {"System architecture": ARCH, "Permit lifecycle": LIFE}

def main():
    raw = json.load(open(sys.argv[1]))
    if isinstance(raw, list):  # saved tool result: [{type, text}], the export JSON is in one text item
        raw = next(json.loads(i["text"]) for i in raw if i.get("text", "").lstrip().startswith("{"))
    data = raw["data"]
    md = base64.b64decode(data["bytes_b64"]).decode("utf-8")
    def swap(m):
        for key, block in DIAGRAMS.items():
            if key in m.group(0):
                return block
        sys.exit(f"Unknown embedded content: {m.group(0)}")
    md, n = re.subn(r"(?:&#91;|\\?\[)embedded content:[^\n]*", swap, md)
    if n != len(DIAGRAMS):
        sys.exit(f"Expected {len(DIAGRAMS)} diagram placeholders, found {n}")
    lines = md.split("\n")
    lines[2] = "Markdown copy of the shared build guide. Edit the shared document, then re-run `scripts/sync-guide.py`."
    out = pathlib.Path(__file__).resolve().parent.parent / "docs" / "build-guide.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {out} ({len(md)} chars, doc rev {raw.get('rev')})")

main()
