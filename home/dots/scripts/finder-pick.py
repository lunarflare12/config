#!/usr/bin/env python3
"""Portal file/folder picker. Folders open real Finder (Thunar); files use GTK3 WhiteSur."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time

os.environ["GTK_USE_PORTAL"] = "0"
os.environ["GDK_DEBUG"] = "no-portals"
os.environ.setdefault("GTK_THEME", "WhiteSur-Dark")
os.environ.setdefault("GTK_APPLICATION_PREFER_DARK_THEME", "1")
os.environ.setdefault("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk, Pango  # noqa: E402

HOME = os.path.expanduser("~")
FINDER = os.path.join(HOME, ".config/scripts/finder.sh")
XFCONF = "/run/current-system/sw/bin/xfconf-query"
HYPRCTL = shutil.which("hyprctl") or "hyprctl"

CSS = b"""
window {
  border-radius: 18px;
  background-color: #2b2b2b;
}
window.finder-pick-bar {
  border-radius: 16px;
  background-color: alpha(#2b2b2b, 0.92);
}
headerbar {
  min-height: 44px;
  background-image: none;
  background-color: #2b2b2b;
  box-shadow: none;
  border: none;
}
button {
  border-radius: 8px;
  min-height: 28px;
  padding: 4px 14px;
}
label.path {
  font-size: 13px;
  color: #f2f2f2;
}
"""


def parse_args(argv: list[str]) -> dict:
    if len(argv) >= 6:
        return {
            "multiple": argv[1] == "1",
            "directory": argv[2] == "1",
            "save": argv[3] == "1",
            "path": argv[4],
            "out": argv[5],
        }
    directory = "--directory" in argv or "-d" in argv
    save = "--save" in argv
    path = HOME
    for a in argv[1:]:
        if not a.startswith("-") and a != "--":
            path = a
            break
    return {
        "multiple": "--multiple" in argv,
        "directory": directory,
        "save": save,
        "path": path,
        "out": None,
    }


def write_out(path: str | None, selected: list[str]) -> int:
    selected = [p for p in selected if p]
    if path:
        if selected:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write("\n".join(selected) + "\n")
        return 0 if selected else 1
    if selected:
        sys.stdout.write("\n".join(selected) + "\n")
    return 0 if selected else 1


def start_folder(raw: str) -> str:
    path = os.path.expanduser(raw or HOME)
    if path in ("", ".", "None"):
        return HOME
    if os.path.isfile(path):
        return os.path.dirname(path) or HOME
    if os.path.isdir(path):
        return path
    parent = os.path.dirname(path)
    if parent and os.path.isdir(parent):
        return parent
    return HOME


def load_css() -> None:
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    screen = Gdk.Screen.get_default()
    if screen is not None:
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )


def apply_settings() -> None:
    settings = Gtk.Settings.get_default()
    if settings is None:
        return
    settings.set_property("gtk-application-prefer-dark-theme", True)
    settings.set_property("gtk-theme-name", "WhiteSur-Dark")
    settings.set_property("gtk-icon-theme-name", "WhiteSur-dark")
    settings.set_property("gtk-font-name", "Inter 13")
    settings.set_property("gtk-recent-files-enabled", False)
    settings.set_property("gtk-decoration-layout", "close,minimize,maximize:")


def gtk_file_chooser(opts: dict) -> list[str]:
    if opts["save"]:
        action = Gtk.FileChooserAction.SAVE
        title = "Save"
        ok = "_Save"
    elif opts["directory"]:
        action = Gtk.FileChooserAction.SELECT_FOLDER
        title = "Open Folder"
        ok = "_Select"
    else:
        action = Gtk.FileChooserAction.OPEN
        title = "Open"
        ok = "_Open"

    dialog = Gtk.FileChooserDialog(title=title, action=action)
    dialog.add_buttons("_Cancel", Gtk.ResponseType.CANCEL, ok, Gtk.ResponseType.OK)
    dialog.set_default_response(Gtk.ResponseType.OK)
    dialog.set_select_multiple(bool(opts["multiple"] and not opts["directory"] and not opts["save"]))
    dialog.set_local_only(True)
    dialog.set_create_folders(True)
    dialog.set_default_size(980, 640)
    dialog.set_do_overwrite_confirmation(bool(opts["save"]))

    start = start_folder(opts["path"])
    dialog.set_current_folder(start)
    raw = os.path.expanduser(opts["path"] or "")
    if opts["save"] and raw and not os.path.isdir(raw):
        dialog.set_current_name(os.path.basename(raw) or "Untitled")

    bookmarks = os.path.join(HOME, ".config/gtk-3.0/bookmarks")
    if os.path.isfile(bookmarks):
        with open(bookmarks, encoding="utf-8") as fh:
            for line in fh:
                uri = line.split()[0] if line.strip() else ""
                if uri.startswith("file://"):
                    folder = uri[7:]
                    if os.path.isdir(folder):
                        try:
                            dialog.add_shortcut_folder(folder)
                        except Exception:
                            pass

    try:
        resp = dialog.run()
        paths: list[str] = []
        if resp == Gtk.ResponseType.OK:
            paths = dialog.get_filenames() if dialog.get_select_multiple() else [dialog.get_filename()]
        return [p for p in paths if p]
    finally:
        dialog.destroy()


def thunar_clients() -> dict[str, dict]:
    try:
        data = json.loads(subprocess.check_output([HYPRCTL, "clients", "-j"], text=True))
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return {}
    out = {}
    for client in data or []:
        cls = str(client.get("class") or "").lower()
        if cls in {"thunar"}:
            out[client.get("address") or ""] = client
    return {k: v for k, v in out.items() if k}


def window_title(address: str) -> str:
    client = thunar_clients().get(address) or {}
    return str(client.get("title") or "")


def title_to_path(title: str, fallback: str) -> str:
    title = title.strip()
    if title.startswith("/") and os.path.isdir(title):
        return title
    if title.startswith("file://"):
        path = title[7:]
        if os.path.isdir(path):
            return path
    named = os.path.join(HOME, title) if title else ""
    if named and os.path.isdir(named):
        return named
    return fallback


def xfconf_full_path(enable: bool | None) -> bool | None:
    if not os.path.isfile(XFCONF):
        return None
    if enable is None:
        try:
            out = subprocess.check_output(
                [XFCONF, "-c", "thunar", "-p", "/misc-full-path-in-title"],
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
            return out.lower() in {"true", "1", "yes"}
        except subprocess.CalledProcessError:
            return None
    subprocess.run(
        [
            XFCONF,
            "-c",
            "thunar",
            "-p",
            "/misc-full-path-in-title",
            "-n",
            "-t",
            "bool",
            "-s",
            "true" if enable else "false",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return enable


def close_thunar(address: str) -> None:
    if not address:
        return
    subprocess.run(
        [HYPRCTL, "dispatch", "closewindow", f"address:{address}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def finder_directory_pick(start: str) -> list[str] | None:
    if not os.access(FINDER, os.X_OK):
        return None
    before = set(thunar_clients())
    try:
        subprocess.Popen(
            [FINDER, start],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        return None

    address = ""
    for _ in range(40):
        time.sleep(0.08)
        new = set(thunar_clients()) - before
        if new:
            address = next(iter(new))
            break
    if not address:
        return None

    prev = xfconf_full_path(None)
    xfconf_full_path(True)

    selected: list[str] = []
    current = [start]

    win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    win.set_title("Select Folder")
    GLib.set_prgname("finder-pick")
    win.set_decorated(False)
    win.set_keep_above(True)
    win.set_resizable(False)
    win.set_default_size(560, 72)
    win.get_style_context().add_class("finder-pick-bar")

    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    box.set_margin_top(12)
    box.set_margin_bottom(12)
    box.set_margin_start(16)
    box.set_margin_end(16)
    win.add(box)

    path_lbl = Gtk.Label(label=start, xalign=0)
    path_lbl.set_ellipsize(Pango.EllipsizeMode.MIDDLE)
    path_lbl.get_style_context().add_class("path")
    path_lbl.set_hexpand(True)
    box.pack_start(path_lbl, True, True, 0)

    cancel = Gtk.Button(label="Cancel")
    open_btn = Gtk.Button(label="Open")
    open_btn.get_style_context().add_class("suggested-action")
    box.pack_start(cancel, False, False, 0)
    box.pack_start(open_btn, False, False, 0)

    def finish(ok: bool) -> None:
        nonlocal selected
        if ok:
            selected = [current[0]]
        win.destroy()
        Gtk.main_quit()

    def tick() -> bool:
        if address not in thunar_clients():
            finish(False)
            return False
        path = title_to_path(window_title(address), current[0])
        current[0] = path
        path_lbl.set_text(path)
        return True

    cancel.connect("clicked", lambda *_: finish(False))
    open_btn.connect("clicked", lambda *_: finish(True))
    win.connect("destroy", lambda *_: Gtk.main_quit())
    GLib.timeout_add(200, tick)
    win.show_all()
    Gtk.main()

    xfconf_full_path(bool(prev) if prev is not None else False)
    close_thunar(address)
    return selected


def main() -> int:
    opts = parse_args(sys.argv)
    GLib.set_prgname("finder-pick")
    GLib.set_application_name("Finder")
    Gtk.init([])
    apply_settings()
    load_css()

    # Directory picks must be a real chooser (Select), not Finder/Thunar.
    # Opening Thunar here left Cursor waiting on a file-manager window
    # with no way to return a folder.
    selected = gtk_file_chooser(opts)

    return write_out(opts["out"], selected)


if __name__ == "__main__":
    sys.exit(main())
