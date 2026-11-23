#!/usr/bin/env python3
"""Wrap prototype/sup-coordinator.html (page content only) into a standalone
prototype/index.html that opens correctly by double-clicking.

Usage: python3 scripts/build-prototype.py
"""
import pathlib
root = pathlib.Path(__file__).resolve().parent.parent / "prototype"
body = (root / "sup-coordinator.html").read_text(encoding="utf-8")
page = (
    "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
    "<!-- Generated from sup-coordinator.html by scripts/build-prototype.py. Do not edit. -->\n"
    "<style>html{color-scheme:light}body{margin:0;font:14px system-ui,sans-serif}img{max-width:100%}[hidden]{display:none!important}</style>\n"
    "</head>\n<body>\n" + body + "\n</body>\n</html>\n"
)
(root / "index.html").write_text(page, encoding="utf-8")
print("wrote", root / "index.html", len(page), "bytes")
