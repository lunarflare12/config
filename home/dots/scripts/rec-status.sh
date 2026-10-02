#!/usr/bin/env bash
# Screen-recorder status for the center island.
#   rec-status.sh            prints "<tool> <paused 0|1> <elapsed seconds>"
#   rec-status.sh announce X notifies once when the active tool changes
#   rec-status.sh pause      pauses or resumes the active recorder
#   rec-status.sh stop       stops the active recorder
set -euo pipefail

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
stamp="$runtime/aurora-rec-tool"
held="$runtime/aurora-rec-held"

obs_py() {
  python3 - "$@" <<'PY'
import base64, hashlib, json, os, re, socket, struct, sys
from datetime import datetime, timedelta

action = sys.argv[1] if len(sys.argv) > 1 else "status"

def log_latest():
    directory = os.path.expanduser("~/.config/obs-studio/logs")
    if not os.path.isdir(directory):
        return ""
    newest = ""
    for name in os.listdir(directory):
        path = os.path.join(directory, name)
        if os.path.isfile(path) and (not newest or os.path.getmtime(path) > os.path.getmtime(newest)):
            newest = path
    return newest

def log_state():
    path = log_latest()
    if not path:
        return None
    base = os.path.basename(path)[:10]
    try:
        day = datetime.strptime(base, "%Y-%m-%d")
    except ValueError:
        return None
    pattern = re.compile(r"^(\d\d:\d\d:\d\d)\.\d+: ==== Recording (Start|Stop|Pause|Paused|Unpause|Unpaused|Resumed)\b")
    events = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            match = pattern.match(line)
            if not match:
                continue
            hour, minute, second = (int(part) for part in match.group(1).split(":"))
            moment = day.replace(hour=hour, minute=minute, second=second)
            if events and moment < events[-1][0]:
                moment += timedelta(days=1)
                day = moment.replace(hour=0, minute=0, second=0)
            events.append((moment, match.group(2)))
    active = False
    paused = False
    elapsed = 0.0
    cursor = None
    for moment, kind in events:
        if active and not paused and cursor is not None:
            elapsed += (moment - cursor).total_seconds()
        cursor = moment
        if kind == "Start":
            active = True
            paused = False
            elapsed = 0.0
        elif kind == "Stop":
            active = False
            paused = False
        elif kind in ("Pause", "Paused"):
            paused = True
        else:
            paused = False
    if not active:
        return None
    if not paused and cursor is not None:
        elapsed += (datetime.now() - cursor).total_seconds()
    return paused, max(0, int(elapsed))

def ws_call(request_type):
    path = os.path.expanduser("~/.config/obs-studio/plugin_config/obs-websocket/config.json")
    with open(path, encoding="utf-8") as fh:
        cfg = json.load(fh)
    port = int(cfg.get("server_port") or 4455)
    password = str(cfg.get("server_password") or "")
    need_auth = bool(cfg.get("auth_required", True))

    def recvn(sock, n):
        buf = b""
        while len(buf) < n:
            chunk = sock.recv(n - len(buf))
            if not chunk:
                raise OSError("closed")
            buf += chunk
        return buf

    def send_text(sock, text):
        payload = text.encode()
        n = len(payload)
        mask = os.urandom(4)
        if n < 126:
            header = bytes([0x81, 0x80 | n])
        elif n < 65536:
            header = bytes([0x81, 0xFE]) + struct.pack(">H", n)
        else:
            header = bytes([0x81, 0xFF]) + struct.pack(">Q", n)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        sock.sendall(header + mask + masked)

    def recv_text(sock):
        header = recvn(sock, 2)
        opcode = header[0] & 0x0F
        length = header[1] & 127
        if length == 126:
            length = struct.unpack(">H", recvn(sock, 2))[0]
        elif length == 127:
            length = struct.unpack(">Q", recvn(sock, 8))[0]
        if header[1] & 0x80:
            mask = recvn(sock, 4)
            data = bytes(b ^ mask[i % 4] for i, b in enumerate(recvn(sock, length)))
        else:
            data = recvn(sock, length)
        return opcode, data.decode(errors="replace")

    sock = socket.create_connection(("127.0.0.1", port), 0.4)
    sock.settimeout(0.4)
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall(
        (
            f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        ).encode()
    )
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise OSError("closed")
        buf += chunk
    opcode, payload = recv_text(sock)
    if opcode != 1:
        raise OSError("handshake")
    hello = json.loads(payload)
    identify = {"rpcVersion": 1}
    auth = (hello.get("d") or {}).get("authentication") or {}
    if need_auth and auth.get("challenge") and auth.get("salt"):
        secret = base64.b64encode(hashlib.sha256((password + auth["salt"]).encode()).digest()).decode()
        token = base64.b64encode(hashlib.sha256((secret + auth["challenge"]).encode()).digest()).decode()
        identify["authentication"] = token
    send_text(sock, json.dumps({"op": 1, "d": identify}))
    while True:
        opcode, payload = recv_text(sock)
        if opcode == 8:
            raise OSError("closed")
        if opcode != 1:
            continue
        message = json.loads(payload)
        op = message.get("op")
        if op == 9:
            send_text(sock, json.dumps({"op": 10, "d": message.get("d") or {}}))
            continue
        if op == 2:
            send_text(sock, json.dumps({"op": 6, "d": {"requestType": request_type, "requestId": "r"}}))
            continue
        if op == 7:
            body = message.get("d") or {}
            status = body.get("requestStatus") or {}
            if not status.get("result"):
                raise OSError("request")
            return body.get("responseData") or {}

def print_obs():
    try:
        data = ws_call("GetRecordStatus")
        if data.get("outputActive"):
            paused = 1 if data.get("outputPaused") else 0
            elapsed = max(0, int(int(data.get("outputDuration") or 0) / 1000))
            print(f"obs {paused} {elapsed}")
            return 0
    except Exception:
        pass
    state = log_state()
    if state is None:
        return 1
    paused, elapsed = state
    print(f"obs {1 if paused else 0} {elapsed}")
    return 0

def hotkey(keys):
    # Fallback when websocket is down. OBS has NeverDisableHotkeys.
    import shutil, subprocess
    if not shutil.which("wtype"):
        raise OSError("no wtype")
    env = os.environ.copy()
    if not env.get("WAYLAND_DISPLAY"):
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        for name in ("wayland-1", "wayland-0"):
            if os.path.exists(os.path.join(runtime, name)):
                env["WAYLAND_DISPLAY"] = name
                break
    subprocess.run(["wtype", "-k", keys], check=False, env=env, timeout=2)

def pause_obs():
    try:
        data = ws_call("GetRecordStatus")
        if data.get("outputActive"):
            paused = bool(data.get("outputPaused"))
            ws_call("ResumeRecord" if paused else "PauseRecord")
            return 0
    except Exception:
        pass
    logged = log_state()
    paused = bool(logged[0]) if logged else False
    try:
        ws_call("ResumeRecord" if paused else "PauseRecord")
        return 0
    except Exception:
        hotkey("F8")
        return 0

def stop_obs():
    try:
        ws_call("StopRecord")
        return 0
    except Exception:
        hotkey("F9")
        return 0

if action == "status":
    sys.exit(print_obs())
if action == "pause":
    sys.exit(pause_obs())
if action == "stop":
    sys.exit(stop_obs())
sys.exit(1)
PY
}

announce() {
  local next="${1-}" prev=""
  [ -f "$stamp" ] && prev="$(cat "$stamp" 2>/dev/null || true)"
  [ "$next" = "$prev" ] && return 0
  printf '%s' "$next" >"$stamp"
  command -v notify-send >/dev/null 2>&1 || return 0
  if [ -z "$next" ]; then
    [ -z "$prev" ] && return 0
    notify-send -a Aurora -u normal "Запись" "Запись остановлена" >/dev/null 2>&1 || true
    return 0
  fi
  if [ "$next" = "obs" ]; then
    notify-send -a Aurora -u normal "Запись" "OBS записывает" >/dev/null 2>&1 || true
  else
    notify-send -a Aurora -u normal "Запись" "Идёт запись" >/dev/null 2>&1 || true
  fi
}

print_status() {
  local name pid state etimes
  for name in wf-recorder gpu-screen-recorder wl-screenrec; do
    pid="$(pidof "$name" 2>/dev/null | awk '{print $1}' || true)"
    [ -n "$pid" ] || continue
    state="$(ps -o state= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
    if [ "$state" = "T" ] && [ -f "$held" ]; then
      printf '%s 1 %s\n' "$name" "$(tr -d '[:space:]' <"$held")"
      return 0
    fi
    etimes="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
    printf '%s 0 %s\n' "$name" "${etimes:-0}"
    return 0
  done
  obs_py status
}

pause_tool() {
  local line tool pid state elapsed
  line="$(print_status || true)"
  tool="${line%% *}"
  case "$tool" in
    obs)
      obs_py pause
      ;;
    wf-recorder|gpu-screen-recorder|wl-screenrec)
      pid="$(pidof "$tool" 2>/dev/null | awk '{print $1}' || true)"
      [ -n "$pid" ] || return 1
      state="$(ps -o state= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
      if [ "$state" = "T" ]; then
        kill -CONT "$pid" || true
        rm -f "$held"
      else
        elapsed="${line##* }"
        printf '%s' "$elapsed" >"$held"
        kill -STOP "$pid" || true
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

stop_tool() {
  local line tool
  line="$(print_status || true)"
  tool="${line%% *}"
  case "$tool" in
    obs)
      obs_py stop
      ;;
    wf-recorder|gpu-screen-recorder|wl-screenrec)
      pkill -x "$tool" || true
      rm -f "$held"
      ;;
    *)
      return 1
      ;;
  esac
}

enable_ws() {
  python3 - <<'PY'
import json, os
path = os.path.expanduser("~/.config/obs-studio/plugin_config/obs-websocket/config.json")
try:
    with open(path, encoding="utf-8") as fh:
        cfg = json.load(fh)
except OSError:
    raise SystemExit(0)
if cfg.get("server_enabled") is True:
    raise SystemExit(0)
cfg["server_enabled"] = True
with open(path, "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
}

case "${1-}" in
  announce) announce "${2-}" ;;
  pause) pause_tool ;;
  stop) stop_tool ;;
  enable-ws) enable_ws ;;
  *) print_status ;;
esac
