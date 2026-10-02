#!/usr/bin/env python3
"""Pin LibreOffice to the dark desktop: Colibre Dark icons + Dark appearance.

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
GTK3 = Path.home() / ".config/gtk-3.0/settings.ini"
GTK4 = Path.home() / ".config/gtk-4.0/settings.ini"

EMPTY = """\
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></oor:items>
"""

GTK_INI = """\
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
"""

# Appearance.ApplicationAppearance: 0=Auto, 1=Light, 2=Dark.
# LibreOfficeTheme is a gallery index — leave at 0 (default). Do not set 2.
# SymbolStyle must be colibre_dark — plain colibre is the light icon pack.
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
    ("/org.openoffice.Office.Common/Misc", "SymbolStyle", "colibre_dark"),
    ("/org.openoffice.Office.Common/Misc", "ShowTipOfTheDay", "false"),
    ("/org.openoffice.Office.Common/Appearance", "ApplicationAppearance", "2"),
    ("/org.openoffice.Office.Common/Appearance", "LibreOfficeTheme", "0"),
    ("/org.openoffice.Office.Common/Appearance", "UseOnlyWhiteDocBackground", "false"),
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


def pin_gtk() -> None:
    for path in (GTK3, GTK4):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(GTK_INI, encoding="utf-8")


def main() -> int:
    if LOCK.exists() and os.environ.get("LIBREOFFICE_UI_FORCE") != "1":
        print("libreoffice is running; skip (set LIBREOFFICE_UI_FORCE=1 to write anyway)", file=sys.stderr)
        return 2

    pin_gtk()
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
