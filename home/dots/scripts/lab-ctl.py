#!/usr/bin/env python3
"""Desktop lab status: VMs, containers, WireGuard, AmneziaWG."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys

WG_DIRS = ["/etc/wireguard"]
AWG_DIRS = ["/etc/amnesia", "/etc/amnezia"]
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")

_USER = os.environ.get("USER") or os.environ.get("LOGNAME") or "dd"
os.environ["PATH"] = (
    "/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/"
    + _USER
    + "/bin:"
    + os.environ.get("PATH", "")
)
SUDO = "/run/wrappers/bin/sudo"
PROTECT = os.path.expanduser("~/.config/scripts/awg-protect-endpoint.sh")


def run(cmd: list[str], timeout: float = 5.0) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=timeout)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 1, "", ""
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def iface_up(name: str) -> bool:
    return run(["ip", "link", "show", "dev", name], timeout=2.0)[0] == 0


def conf_meta(path: str) -> tuple[str, str]:
    label = ""
    folder = ""
    try:
        with open(path, encoding="utf-8") as fh:
            for _ in range(80):
                raw = fh.readline()
                if not raw:
                    break
                line = raw.strip()
                if not line:
                    continue
                if line.startswith("[Peer"):
                    break
                if not line.startswith("#"):
                    continue
                body = line[1:].strip()
                key, _, rest = body.partition(" ")
                key = key.rstrip(":=").lower()
                rest = rest.strip().strip("\"'")
                if not rest:
                    continue
                if key == "name" and not label:
                    label = rest[:80]
                elif key == "folder" and not folder:
                    folder = rest[:80]
    except OSError:
        pass
    return label, folder


def configs(dirs: list[str]) -> list[dict]:
    seen: set[str] = set()
    out: list[dict] = []
    for directory in dirs:
        if not os.path.isdir(directory):
            continue
        try:
            names = os.listdir(directory)
        except OSError:
            continue
        for filename in sorted(names):
            if not filename.endswith(".conf"):
                continue
            name = filename[:-5]
            if not NAME_RE.match(name) or name in seen:
                continue
            seen.add(name)
            path = os.path.join(directory, filename)
            label, folder = conf_meta(path)
            out.append(
                {
                    "name": name,
                    "label": label or name,
                    "folder": folder,
                    "up": iface_up(name),
                    "path": path,
                }
            )
    return out


def vms() -> list[dict]:
    code, text, _ = run(["virsh", "-c", "qemu:///system", "list", "--state-running", "--name"])
    if code != 0:
        return []
    items = []
    for line in text.splitlines():
        name = line.strip()
        if name:
            items.append({"name": name, "state": "running"})
    return items


def parse_container_state(status: str, state: str) -> str:
    st = (state or "").strip().lower()
    text = (status or "").strip().lower()
    if st == "paused" or "paused" in text:
        return "paused"
    if st == "running" or text.startswith("up"):
        return "running"
    if st:
        return st
    if text.startswith("exited") or "dead" in text:
        return "exited"
    return "unknown"


def container_stats() -> dict[str, dict]:
    code, text, _ = run(
        [
            "docker",
            "stats",
            "--no-stream",
            "--format",
            "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}",
        ],
        timeout=12.0,
    )
    out: dict[str, dict] = {}
    if code != 0:
        return out
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        out[parts[0]] = {
            "cpu": parts[1].strip(),
            "mem": parts[2].strip(),
            "memPerc": parts[3].strip() if len(parts) > 3 else "",
        }
    return out


def containers() -> list[dict]:
    code, text, _ = run(
        [
            "docker",
            "ps",
            "-a",
            "--format",
            "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.ID}}\t{{.State}}",
        ]
    )
    if code != 0:
        return []
    stats = container_stats()
    items = []
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        name = parts[0]
        ident = parts[3][:12] if len(parts) > 3 else ""
        state = parse_container_state(parts[2], parts[4] if len(parts) > 4 else "")
        usage = stats.get(name, {})
        items.append(
            {
                "name": name,
                "image": parts[1],
                "status": parts[2],
                "id": ident,
                "state": state,
                "cpu": usage.get("cpu", ""),
                "mem": usage.get("mem", ""),
                "memPerc": usage.get("memPerc", ""),
            }
        )
    return items


def public_tunnels(rows: list[dict], kind: str) -> list[dict]:
    return [
        {
            "name": row["name"],
            "label": row.get("label") or row["name"],
            "folder": row.get("folder") or "",
            "up": bool(row["up"]),
            "kind": kind,
        }
        for row in rows
    ]


def status() -> dict:
    return {
        "vms": vms(),
        "containers": containers(),
        "wireguard": public_tunnels(configs(WG_DIRS), "wireguard"),
        "amnezia": public_tunnels(configs(AWG_DIRS), "amnezia"),
    }


def ensure_protect_hooks(path: str) -> None:
    if not os.path.isfile(path) or not os.access(path, os.W_OK):
        return
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return
    if "awg-protect-endpoint.sh" in text:
        return
    hook_up = f"PreUp = {PROTECT} up %i"
    hook_after = f"PostUp = {PROTECT} up %i"
    hook_down = f"PostDown = {PROTECT} down %i"
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    inserted = False
    for line in lines:
        out.append(line)
        if not inserted and line.strip() == "[Interface]":
            out.append(hook_up + "\n")
            out.append(hook_after + "\n")
            out.append(hook_down + "\n")
            inserted = True
    if not inserted:
        return
    # /etc/amnesia is 0750 root:wheel — we can rewrite the file we own,
    # but cannot create a sibling .tmp.
    try:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("".join(out))
    except OSError:
        pass


def protect_endpoint(name: str, action: str) -> None:
    if not os.path.isfile(PROTECT):
        return
    run(["bash", PROTECT, action, name], timeout=5.0)


def toggle(kind: str, name: str) -> int:
    if not NAME_RE.match(name):
        print("invalid name", file=sys.stderr)
        return 2
    if kind == "wireguard":
        dirs, tool = WG_DIRS, "wg-quick"
    elif kind == "amnezia":
        dirs, tool = AWG_DIRS, "awg-quick"
    else:
        print("invalid kind", file=sys.stderr)
        return 2

    row = next((item for item in configs(dirs) if item["name"] == name), None)
    if row is None:
        print("config not found", file=sys.stderr)
        return 1

    ensure_protect_hooks(row["path"])
    action = "down" if row["up"] else "up"
    if action == "up":
        protect_endpoint(name, "up")
    code, out, err = run([tool, action, row["path"]], timeout=40.0)
    if action == "up" and code == 0:
        protect_endpoint(name, "up")
    elif action == "down" or code != 0:
        protect_endpoint(name, "down")
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)
    return code


def vpn_bin() -> str:
    path = "/run/current-system/sw/bin/vpn-ctl"
    if os.path.isfile(path):
        return os.path.realpath(path)
    found = shutil.which("vpn-ctl")
    return found or "vpn-ctl"


def _emit(out: str, err: str) -> None:
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)


def gui_toggle(kind: str, name: str) -> int:
    if os.geteuid() == 0:
        return toggle(kind, name)
    vpn = vpn_bin()
    dirs = WG_DIRS if kind == "wireguard" else AWG_DIRS
    row = next((item for item in configs(dirs) if item["name"] == name), None)
    if row:
        ensure_protect_hooks(row["path"])
    # NOPASSWD is the store path. `sudo -n vpn-ctl` (short name) cannot prompt
    # and always fails with "a password is required".
    try:
        proc = subprocess.run(
            [SUDO, "-n", "--", vpn, "toggle", kind, name],
            check=False,
            capture_output=True,
            text=True,
            timeout=40.0,
        )
    except subprocess.TimeoutExpired:
        print("vpn toggle timed out", file=sys.stderr)
        return 1
    if proc.returncode == 0:
        _emit(proc.stdout or "", proc.stderr or "")
        return 0
    err = proc.stderr or ""
    _emit(proc.stdout or "", err)
    if "password is required" not in err and "a terminal is required" not in err:
        return proc.returncode
    policy = "/etc/polkit-1/actions/org.aurora.vpnctl.policy"
    pkexec = "/run/wrappers/bin/pkexec"
    if os.path.isfile(policy) and os.path.exists(pkexec):
        pk = subprocess.run([pkexec, vpn, "toggle", kind, name], check=False)
        if pk.returncode == 0:
            return 0
        if pk.returncode not in (126, 127):
            return pk.returncode
    kitty = shutil.which("kitty") or "kitty"
    os.execvp(
        kitty,
        [
            kitty,
            "--class",
            "termfloat",
            "-o",
            "confirm_os_window_close=0",
            "-e",
            SUDO,
            "--",
            vpn,
            "toggle",
            kind,
            name,
        ],
    )
    return 1


def docker_action(action: str, name: str) -> int:
    if not NAME_RE.match(name):
        print("invalid name", file=sys.stderr)
        return 2
    if action == "pause":
        cmd = ["docker", "pause", name]
    elif action == "unpause":
        cmd = ["docker", "unpause", name]
    elif action == "restart":
        cmd = ["docker", "restart", name]
    elif action == "rm":
        cmd = ["docker", "rm", "-f", name]
    else:
        print("invalid docker action", file=sys.stderr)
        return 2
    code, out, err = run(cmd, timeout=40.0)
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)
    return code


def main() -> int:
    argv = sys.argv[1:]
    if not argv or argv[0] in ("status", "list"):
        json.dump(status(), sys.stdout, ensure_ascii=False, separators=(",", ":"))
        sys.stdout.write("\n")
        return 0
    if argv[0] == "toggle" and len(argv) >= 3:
        if os.geteuid() != 0:
            return gui_toggle(argv[1], argv[2])
        return toggle(argv[1], argv[2])
    if argv[0] == "gui-toggle" and len(argv) >= 3:
        return gui_toggle(argv[1], argv[2])
    if argv[0] == "docker" and len(argv) >= 3:
        return docker_action(argv[1], argv[2])
    print("usage: lab-ctl status | toggle wireguard|amnezia NAME | docker pause|unpause|restart|rm NAME", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
