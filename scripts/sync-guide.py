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
  subgraph pa["Power Automate: 8 flows, run as the service account"]
    f1["Intake"] ~~~ f2["Number and folder"] ~~~ f3["Suggest conditions"] ~~~ f4["Draft permit"]
    f5["Signature routing"] ~~~ f6["Close and move"] ~~~ f7["Status audit"] ~~~ f8["Daily reminders"]
  end
  mail["Outlook shared mailbox<br/>Applicant notices and reminder digests"]
  sign["E-signature or Approvals<br/>Permittee signs first, then the Superintendent"]
  forms --> sp
  app <--> sp
  sp --> pbi
  sp -- changes trigger flows --> pa
  pa -- flows write back --> sp
  pa --> mail
  pa --> sign
```'''

LIFE = '''```mermaid
flowchart LR
  A["Received<br/>Flow 2: number, folder"] --> B["Under review<br/>Flow 3: suggest conditions"]
  B --> C["Draft permit<br/>Flow 4: document built"]
  C --> D["Permittee signs first<br/>Flow 5"]
  D --> E["Superintendent signs second<br/>Flow 5"]
  E --> F["Executed<br/>signed PDF filed"]
  F --> G["Active<br/>compliance items tracked"]
  G --> H["Closed<br/>Flow 6: folder moved"]
  W["Withdrawn or denied<br/>at any stage"] --> H
```

At every stage, Flow 7 logs each status change and Flow 8 sends daily deadline reminders.'''

DIAGRAMS = {"System architecture": ARCH, "Permit lifecycle": LIFE}

def main():
    data = json.load(open(sys.argv[1]))["data"]
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
    print(f"wrote {out} ({len(md)} chars, doc rev {json.load(open(sys.argv[1])).get('rev')})")

main()
