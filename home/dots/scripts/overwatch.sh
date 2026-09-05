#!/usr/bin/env bash
# Steam launch options:
#   /home/dd/.config/scripts/overwatch.sh %command%
set -euo pipefail

HOME="${HOME:-/home/dd}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

pkill -f 'fossilize_replay.*/shadercache/2357570/' >/dev/null 2>&1 || true

export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"
export PROTON_HIDE_NVIDIA_GPU="${PROTON_HIDE_NVIDIA_GPU:-0}"
export PROTON_ENABLE_NGX_UPDATER=0
export __GL_SYNC_TO_VBLANK=0
export __GL_SHARPEN_ENABLE=0
export DXVK_HDR=0
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH="${DXVK_STATE_CACHE_PATH:-$XDG_CACHE_HOME/dxvk}"

mkdir -p "$DXVK_STATE_CACHE_PATH" "$XDG_CONFIG_HOME/dxvk"

export DXVK_CONFIG_FILE="$XDG_CONFIG_HOME/dxvk/overwatch.conf"
export PROTON_DXVK_CONFIG_FILE="$DXVK_CONFIG_FILE"

python3 - <<'PY'
import json
import os
import re
import subprocess
from pathlib import Path

ini_path = Path("/steam/steamapps/compatdata/2357570/pfx/drive_c/users/steamuser/Documents/Overwatch/Settings/Settings_v0.ini")
dxvk_path = Path(os.environ["DXVK_CONFIG_FILE"])
monitors_lua = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))) / "hypr/config/monitors.lua"


def compositor_env():
    env = {
        "HOME": os.environ.get("HOME", "/home/dd"),
        "PATH": "/run/current-system/sw/bin:/usr/bin:/bin",
        "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000"),
        "HYPRLAND_INSTANCE_SIGNATURE": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""),
        "DISPLAY": os.environ.get("DISPLAY", ":0"),
        "XAUTHORITY": os.environ.get("XAUTHORITY", ""),
        "WAYLAND_DISPLAY": os.environ.get("WAYLAND_DISPLAY", ""),
    }
    runtime = Path(env["XDG_RUNTIME_DIR"]) / "hypr"
    if not env["HYPRLAND_INSTANCE_SIGNATURE"] and runtime.is_dir():
        for d in runtime.iterdir():
            if (d / ".socket.sock").exists() or (d / ".socket.ipc.sock").exists():
                env["HYPRLAND_INSTANCE_SIGNATURE"] = d.name
                break
    return {k: v for k, v in env.items() if v}


def hypr_monitors():
    hyprctl = "/run/current-system/sw/bin/hyprctl"
    if not os.access(hyprctl, os.X_OK):
        return []
    try:
        out = subprocess.check_output([hyprctl, "-j", "monitors"], env=compositor_env(), text=True)
        return json.loads(out)
    except Exception:
        return []


def fallback_monitor():
    text = monitors_lua.read_text() if monitors_lua.exists() else ""
    match = re.search(r'mode = "(\d+)x(\d+)@([0-9.]+)Hz"', text)
    if match:
        return {
            "width": int(match.group(1)),
            "height": int(match.group(2)),
            "refreshRate": float(match.group(3)),
            "name": "DP-1",
        }
    return {"width": 2560, "height": 1080, "refreshRate": 200.0, "name": "DP-1"}


def pick_monitor(mons):
    active = [m for m in mons if not m.get("disabled")]
    if not active:
        return fallback_monitor()
    return max(
        active,
        key=lambda m: (int(m.get("width") or 0) * int(m.get("height") or 0), float(m.get("refreshRate") or 0)),
    )


def upsert_keys(src, keys):
    lines = src.splitlines()
    seen = set()
    out = []
    in_render = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_render = stripped == "[Render.13]"
        if in_render and "=" in line:
            key = line.split("=", 1)[0].strip()
            if key in keys:
                pad = line[: len(line) - len(line.lstrip())]
                out.append(f"{pad}{key} = {keys[key]}")
                seen.add(key)
                continue
        out.append(line)
    missing = [k for k in keys if k not in seen]
    if missing:
        insert_at = None
        for i, line in enumerate(out):
            if line.strip() == "[Render.13]":
                insert_at = i + 1
                break
        if insert_at is None:
            out.extend(["", "[Render.13]"])
            insert_at = len(out)
        for key in missing:
            out.insert(insert_at, f"{key} = {keys[key]}")
            insert_at += 1
    return "\n".join(out) + "\n"


def set_x_primary(width, height):
    candidates = [
        "xrandr",
        "/run/current-system/sw/bin/xrandr",
        "/nix/store/6j7x7hg0d5mrrphqfl6mlxvsmlfg22ag-xrandr-1.5.4/bin/xrandr",
    ]
    xrandr = next((p for p in candidates if p == "xrandr" or os.access(p, os.X_OK)), None)
    if xrandr == "xrandr":
        from shutil import which
        xrandr = which("xrandr")
    if not xrandr:
        return
    try:
        query = subprocess.check_output([xrandr, "--query"], env=compositor_env(), text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return
    target = None
    for line in query.splitlines():
        if " connected" not in line or "disconnected" in line:
            continue
        name = line.split()[0]
        if f"{width}x{height}" in line:
            target = name
            break
    if not target:
        return
    try:
        subprocess.check_call([xrandr, "--output", target, "--primary"], env=compositor_env(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


mon = pick_monitor(hypr_monitors())
width = int(mon["width"])
height = int(mon["height"])
refresh = int(round(float(mon.get("refreshRate") or 60)))
use_219 = "1" if (width / max(height, 1)) >= 2.0 else "0"

dxvk_path.write_text(
    "\n".join(
        [
            "dxgi.syncInterval = 0",
            "dxgi.maxFrameLatency = 1",
            "dxgi.maxFrameRate = 0",
            "d3d11.maxFrameRate = 0",
            f"dxgi.forceRefreshRate = {refresh}",
            "dxvk.enableGraphicsPipelineLibrary = True",
            "dxvk.numCompilerThreads = 6",
            "",
        ]
    )
)
try:
    Path("/steam/steamapps/common/Overwatch/dxvk.conf").write_text(dxvk_path.read_text())
except OSError:
    pass

ini_path.parent.mkdir(parents=True, exist_ok=True)
text = ini_path.read_text() if ini_path.exists() else "[Render.13]\n"
ini_path.write_text(
    upsert_keys(
        text,
        {
            "FullScreenWidth": f'"{width}"',
            "FullScreenHeight": f'"{height}"',
            "FullScreenRefresh": f'"{refresh}"',
            "WindowedRefresh": f'"{refresh}"',
            "Use219AspectRatio": f'"{use_219}"',
            "LimitToRefresh": '"0"',
            "UseVSync": '"0"',
            "FrameRateCap": '"0"',
        },
    )
)
set_x_primary(width, height)
PY

if [ -n "${LD_PRELOAD:-}" ]; then
  filtered=""
  old_ifs=$IFS
  IFS=:
  for p in $LD_PRELOAD; do
    case "$p" in
      *gameoverlayrenderer*) ;;
      "") ;;
      *)
        if [ -z "$filtered" ]; then
          filtered=$p
        else
          filtered="$filtered:$p"
        fi
        ;;
    esac
  done
  IFS=$old_ifs
  export LD_PRELOAD="$filtered"
fi

if command -v gamemoderun >/dev/null 2>&1; then
  exec gamemoderun "$@"
fi
exec "$@"
