#!/usr/bin/env bash
# C&C Generals Online — Wine virtual desktop 2560×1080 on DP-1.
# No compositor exclusive fullscreen (keeps workspace switch + aurora widgets).
set -euo pipefail

# Lutris / steam-run PATH often lacks host python3; resolve once.
if ! command -v python3 >/dev/null 2>&1; then
  for c in \
    /nix/store/b5bpi6zfajzzrwwpgba2q6li3nnya4bs-python3-3.14.7/bin/python3 \
    /run/current-system/sw/bin/python3 \
    /etc/profiles/per-user/dd/bin/python3 \
    "$HOME/.nix-profile/bin/python3"
  do
    if [[ -x "$c" ]]; then
      PATH="$(dirname "$c"):$PATH"
      export PATH
      break
    fi
  done
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "generals.sh: python3 not found in PATH" >&2
  exit 1
fi

HOME="${HOME:-/home/dd}"
PREFIX="${HOME}/Games/generals"
ZH="${PREFIX}/drive_c/Program Files (x86)/EA Games/Command and Conquer Generals/Command and Conquer Generals Zero Hour"
WINE="${HOME}/.local/share/lutris/runners/wine/proton-cachyos-x86_64/files/bin/wine"
WINESERVER="${WINE%/*}/wineserver"
RES_W="${GENERALS_WIDTH:-2560}"
RES_H="${GENERALS_HEIGHT:-1080}"
DOC="${PREFIX}/drive_c/users/steamuser/Documents/Command and Conquer Generals Zero Hour Data"

if [[ -f "${ZH}/GeneralsOnlineZH_60.exe" ]]; then
  EXE="${ZH}/GeneralsOnlineZH_60.exe"
elif [[ -f "${ZH}/GeneralsOnlineZH.exe" ]]; then
  EXE="${ZH}/GeneralsOnlineZH.exe"
else
  echo "GeneralsOnlineZH not found in: $ZH" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"
game_ensure_xwayland
game_pin_outputs 2>/dev/null || true

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEESYNC=0
export WINEFSYNC=0
export WINEDLLOVERRIDES="d3d8=n,b;d3d9=b"

mkdir -p "${HOME}/.cache/steam-shadercache" "${HOME}/.cache/dxvk" "${HOME}/.cache/nvidia"

close_wine_desktop() {
  # Drop leftover Hypr "Wine Desktop" if wineserver died uncleanly.
  hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys, subprocess
for c in json.load(sys.stdin):
    if c.get("class") == "steam_proton" and "Wine Desktop" in (c.get("title") or ""):
        addr = c.get("address") or ""
        if not addr:
            continue
        # Hypr lua dispatch (classic "closewindow address:" is rejected).
        expr = (
            "(function() local w = hl.get_window(\"address:%s\"); "
            "if w then hl.dispatch(hl.dsp.window.close({ window = w })) end; "
            "return true end)()"
        ) % addr
        subprocess.run(
            ["hyprctl", "eval", expr],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
' 2>/dev/null || true
}

cleanup_wine() {
  # Kill the whole prefix, then close any stuck blue Wine Desktop window.
  if [[ -x "$WINESERVER" ]]; then
    steam-run env WINEPREFIX="$WINEPREFIX" WINEARCH=win64 "$WINESERVER" -k >/dev/null 2>&1 || true
  fi
  sleep 0.3
  close_wine_desktop
  # If explorer still holds the blue desk, force it.
  pkill -f 'Games/generals/.*/explorer\.exe' >/dev/null 2>&1 || true
  sleep 0.2
  close_wine_desktop
}
trap cleanup_wine EXIT
trap 'cleanup_wine; exit 0' INT TERM HUP

game_live() {
  # Real game only. Linux truncates comm to 15 chars:
  # GeneralsOnlineZH_60.exe → "GeneralsOnlineZ" (not GeneralsOnlineZH*).
  # wine/bwrap/start/explorer keep the path in argv forever → ignore those.
  local pid st comm cmd0
  while read -r pid; do
    [[ -d "/proc/$pid" ]] || continue
    st=$(ps -p "$pid" -o state= 2>/dev/null) || continue
    [[ "$st" == *Z* ]] && continue
    comm=$(tr -d '\0\n' <"/proc/$pid/comm" 2>/dev/null) || continue
    case "$comm" in
      GeneralsOnline*|generals.exe|Generals.exe) return 0 ;;
    esac
    # Fallback: argv0 is the windows exe path (not a wine wrapper).
    cmd0=$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | head -1)
    case "$cmd0" in
      *explorer.exe*|*start.exe*|*/bin/wine|*/bin/wine64|*bwrap*|*steam-run*|*generals.sh*) continue ;;
    esac
    [[ "$cmd0" == *GeneralsOnlineZH* ]] && return 0
  done < <(pgrep -f 'GeneralsOnlineZH' 2>/dev/null || true)
  return 1
}

# Lutris wrapper often SIGKILL's the launcher on "stop"/child death — EXIT trap
# never runs and Wine Desktop stays blue. Detached reaper survives that.
(
  for _ in $(seq 1 180); do
    game_live && break
    sleep 0.5
  done
  game_live || exit 0
  while game_live; do sleep 1; done
  sleep 0.4
  cleanup_wine
) >/dev/null 2>&1 &
disown $! 2>/dev/null || true


# Hotkeys CSF (once).
CSF="${ZH}/Data/English/generals.csf"
if [[ ! -f "$CSF" ]] || [[ "$(wc -c <"$CSF")" -lt 100000 ]]; then
  mkdir -p "${ZH}/Data/English"
  python3 - "$CSF" <<'PY' || true
import io, sys, urllib.request, zipfile
from pathlib import Path
dest = Path(sys.argv[1])
url = "https://www.gentool.net/download/hotkeys/HotkeysEnglishZH_v1.5.zip"
try:
    data = urllib.request.urlopen(url, timeout=45).read()
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        for name in zf.namelist():
            if name.lower().endswith(".csf"):
                dest.write_bytes(zf.read(name))
                break
except Exception as e:
    print(f"hotkeys skip: {e}", file=sys.stderr)
PY
fi

# Camera zoom (best-effort).
python3 - "$DOC/GeneralsOnlineData/settings.json" <<'PY' || true
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
p.parent.mkdir(parents=True, exist_ok=True)
s = json.loads(p.read_text()) if p.exists() else {}
cam = s.setdefault("camera", {})
cam["max_height_only_when_lobby_host"] = float(cam.get("max_height_only_when_lobby_host") or 500)
cam.setdefault("min_height", 100.0)
cam.setdefault("move_speed_ratio", 1.0)
net = s.setdefault("network", {})
net["use_alternative_endpoint"] = True
p.write_text(json.dumps(s, indent=2) + "\n")
PY

OPTS="$(cat <<EOF
[Options]
AntiAliasing = 2
BuildingOcclusion = yes
DynamicLOD = no
ExtraAnimations = yes
FPSLimit = 60
FirewallBehavior = 9
FirewallPortAllocationDelta = 0
FirewallPortOverride = 0
HeatEffects = yes
IdealStaticGameLOD = High
Resolution = ${RES_W} ${RES_H}
ScrollFactor = 50
SendDelay = no
ShowTrees = yes
StaticGameLOD = High
TextureReduction = 0
UseCloudMap = yes
UseLightMap = yes
UseShadowMap = yes
UseShadowVolumes = yes
Windowed = no
EOF
)"
mkdir -p "$DOC"
printf '%s\n' "$OPTS" > "$DOC/Options.ini"

# GenTool: merge only, never wipe.
if [[ -f "${ZH}/d3d8.cfg" ]]; then
  python3 - "${ZH}/d3d8.cfg" <<'PY' || true
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(errors="replace") if p.exists() else "[gentool76]\n"
if "[gentool76]" not in t:
    t = "[gentool76]\n" + t
def upsert(text, key, val):
    if re.search(rf"(?m)^{key}=", text):
        return re.sub(rf"(?m)^{key}=.*$", f"{key}={val}", text, count=1)
    return text.rstrip() + f"\n{key}={val}\n"
t = upsert(t, "pitch", "37")
t = upsert(t, "cursorlock", "1")
p.write_text(t)
PY
fi

# Wine virtual desktop size + mild cursor warp.
python3 - "$RES_W" "$RES_H" <<'PY' || true
from pathlib import Path
import re, sys, time
w, h = sys.argv[1], sys.argv[2]
p = Path.home() / "Games/generals/user.reg"
t = p.read_text(errors="replace") if p.exists() else ""
ts = str(int(time.time()))
if not re.search(r'(?m)^\[Software\\\\Wine\\\\Explorer\]', t):
    t += f"\n[Software\\\\Wine\\\\Explorer] {ts}\n#time=1dd000000000000\n\"Desktop\"=\"Default\"\n"
else:
    if re.search(r'(?m)^"Desktop"=', t):
        t = re.sub(r'(?m)^"Desktop"=".*"', '"Desktop"="Default"', t)
    else:
        t = re.sub(
            r'(?m)^(\[Software\\\\Wine\\\\Explorer\][^\n]*\n(?:#time=[^\n]*\n)?)',
            r'\1"Desktop"="Default"\n', t, count=1)
desk = f'"Default"="{w}x{h}"'
if re.search(r'(?m)^\[Software\\\\Wine\\\\Explorer\\\\Desktops\]', t):
    if re.search(r'(?m)^"Default"="\d+x\d+"', t):
        t = re.sub(r'(?m)^"Default"="\d+x\d+"', desk, t, count=1)
    else:
        t = re.sub(
            r'(?m)^(\[Software\\\\Wine\\\\Explorer\\\\Desktops\][^\n]*\n(?:#time=[^\n]*\n)?)',
            r'\1' + desk + '\n', t, count=1)
else:
    t += f"\n[Software\\\\Wine\\\\Explorer\\\\Desktops] {ts}\n#time=1dd000000000000\n{desk}\n"
t = re.sub(r'(?m)^"MouseWarpOverride"=".*"', '"MouseWarpOverride"="enable"', t)
t = re.sub(r'(?m)^"GrabFullscreen"=".*"', '"GrabFullscreen"="N"', t)
if not re.search(r'(?m)^"MouseWarpOverride"=', t):
    t += f"\n[Software\\\\Wine\\\\X11 Driver] {ts}\n\"MouseWarpOverride\"=\"enable\"\n\"GrabFullscreen\"=\"N\"\n"
# Host browser for GO login ShellExecute
wb = '"Browsers"="/home/dd/.config/scripts/go-open-url.sh %s"'
if re.search(r'(?m)^\[Software\\\\Wine\\\\WineBrowser\]', t):
    if re.search(r'(?m)^"Browsers"=', t):
        t = re.sub(r'(?m)^"Browsers"=.*$', wb, t)
    else:
        t = re.sub(
            r'(?m)^(\[Software\\\\Wine\\\\WineBrowser\][^\n]*\n(?:#time=[^\n]*\n)?)',
            r'\1' + wb + '\n', t, count=1)
else:
    t += f"\n[Software\\\\Wine\\\\WineBrowser] {ts}\n#time=1dd000000000000\n{wb}\n"
p.write_text(t)
print(f"wine desktop {w}x{h}")
PY

mkdir -p "${HOME}/.config/scripts"
cat > "${HOME}/.config/scripts/go-open-url.sh" <<'EOF'
#!/usr/bin/env bash
exec >>/tmp/go-winebrowser.log 2>&1
echo "$(date -Is) argv: $*"
url=""
for a in "$@"; do
  case "$a" in http://*|https://*) url="$a" ;; esac
done
[[ -z "$url" && $# -ge 1 ]] && url="${@: -1}"
[[ -z "$url" ]] && exit 0
if [[ "$url" == *playgenerals.online/login* ]]; then
  code=$(printf '%s' "$url" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')
  [[ -n "$code" ]] && command -v wl-copy >/dev/null && printf '%s' "$code" | wl-copy
  command -v notify-send >/dev/null && notify-send -u critical "Generals Online" \
    "Login page Error 102. Code in clipboard: ${code:-?}. Open Discord Command Center."
  url="https://discord.playgenerals.online/"
fi
if [[ -x /home/dd/.config/scripts/google-chrome ]]; then
  /home/dd/.config/scripts/google-chrome "$url" &
else
  xdg-open "$url" &
fi
EOF
chmod +x "${HOME}/.config/scripts/go-open-url.sh"

# No exclusive FS — workspace switch + widgets stay usable.
hyprctl eval 'hl.window_rule({ name = "generals-wine-desktop-runtime", match = { class = "^steam_proton$", title = ".*Wine Desktop.*" }, fullscreen_state = "0 0", sync_fullscreen = false, confine_pointer = true, suppress_event = "x11configurerequest", decorate = false, border_size = 0 })' >/dev/null 2>&1 || true

cd "$ZH"

# Login-code helper (Discord fallback if site /login/ is broken).
(
  opened=""
  for _ in $(seq 1 120); do
    [[ -f "${DOC}/GeneralsOnlineData/GeneralsOnline.log" ]] || { sleep 1; continue; }
    code=$(rg -o '"login_code"\s*:\s*"[A-Za-z0-9]+"' "${DOC}/GeneralsOnlineData/GeneralsOnline.log" 2>/dev/null | tail -1 | sed 's/.*"\([^"]*\)"$/\1/') || true
    if [[ -n "${code:-}" && "$code" != "$opened" ]]; then
      opened="$code"
      command -v wl-copy >/dev/null && printf '%s' "$code" | wl-copy || true
      command -v notify-send >/dev/null && notify-send "Generals Online" "Login code copied: $code" || true
    fi
    sleep 2
  done
) &
BROWSER_PID=$!

steam-run env \
  WINEPREFIX="$WINEPREFIX" WINEARCH=win64 \
  WINEESYNC=0 WINEFSYNC=0 \
  WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
  "$WINE" explorer /desktop=Default,${RES_W}x${RES_H} "$EXE" "$@" &
WINEPID=$!

# Place on DP-1, clear any inherited fullscreen. Do not spam FS.
(
  for _ in $(seq 1 40); do
    addr=$(hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
for c in json.load(sys.stdin):
    if c.get("class") == "steam_proton" and "Wine Desktop" in (c.get("title") or ""):
        print(c.get("address", "")); break
' 2>/dev/null || true)
    if [[ -n "${addr:-}" ]]; then
      hyprctl eval "hl.dispatch(hl.dsp.window.move({ output = \"${GENERALS_OUTPUT:-DP-4}\", window = \"$addr\" }))" >/dev/null 2>&1 || true
      hyprctl eval "hl.dispatch(hl.dsp.window.fullscreen_state({ window = \"$addr\", internal = 0, client = 0 }))" >/dev/null 2>&1 || true
      break
    fi
    sleep 0.4
  done
) &

# Wait for the real game exe (not wine parent — steam-run/wine can exit early).
for _ in $(seq 1 120); do
  game_live && break
  sleep 0.5
done

if ! game_live; then
  echo "GeneralsOnlineZH did not start" >&2
  exit 1
fi

# Stay up until the game process exits. Ignore wine-parent death.
while game_live; do
  sleep 1
done

kill "$BROWSER_PID" >/dev/null 2>&1 || true
cleanup_wine
# EXIT trap also runs cleanup_wine

