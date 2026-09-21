#!/usr/bin/env python3
"""Make LibreOffice look closer to Microsoft Office: tabbed ribbon + Colibre icons.

Surgical text edits only. Re-serializing registrymodifications.xcu with
ElementTree makes LibreOffice 26 reject the file ("invalid type xs:string").
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

XCU = Path.home() / ".config/libreoffice/4/user/registrymodifications.xcu"
LOCK = Path.home() / ".config/libreoffice/4/.lock"

EMPTY = """\
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></oor:items>
"""

# Schema lives in LO 26 share/registry/main.xcd (ToolbarMode.xcs is not shipped).
# ActiveWriter/Calc/Impress/Draw are xs:string UI files. Per-app Active is the
# Tabbed CommandArg (notebookbar.ui). LO 26 persists set nodes as
# org.openoffice.Office.UI.ToolbarMode:Application['Writer'] rather than Writer.
APP = "/org.openoffice.Office.UI.ToolbarMode/Applications/org.openoffice.Office.UI.ToolbarMode:Application"
SETTINGS: list[tuple[str, str, str]] = [
    ("/org.openoffice.Office.UI.ToolbarMode", "ActiveWriter", "notebookbar.ui"),
    ("/org.openoffice.Office.UI.ToolbarMode", "ActiveCalc", "notebookbar.ui"),
    ("/org.openoffice.Office.UI.ToolbarMode", "ActiveImpress", "notebookbar.ui"),
    ("/org.openoffice.Office.UI.ToolbarMode", "ActiveDraw", "notebookbar.ui"),
    (f"{APP}['Writer']", "Active", "notebookbar.ui"),
    (f"{APP}['Calc']", "Active", "notebookbar.ui"),
    (f"{APP}['Impress']", "Active", "notebookbar.ui"),
    (f"{APP}['Draw']", "Active", "notebookbar.ui"),
    ("/org.openoffice.Office.Common/Misc", "SymbolStyle", "colibre"),
    ("/org.openoffice.Office.Common/Misc", "ShowTipOfTheDay", "false"),
]


def item_xml(path: str, name: str, value: str) -> str:
    return (
        f'<item oor:path="{path}">'
        f'<prop oor:name="{name}" oor:op="fuse">'
        f"<value>{value}</value></prop></item>"
    )


def upsert(xml: str, path: str, name: str, value: str) -> str:
    new = item_xml(path, name, value)
    pat = re.compile(
        r"<item oor:path=\""
        + re.escape(path)
        + r"\">\s*<prop oor:name=\""
        + re.escape(name)
        + r"\"[^>]*>\s*<value>[^<]*</value>\s*</prop>\s*</item>",
        re.DOTALL,
    )
    if pat.search(xml):
        return pat.sub(new, xml, count=1)
    if "</oor:items>" not in xml:
        raise ValueError("xcu missing </oor:items>")
    return xml.replace("</oor:items>", new + "</oor:items>", 1)


def main() -> int:
    if LOCK.exists() and os.environ.get("LIBREOFFICE_UI_FORCE") != "1":
        print("libreoffice is running; skip (set LIBREOFFICE_UI_FORCE=1 to write anyway)", file=sys.stderr)
        return 2

    XCU.parent.mkdir(parents=True, exist_ok=True)
    xml = XCU.read_text(encoding="utf-8") if XCU.exists() else EMPTY
    if "oor:items" not in xml:
        print(f"unexpected xcu contents in {XCU}", file=sys.stderr)
        return 1

    for path, name, value in SETTINGS:
        xml = upsert(xml, path, name, value)

    XCU.write_text(xml, encoding="utf-8")
    print(f"wrote {XCU}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
