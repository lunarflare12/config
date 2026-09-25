#!/usr/bin/env python3
"""Desktop lab status: VMs, containers, WireGuard, AmneziaWG, VLESS."""

from __future__ import annotations

import glob
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time

WG_DIRS = ["/etc/wireguard"]
AWG_DIRS = ["/etc/amnesia", "/etc/amnezia"]
# Dedicated watch dirs — only these are listed in Labs (not Amnezia GUI state).
VLESS_DIRS = [
    os.path.expanduser("~/.config/vless"),
    "/etc/amnesia/vless",
]
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")

_USER = os.environ.get("USER") or os.environ.get("LOGNAME") or "dd"
os.environ["PATH"] = (
    "/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/"
    + _USER
    + "/bin:"
    + os.path.expanduser("~/.local/bin")
    + ":"
    + os.environ.get("PATH", "")
)
SUDO = "/run/wrappers/bin/sudo"
PROTECT = os.path.expanduser("~/.config/scripts/awg-protect-endpoint.sh")
VLESS_RUN = "/run/aurora-vless"


def run(cmd: list[str], timeout: float = 5.0) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=timeout)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 1, "", ""
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def iface_up(name: str) -> bool:
    return run(["ip", "link", "show", "dev", name], timeout=2.0)[0] == 0


def _hash_meta_lines(path: str, stop_at: tuple[str, ...] = ()) -> tuple[str, str]:
    """Parse `# name …` / `# folder …` like WireGuard conf headers."""
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
                if any(line.startswith(s) for s in stop_at):
                    break
                if not line.startswith("#"):
                    # Non-comment body started (e.g. `{` for JSON) — stop.
                    if line.startswith("{"):
                        break
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


def conf_meta(path: str) -> tuple[str, str]:
    return _hash_meta_lines(path, stop_at=("[Peer", "[Interface"))


def json_meta(path: str) -> tuple[str, str]:
    return _hash_meta_lines(path)


def strip_hash_preamble(text: str) -> str:
    """Drop leading `# …` / blank lines so the JSON body is valid."""
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        if not s or s.startswith("#"):
            i += 1
            continue
        break
    return "".join(lines[i:])


def vless_pid_path(name: str) -> str:
    return os.path.join(VLESS_RUN, f"{name}.pid")


def vless_runtime_config(name: str) -> str:
    return os.path.join(VLESS_RUN, f"{name}.json")


def vless_up(name: str) -> bool:
    pid_path = vless_pid_path(name)
    try:
        with open(pid_path, encoding="utf-8") as fh:
            pid = int(fh.read().strip())
    except (OSError, ValueError):
        return False
    try:
        os.kill(pid, 0)
    except PermissionError:
        pass
    except OSError:
        try:
            os.unlink(pid_path)
        except OSError:
            pass
        return False
    # Confirm it is still our sing-box (or leftover xray) for this config.
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as fh:
            cmd = fh.read().replace(b"\0", b" ").decode("utf-8", "replace")
    except OSError:
        return False
    return name in cmd and ("sing-box" in cmd or "xray" in cmd)


def vless_configs() -> list[dict]:
    seen: set[str] = set()
    out: list[dict] = []
    for directory in VLESS_DIRS:
        if not os.path.isdir(directory):
            continue
        try:
            names = os.listdir(directory)
        except OSError:
            continue
        for filename in sorted(names):
            if not filename.endswith(".json"):
                continue
            stem = filename[:-5]
            if not NAME_RE.match(stem) or stem in seen:
                continue
            path = os.path.join(directory, filename)
            label, folder = json_meta(path)
            seen.add(stem)
            out.append(
                {
                    "name": stem,
                    "label": label or stem,
                    "folder": folder or "personal",
                    "up": vless_up(stem),
                    "path": path,
                    "kind": "vless",
                }
            )
    return out


def singbox_bin() -> str:
    candidates = [
        shutil.which("sing-box") or "",
        os.path.expanduser("~/.local/bin/sing-box"),
        "/run/current-system/sw/bin/sing-box",
        f"/etc/profiles/per-user/{_USER}/bin/sing-box",
    ]
    candidates.extend(sorted(glob.glob("/nix/store/*-sing-box-*/bin/sing-box"), reverse=True))
    for cand in candidates:
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return "sing-box"


def is_singbox(cfg: dict) -> bool:
    for row in list(cfg.get("inbounds") or []) + list(cfg.get("outbounds") or []):
        if row.get("type") and not row.get("protocol"):
            return True
    return False


def xray_to_singbox(cfg: dict) -> dict:
    """Map a VLESS/SOCKS xray client JSON onto sing-box."""
    if is_singbox(cfg):
        return cfg
    inbounds: list[dict] = []
    for ib in cfg.get("inbounds") or []:
        proto = str(ib.get("protocol") or ib.get("type") or "socks")
        if proto == "tun" or ib.get("type") == "tun":
            inbounds.append(ib)
            continue
        item: dict = {
            "type": proto,
            "tag": ib.get("tag") or f"{proto}-in",
            "listen": ib.get("listen") or "127.0.0.1",
            "listen_port": int(ib.get("listen_port") or ib.get("port") or 10818),
        }
        inbounds.append(item)
    if not inbounds:
        inbounds.append(
            {
                "type": "socks",
                "tag": "socks-in",
                "listen": "127.0.0.1",
                "listen_port": 10818,
            }
        )
    outbounds: list[dict] = []
    for ob in cfg.get("outbounds") or []:
        proto = str(ob.get("protocol") or ob.get("type") or "")
        if proto in {"freedom", "direct"}:
            outbounds.append({"type": "direct", "tag": ob.get("tag") or "direct"})
            continue
        if proto in {"blackhole", "block"}:
            outbounds.append({"type": "block", "tag": ob.get("tag") or "block"})
            continue
        if proto != "vless":
            if ob.get("type"):
                outbounds.append(ob)
            continue
        settings = ob.get("settings") or {}
        vnext = (settings.get("vnext") or [{}])[0]
        user = (vnext.get("users") or [{}])[0]
        ss = ob.get("streamSettings") or {}
        reality = ss.get("realitySettings") or {}
        tls_set = ss.get("tlsSettings") or {}
        item = {
            "type": "vless",
            "tag": ob.get("tag") or "proxy",
            "server": vnext.get("address") or ob.get("server"),
            "server_port": int(vnext.get("port") or ob.get("server_port") or 443),
            "uuid": user.get("id") or user.get("uuid") or "",
        }
        flow = user.get("flow") or ob.get("flow")
        if flow:
            item["flow"] = flow
            item["packet_encoding"] = "xudp"
        security = str(ss.get("security") or "")
        if security == "reality" or reality:
            item["tls"] = {
                "enabled": True,
                "server_name": reality.get("serverName") or reality.get("server_name") or "",
                "utls": {
                    "enabled": True,
                    "fingerprint": reality.get("fingerprint") or "chrome",
                },
                "reality": {
                    "enabled": True,
                    "public_key": reality.get("publicKey") or reality.get("public_key") or "",
                    "short_id": reality.get("shortId") or reality.get("short_id") or "",
                },
            }
        elif security == "tls":
            item["tls"] = {
                "enabled": True,
                "server_name": tls_set.get("serverName") or tls_set.get("server_name") or "",
            }
        network = str(ss.get("network") or "tcp")
        if network == "ws":
            ws = ss.get("wsSettings") or {}
            item["transport"] = {"type": "ws", "path": ws.get("path") or "/"}
        elif network == "grpc":
            grpc = ss.get("grpcSettings") or {}
            item["transport"] = {"type": "grpc", "service_name": grpc.get("serviceName") or ""}
        outbounds.append(item)
    if not any(ob.get("type") == "direct" for ob in outbounds):
        outbounds.append({"type": "direct", "tag": "direct"})
    return {
        "log": {"level": "warn"},
        "inbounds": inbounds,
        "outbounds": outbounds,
    }


def vless_listen_port(cfg: dict) -> int:
    for inbound in cfg.get("inbounds") or []:
        kind = str(inbound.get("type") or inbound.get("protocol") or "")
        if kind == "tun":
            return 0
        try:
            port = inbound.get("listen_port") or inbound.get("port")
            if port:
                return int(port)
        except (TypeError, ValueError):
            continue
    return 10818


def wait_vless_ready(proc: subprocess.Popen, port: int) -> bool:
    if port <= 0:
        for _ in range(25):
            if proc.poll() is not None:
                return False
            time.sleep(0.08)
        return proc.poll() is None
    for _ in range(25):
        if proc.poll() is not None:
            return False
        sock = socket.socket()
        try:
            sock.settimeout(0.15)
            sock.connect(("127.0.0.1", port))
            return True
        except OSError:
            time.sleep(0.08)
        finally:
            sock.close()
    return proc.poll() is None


def stop_vless_pid(pid_path: str) -> None:
    try:
        with open(pid_path, encoding="utf-8") as fh:
            pid = int(fh.read().strip())
        try:
            os.killpg(pid, 15)
        except OSError:
            os.kill(pid, 15)
    except (OSError, ValueError):
        pass
    try:
        os.unlink(pid_path)
    except OSError:
        pass


def toggle_vless(name: str) -> int:
    if not NAME_RE.match(name):
        print("invalid name", file=sys.stderr)
        return 2
    row = next((item for item in vless_configs() if item["name"] == name), None)
    if row is None:
        print("vless config not found", file=sys.stderr)
        return 1
    os.makedirs(VLESS_RUN, mode=0o755, exist_ok=True)
    os.chmod(VLESS_RUN, 0o755)
    pid_path = vless_pid_path(name)
    if row["up"]:
        stop_vless_pid(pid_path)
        try:
            os.unlink(vless_runtime_config(name))
        except OSError:
            pass
        return 0
    bin_path = singbox_bin()
    try:
        raw = open(row["path"], encoding="utf-8").read()
    except OSError as exc:
        print(f"cannot read config: {exc}", file=sys.stderr)
        return 1
    clean = strip_hash_preamble(raw)
    try:
        parsed = json.loads(clean)
    except json.JSONDecodeError as exc:
        print(f"invalid vless json: {exc}", file=sys.stderr)
        return 1
    runtime_cfg = xray_to_singbox(parsed)
    port = vless_listen_port(runtime_cfg)
    runtime = vless_runtime_config(name)
    try:
        with open(runtime, "w", encoding="utf-8") as fh:
            json.dump(runtime_cfg, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        os.chmod(runtime, 0o600)
    except OSError as exc:
        print(f"cannot write runtime config: {exc}", file=sys.stderr)
        return 1
    log_path = os.path.join(VLESS_RUN, f"{name}.log")
    try:
        log_fh = open(log_path, "a", encoding="utf-8")
    except OSError:
        log_fh = subprocess.DEVNULL
    try:
        proc = subprocess.Popen(
            [bin_path, "run", "-c", runtime],
            stdout=log_fh,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    except FileNotFoundError:
        print("sing-box binary not found", file=sys.stderr)
        return 1
    with open(pid_path, "w", encoding="utf-8") as fh:
        fh.write(str(proc.pid) + "\n")
    os.chmod(pid_path, 0o644)
    if not wait_vless_ready(proc, port):
        err = f"sing-box failed to listen on 127.0.0.1:{port}" if port else "sing-box failed to start"
        print(err, file=sys.stderr)
        try:
            os.kill(proc.pid, 15)
        except OSError:
            pass
        return 1
    return 0


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
    code, text, _ = run(["virsh", "-c", "qemu:///system", "list", "--all"], timeout=8.0)
    if code != 0:
        return []
    items = []
    for line in text.splitlines():
        raw = line.strip()
        if not raw or raw.startswith("Id") or set(raw) <= {"-", " "}:
            continue
        parts = raw.split()
        if len(parts) < 3 or not (parts[0] == "-" or parts[0].isdigit()):
            continue
        name = parts[1]
        state_raw = " ".join(parts[2:]).lower()
        if "running" in state_raw:
            state = "running"
        elif "paused" in state_raw:
            state = "paused"
        else:
            state = "shut off"
        items.append({"name": name, "state": state})
    return items


def vm_action(action: str, name: str) -> int:
    if not NAME_RE.match(name):
        print("invalid name", file=sys.stderr)
        return 2
    if action == "start":
        cmd = ["virsh", "-c", "qemu:///system", "start", name]
    elif action in ("stop", "shutdown"):
        cmd = ["virsh", "-c", "qemu:///system", "shutdown", name]
    elif action == "destroy":
        cmd = ["virsh", "-c", "qemu:///system", "destroy", name]
    else:
        print("invalid vm action", file=sys.stderr)
        return 2
    code, out, err = run(cmd, timeout=40.0)
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)
    return code


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
            "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}",
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
            "net": parts[4].strip() if len(parts) > 4 else "",
        }
    return out


# App-isolation boxes (compose under ~/containers). Not lab toys.
APP_PROJECTS = {
    "apps-isolated",
    "telegram-isolated",
    "steam-isolated",
}
APP_CONTAINERS = {
    "chrome-dd",
    "chrome-az",
    "chrome-hika",
    "chrome-sciencesoft",
    "firefox",
    "zen",
    "idea",
    "spotify",
    "vscode",
    "obsidian",
    "openlens",
    "libreoffice",
    "telegram-1",
    "telegram-2",
    "steam",
    "overwatch",
    "terraria",
    "albion",
}


def is_app_container(name: str, project: str) -> bool:
    if project in APP_PROJECTS:
        return True
    if name in APP_CONTAINERS:
        return True
    return False


def container_inspect(names: list[str]) -> dict[str, dict]:
    if not names:
        return {}
    code, text, _ = run(["docker", "inspect", *names], timeout=10.0)
    if code != 0 or not text.strip():
        return {}
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, list):
        return {}
    out: dict[str, dict] = {}
    for obj in data:
        if not isinstance(obj, dict):
            continue
        name = str(obj.get("Name") or "").lstrip("/")
        if not name:
            continue
        mounts: list[str] = []
        for mount in obj.get("Mounts") or []:
            if not isinstance(mount, dict):
                continue
            src = str(mount.get("Source") or mount.get("Name") or "")
            dst = str(mount.get("Destination") or "")
            if src and dst:
                mounts.append(src + " → " + dst)
            elif dst:
                mounts.append(dst)
        nets: list[str] = []
        networks = ((obj.get("NetworkSettings") or {}).get("Networks")) or {}
        if isinstance(networks, dict):
            for net_name, info in networks.items():
                ip = ""
                if isinstance(info, dict):
                    ip = str(info.get("IPAddress") or "")
                line = str(net_name or "")
                if ip:
                    line = line + "  " + ip
                if line:
                    nets.append(line)
        out[name] = {"volumes": mounts, "networks": nets}
    return out


def list_docker(full: bool = True) -> tuple[list[dict], list[dict]]:
    code, text, _ = run(
        [
            "docker",
            "ps",
            "-a",
            "--format",
            "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.ID}}\t{{.State}}\t{{.Label \"com.docker.compose.project\"}}",
        ]
    )
    if code != 0:
        return [], []
    # Always inspect mounts/networks so hover tips can show Volumes / Networks.
    # stats stays the heavy part; inspect of the name list is cheap.
    stats = container_stats()
    rows: list[tuple[str, str, list[str]]] = []
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        rows.append((parts[0], parts[5].strip() if len(parts) > 5 else "", parts))
    details = container_inspect([name for name, _, _ in rows])
    lab: list[dict] = []
    apps: list[dict] = []
    for name, project, parts in rows:
        ident = parts[3][:12] if len(parts) > 3 else ""
        state = parse_container_state(parts[2], parts[4] if len(parts) > 4 else "")
        usage = stats.get(name, {})
        extra = details.get(name, {})
        item = {
            "name": name,
            "image": parts[1],
            "status": parts[2],
            "id": ident,
            "state": state,
            "cpu": usage.get("cpu", ""),
            "mem": usage.get("mem", ""),
            "memPerc": usage.get("memPerc", ""),
            "net": usage.get("net", ""),
            "volumes": extra.get("volumes") or [],
            "networks": extra.get("networks") or [],
        }
        if is_app_container(name, project):
            apps.append(item)
        else:
            lab.append(item)
    lab.sort(key=lambda row: str(row.get("name") or ""))
    apps.sort(key=lambda row: str(row.get("name") or ""))
    return lab, apps


def containers() -> list[dict]:
    return list_docker(True)[0]


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


def status(full: bool = True) -> dict:
    lab, apps = list_docker(full)
    return {
        "vms": vms(),
        "containers": lab,
        "apps": apps,
        "wireguard": public_tunnels(configs(WG_DIRS), "wireguard"),
        "amnezia": public_tunnels(configs(AWG_DIRS), "amnezia"),
        "vless": public_tunnels(vless_configs(), "vless"),
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
    if kind == "vless":
        return toggle_vless(name)
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


def drop_container_windows(name: str, action: str) -> None:
    if name in {"steam", "overwatch", "terraria", "albion", "ollama", "omniroute"}:
        return
    script = os.path.expanduser("~/.config/scripts/reap-container-windows")
    if os.path.isfile(script):
        run([script, name, action], timeout=2.0)
        return
    py = os.path.expanduser("~/.config/scripts/reap-container-windows.py")
    if os.path.isfile(py):
        run(["python3", py, name, action], timeout=2.0)


def docker_action(action: str, name: str) -> int:
    if not NAME_RE.match(name):
        print("invalid name", file=sys.stderr)
        return 2
    if action == "pause":
        # Pause freezes the last Wayland frame. GUI apps must stop instead.
        if name in APP_CONTAINERS and name not in {"steam", "overwatch"}:
            drop_container_windows(name, "stop")
            run(["docker", "update", "--restart", "no", name], timeout=10.0)
            cmd = ["docker", "stop", "-t", "0", name]
        else:
            cmd = ["docker", "pause", name]
    elif action == "unpause":
        cmd = ["docker", "unpause", name]
    elif action == "start":
        cmd = ["docker", "start", name]
    elif action == "stop":
        drop_container_windows(name, "stop")
        run(["docker", "update", "--restart", "no", name], timeout=10.0)
        cmd = ["docker", "stop", "-t", "0", name]
    elif action == "restart":
        cmd = ["docker", "restart", name]
    elif action == "rm":
        drop_container_windows(name, "kill")
        cmd = ["docker", "rm", "-f", name]
    else:
        print("invalid docker action", file=sys.stderr)
        return 2
    code, out, err = run(cmd, timeout=40.0)
    if action in {"stop", "pause", "rm"}:
        drop_container_windows(name, "stop")
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)
    return code


def main() -> int:
    argv = sys.argv[1:]
    if not argv or argv[0] in ("status", "list"):
        json.dump(status(full=True), sys.stdout, ensure_ascii=False, separators=(",", ":"))
        sys.stdout.write("\n")
        return 0
    if argv[0] == "status-light":
        json.dump(status(full=False), sys.stdout, ensure_ascii=False, separators=(",", ":"))
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
    if argv[0] == "vm" and len(argv) >= 3:
        return vm_action(argv[1], argv[2])
    print("usage: lab-ctl status|status-light | toggle wireguard|amnezia|vless NAME | docker start|stop|pause|unpause|restart|rm NAME | vm start|stop|destroy NAME", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
