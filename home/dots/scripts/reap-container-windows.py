#!/usr/bin/env python3
"""Drop Hyprland surfaces the moment an isolated desktop container stops.

docker stop leaves the last Wayland frame mapped. Kill the window first,
then the container. Leave Steam / Overwatch / Cursor alone.
"""

from __future__ import annotations

import json
import os
import re
import select
import subprocess
import sys
import time

CLASS_OF = {
    "chrome-dd": (r"^chrome-dd$",),
    "chrome-az": (r"^chrome-az$",),
    "chrome-hika": (r"^chrome-hika$",),
    "vscode": (r"^(code|Code)$",),
    "obsidian": (r"^(md\.Obsidian|obsidian)$",),
    "openlens": (r"^(open-lens|OpenLens)$",),
    "libreoffice": (r"^libreoffice",),
    "firefox": (r"^firefox$",),
    "zen": (r"^(zen|ZenBrowser)$",),
    "spotify": (r"^spotify",),
    "idea": (r"^jetbrains-idea",),
}

TELEGRAM = re.compile(r"^org\.telegram\.desktop")
TELEGRAM_NAMES = ("telegram-1", "telegram-2")
KEEP = re.compile(r"^(cursor|steam|steam_app_|dota2|gamescope)", re.I)
ANR = re.compile(r"not responding|не отвечает|hyprland-dialog", re.I)
DEAD_STATES = {"paused", "exited", "dead", "removing", "created"}
STOP_ACTIONS = {"pause", "die", "stop", "kill", "oom"}
SKIP_EVENTS = {"ollama", "omniroute", "steam", "overwatch", "terraria", "albion"}


def run(cmd: list[str], timeout: float = 1.2) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""
    return out.stdout or ""


def clients() -> list[dict]:
    raw = run(["hyprctl", "-j", "clients"], timeout=1.5).strip()
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def container_states() -> dict[str, str]:
    raw = run(["docker", "ps", "-a", "--format", "{{.Names}}\t{{.State}}"], timeout=2.0)
    out: dict[str, str] = {}
    for line in raw.splitlines():
        if "\t" not in line:
            continue
        name, state = line.split("\t", 1)
        out[name.strip()] = state.strip().lower()
    return out


def pid_alive(pid: int) -> bool:
    if pid <= 1:
        return False
    return os.path.exists(f"/proc/{pid}")


def addr_of(win: dict) -> str:
    addr = str(win.get("address") or "")
    if not addr:
        return ""
    return addr if addr.startswith("0x") else ("0x" + addr)


def kill_addresses(addrs: list[str]) -> None:
    addrs = [a for a in addrs if a]
    if not addrs:
        return
    parts = ["local n=0"]
    for addr in addrs:
        parts.append(
            f'local w=hl.get_window("address:{addr}");'
            "if w then "
            "hl.dispatch(hl.dsp.window.close({ window = w }));"
            "hl.dispatch(hl.dsp.window.kill({ window = w }));"
            "n=n+1 end"
        )
    parts.append("return n")
    run(["hyprctl", "repl", " ".join(parts)], timeout=1.2)


def class_owner(cls: str) -> str:
    for name, pats in CLASS_OF.items():
        if any(re.search(p, cls) for p in pats):
            return name
    return ""


def container_pids(name: str) -> set[int]:
    raw = run(["docker", "top", name, "-eo", "pid"], timeout=1.2)
    pids: set[int] = set()
    for line in raw.splitlines()[1:]:
        token = line.strip().split()[0] if line.strip() else ""
        if token.isdigit():
            pids.add(int(token))
    return pids


def should_reap(
    win: dict,
    name: str,
    action: str,
    states: dict[str, str],
    pids: dict[int, str],
) -> bool:
    cls = str(win.get("class") or win.get("initialClass") or "")
    title = str(win.get("title") or "")
    if KEEP.search(cls):
        return False
    if ANR.search(cls) or ANR.search(title):
        return True
    pid = int(win.get("pid") or 0)
    owner = pids.get(pid) or class_owner(cls)

    if TELEGRAM.search(cls):
        if pid > 1 and pid_alive(pid) and action not in STOP_ACTIONS:
            return False
        if action in STOP_ACTIONS and name in TELEGRAM_NAMES:
            return pids.get(pid) == name or (pid > 1 and not pid_alive(pid))
        if pid > 1 and not pid_alive(pid):
            return True
        if all(states.get(n) in DEAD_STATES for n in TELEGRAM_NAMES if n in states):
            return True
        return False

    if action in STOP_ACTIONS and name and owner == name:
        return True
    if owner and states.get(owner) in DEAD_STATES:
        return True
    if owner and pid > 1 and not pid_alive(pid):
        return True
    return False


def reap(name: str = "", action: str = "") -> int:
    states = container_states()
    pids: dict[int, str] = {}
    wanted = set()
    if name:
        wanted.add(name)
    if name in TELEGRAM_NAMES or not name:
        wanted.update(n for n in TELEGRAM_NAMES if n in states)
    if action in STOP_ACTIONS and name:
        for pid in container_pids(name):
            pids[pid] = name
    for tg in TELEGRAM_NAMES:
        if tg in wanted and states.get(tg) == "running":
            for pid in container_pids(tg):
                pids.setdefault(pid, tg)

    addrs: list[str] = []
    for win in clients():
        if not should_reap(win, name, action, states, pids):
            continue
        addr = addr_of(win)
        if addr:
            addrs.append(addr)
    if not addrs:
        return 0
    kill_addresses(addrs)
    return len(addrs)


def watch() -> int:
    cmd = [
        "docker",
        "events",
        "--filter",
        "type=container",
        "--format",
        "{{.Actor.Attributes.name}} {{.Action}}",
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)
    assert proc.stdout is not None
    try:
        reap()
        last = time.monotonic()
        while proc.poll() is None:
            ready, _, _ = select.select([proc.stdout], [], [], 0.2)
            now = time.monotonic()
            if now - last >= 2.0:
                reap()
                last = now
            if not ready:
                continue
            line = proc.stdout.readline()
            if not line:
                break
            parts = line.strip().split()
            if len(parts) < 2:
                continue
            ev_name, action = parts[0], parts[1].split(":")[0]
            if action not in STOP_ACTIONS:
                continue
            if ev_name in SKIP_EVENTS:
                continue
            reap(ev_name, action)
            reap(ev_name, action)
    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()
    return 0


def main() -> int:
    if sys.argv[1:] == ["watch"]:
        return watch()
    name = sys.argv[1] if len(sys.argv) > 1 else ""
    action = sys.argv[2] if len(sys.argv) > 2 else "stop"
    reap(name, action)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
