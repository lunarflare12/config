#!/usr/bin/env python3
"""Build Aurora cursor themes from downloaded vsthemes packs."""
import runpy
from pathlib import Path

runpy.run_path(str(Path(__file__).with_name("install-cursors.py")), run_name="__main__")
