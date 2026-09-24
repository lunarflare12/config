#!/usr/bin/env python3
"""Surface container MPRIS (and PipeWire fallback) to the host now-playing widget."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time

MEDIA = (
    "chrome-dd",
    "chrome-az",
    "chrome-hika",
    "firefox",
    "zen",
    "spotify",
)

RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
STATE_DIR = os.path.join(RUNTIME, "aurora-mpris")
STATE_PATH = os.path.join(STATE_DIR, "active.json")
ART_PATH = os.path.join(STATE_DIR, "cover")
BUS = "unix:path=/tmp/xdg/bus"
_last_art_src = ""
_last_art_out = ""


def run(cmd: list[str], timeout: float = 4.0) -> tuple[int, str]:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""
    return proc.returncode, (proc.stdout or "").strip()


def running_media() -> list[str]:
    code, out = run(["docker", "ps", "--format", "{{.Names}}"])
    if code != 0 or not out:
        return []
    names = set(out.splitlines())
    return [name for name in MEDIA if name in names]


def busctl(container: str, args: list[str]) -> tuple[int, str]:
    return run(
        [
            "docker",
            "exec",
            "-e",
            f"DBUS_SESSION_BUS_ADDRESS={BUS}",
            container,
            "busctl",
            "--user",
            "--json=short",
            *args,
        ]
    )


def unwrap(obj):
    if isinstance(obj, dict) and "type" in obj and "data" in obj:
        data = obj["data"]
        if isinstance(data, dict):
            return {key: unwrap(val) for key, val in data.items()}
        if isinstance(data, list):
            return [unwrap(item) for item in data]
        return data
    return obj


def load_json(text: str):
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def mpris_names(container: str) -> list[str]:
    code, out = busctl(container, ["list"])
    if code != 0 or not out:
        return []
    payload = load_json(out)
    names: list[str] = []
    if isinstance(payload, list):
        for row in payload:
            name = ""
            if isinstance(row, dict):
                name = str(row.get("name") or row.get("NAME") or "")
            elif isinstance(row, str):
                name = row
            if name.startswith("org.mpris.MediaPlayer2."):
                names.append(name)
        if names:
            return names
    for line in out.splitlines():
        name = line.split()[0] if line.split() else ""
        if name.startswith("org.mpris.MediaPlayer2."):
            names.append(name)
    return names


def get_prop(container: str, name: str, iface: str, prop: str):
    code, out = busctl(
        container,
        ["get-property", name, "/org/mpris/MediaPlayer2", iface, prop],
    )
    if code != 0:
        return None
    parsed = load_json(out)
    if parsed is None:
        return None
    return unwrap(parsed)


def first_text(value) -> str:
    if isinstance(value, list):
        return first_text(value[0]) if value else ""
    if value is None:
        return ""
    return str(value)


def to_seconds(raw) -> float:
    try:
        n = float(raw)
    except (TypeError, ValueError):
        return 0.0
    if n <= 0:
        return 0.0
    if n > 10000:
        return n / 1_000_000.0
    return n


def pull_art(container: str, url: str) -> str:
    global _last_art_src, _last_art_out
    if not url:
        return ""
    if url == _last_art_src and os.path.isfile(ART_PATH):
        return _last_art_out
    path = url
    if path.startswith("file://"):
        path = path[7:]
    if not path.startswith("/"):
        return url if "://" in url else ""
    os.makedirs(STATE_DIR, exist_ok=True)
    dest = ART_PATH
    code, _ = run(["docker", "cp", f"{container}:{path}", dest], timeout=6.0)
    if code != 0 or not os.path.isfile(dest):
        return ""
    _last_art_src = url
    _last_art_out = "file://" + dest
    return _last_art_out


def snapshot_player(container: str, name: str) -> dict | None:
    status = first_text(get_prop(container, name, "org.mpris.MediaPlayer2.Player", "PlaybackStatus"))
    if not status:
        return None
    meta = get_prop(container, name, "org.mpris.MediaPlayer2.Player", "Metadata") or {}
    if not isinstance(meta, dict):
        meta = {}
    identity = first_text(get_prop(container, name, "org.mpris.MediaPlayer2", "Identity")) or container
    title = first_text(meta.get("xesam:title"))
    artist = first_text(meta.get("xesam:artist"))
    album = first_text(meta.get("xesam:album"))
    art = first_text(meta.get("mpris:artUrl"))
    length = to_seconds(meta.get("mpris:length"))
    position = to_seconds(get_prop(container, name, "org.mpris.MediaPlayer2.Player", "Position"))
    playing = status.lower() == "playing"
    return {
        "available": True,
        "playing": playing,
        "source": "container",
        "container": container,
        "name": name,
        "title": title,
        "artist": artist,
        "album": album,
        "identity": identity,
        "desktopEntry": container,
        "artUrl": pull_art(container, art) if art else "",
        "trackId": first_text(meta.get("mpris:trackid")) or "/",
        "length": length,
        "position": position,
        "canToggle": True,
        "canNext": bool(get_prop(container, name, "org.mpris.MediaPlayer2.Player", "CanGoNext")),
        "canPrevious": bool(get_prop(container, name, "org.mpris.MediaPlayer2.Player", "CanGoPrevious")),
        "canSeek": bool(get_prop(container, name, "org.mpris.MediaPlayer2.Player", "CanSeek")) and length > 0,
        "canRaise": False,
    }


def pipewire_fallback() -> dict | None:
    pw = shutil.which("pw-dump")
    if not pw:
        return None
    code, out = run([pw], timeout=5.0)
    if code != 0 or not out:
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    for obj in data:
        if not isinstance(obj, dict):
            continue
        if "Node" not in str(obj.get("type") or ""):
            continue
        info = obj.get("info") or {}
        props = info.get("props") or {}
        if props.get("media.class") != "Stream/Output/Audio":
            continue
        if str(info.get("state") or "").lower() != "running":
            continue
        app = first_text(props.get("application.name") or props.get("node.name"))
        media = first_text(props.get("media.name"))
        if not app and not media:
            continue
        return {
            "available": True,
            "playing": True,
            "source": "pipewire",
            "container": "",
            "name": "",
            "title": media if media and media.lower() not in ("playback", "audio stream") else app,
            "artist": app if media and media.lower() not in ("playback", "audio stream") else "",
            "album": "",
            "identity": app or "Audio",
            "desktopEntry": first_text(props.get("application.process.binary")),
            "artUrl": "",
            "length": 0,
            "position": 0,
            "canToggle": False,
            "canNext": False,
            "canPrevious": False,
            "canSeek": False,
            "canRaise": False,
        }
    return None


def empty() -> dict:
    return {
        "available": False,
        "playing": False,
        "source": "",
        "container": "",
        "name": "",
        "title": "",
        "artist": "",
        "album": "",
        "identity": "",
        "desktopEntry": "",
        "artUrl": "",
        "trackId": "/",
        "length": 0,
        "position": 0,
        "canToggle": False,
        "canNext": False,
        "canPrevious": False,
        "canSeek": False,
        "canRaise": False,
    }


def poll() -> dict:
    found: list[dict] = []
    for container in running_media():
        for name in mpris_names(container):
            snap = snapshot_player(container, name)
            if snap:
                found.append(snap)
    for snap in found:
        if snap["playing"]:
            return snap
    for snap in found:
        if snap["title"] or snap["artist"]:
            return snap
    pw = pipewire_fallback()
    if pw:
        return pw
    return empty()


def save_state(snap: dict) -> None:
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(snap, fh)
    os.replace(tmp, STATE_PATH)


def load_state() -> dict:
    try:
        with open(STATE_PATH, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return empty()


def call_player(container: str, name: str, method: str, extra: list[str] | None = None) -> int:
    args = ["call", name, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", method]
    if extra:
        args.extend(extra)
    code, _ = busctl(container, args)
    return code


def ctl(action: str, arg: str = "") -> int:
    state = load_state()
    if state.get("source") != "container" or not state.get("container") or not state.get("name"):
        return 1
    container = str(state["container"])
    name = str(state["name"])
    if action == "toggle":
        return call_player(container, name, "PlayPause")
    if action == "next":
        return call_player(container, name, "Next")
    if action == "previous":
        return call_player(container, name, "Previous")
    if action == "seek":
        try:
            ratio = min(1.0, max(0.0, float(arg)))
        except ValueError:
            return 1
        length = float(state.get("length") or 0)
        if length <= 0:
            return 1
        usec = str(int(ratio * length * 1_000_000))
        track = str(state.get("trackId") or "/")
        return call_player(container, name, "SetPosition", ["o", track, "x", usec])
    return 1


def loop() -> None:
    last = ""
    while True:
        snap = poll()
        save_state(snap)
        line = json.dumps(snap, ensure_ascii=False, separators=(",", ":"))
        if line != last:
            print(line, flush=True)
            last = line
        time.sleep(1.0)


def main() -> int:
    if len(sys.argv) > 1:
        action = sys.argv[1]
        arg = sys.argv[2] if len(sys.argv) > 2 else ""
        return ctl(action, arg)
    loop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
