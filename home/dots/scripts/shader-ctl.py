#!/usr/bin/env python3
"""Steam shader status + fossilize replay without launching the game."""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOME = Path(os.environ.get("HOME", "/home/dd"))
CACHE = HOME / ".cache" / "aurora"
STATUS_PATH = CACHE / "shader-status.json"
LOCK_PATH = CACHE / "shader-build.lock"
TARGET_PATH = CACHE / "shader-build.target"
PICS_PATH = CACHE / "shader-pics.json"
FOSSILIZE = HOME / ".local" / "share" / "Steam" / "ubuntu12_64" / "fossilize_replay"
STEAM_RUN = Path("/run/current-system/sw/bin/steam-run")
NVIDIA_ICD = Path("/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json")
NVSETTINGS = Path("/run/current-system/sw/bin/nvidia-settings")

STEAM_ROOTS = [
    HOME / ".local" / "share" / "Steam",
    Path("/steam"),
]

SHADER_ROOTS = [
    Path("/steam/steamapps/shadercache"),
    HOME / ".cache" / "steam-shadercache",
    HOME / ".local" / "share" / "Steam" / "steamapps" / "shadercache",
]

SKIP_NAME = re.compile(
    r"(proton|steam linux runtime|steamworks|redistributable|"
    r"dedicated server|\bsdk\b|soundtrack|compatibility tool|"
    r"steamworks common|proton experimental)",
    re.I,
)

# SteamKit EAppState. Bit 2 is "update required". Shader depots often
# leave BytesToDownload != BytesDownloaded while StateFlags stays 4 —
# Steam's UI still shows that as an update. Treat the byte gap as live.
STATE_UPDATE_REQUIRED = 2
STATE_UPDATE_RUNNING = 256
STATE_UPDATE_PAUSED = 512
STATE_UPDATE_STARTED = 1024
STATE_DOWNLOADING = 1 << 20
STATE_STAGING = 1 << 21
STATE_COMMITTING = 1 << 22
STATE_BUSY = (
    STATE_UPDATE_RUNNING
    | STATE_UPDATE_PAUSED
    | STATE_UPDATE_STARTED
    | STATE_DOWNLOADING
    | STATE_STAGING
    | STATE_COMMITTING
)

STEAM_REPLAY_RE = re.compile(
    r"Still replaying (\d+) \((\d+)%,\s*(\d+)/(\d+)\)"
)
SHADER_LOGS = [
    HOME / ".local" / "share" / "Steam" / "logs" / "shader_log.txt",
    HOME / ".steam" / "steam" / "logs" / "shader_log.txt",
]


def proc_comm(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/comm").read_text().strip()
    except OSError:
        return ""


def proc_ppid(pid: int) -> int:
    try:
        for line in Path(f"/proc/{pid}/status").read_text().splitlines():
            if line.startswith("PPid:"):
                return int(line.split()[1])
    except (OSError, ValueError, IndexError):
        return 0
    return 0


def proc_cmdline(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace")
    except OSError:
        return ""


def fossilize_appids() -> set[str]:
    ids: set[str] = set()
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        if not proc_comm(int(proc.name)).startswith("fossilize"):
            continue
        cmd = proc_cmdline(int(proc.name))
        m = re.search(r"shadercache/(\d+)", cmd)
        if m:
            ids.add(m.group(1))
    return ids


def steam_owned_fossilize(pid: int) -> bool:
    cur = pid
    for _ in range(16):
        cur = proc_ppid(cur)
        if cur <= 1:
            return False
        if proc_comm(cur) == "steam":
            return True
    return False


def steam_shader_progress() -> dict[str, dict]:
    found: dict[str, dict] = {}
    for path in SHADER_LOGS:
        if not path.is_file():
            continue
        try:
            tail = path.read_bytes()[-65536:].decode(errors="replace")
        except OSError:
            continue
        for m in STEAM_REPLAY_RE.finditer(tail):
            found[m.group(1)] = {
                "percent": float(m.group(2)),
                "done": int(m.group(3)),
                "total": int(m.group(4)),
            }
    return found


def notify(title: str, body: str) -> None:
    try:
        subprocess.run(["notify-send", "-a", "Shaders", title, body], check=False)
    except OSError:
        pass


def acf_values(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, val in re.findall(r'"([^"]+)"\s+"([^"]*)"', text):
        out.setdefault(key, val)
    return out


def library_steamapps() -> list[Path]:
    found: list[Path] = []
    seen: set[str] = set()

    def add(steamapps: Path) -> None:
        try:
            key = str(steamapps.resolve())
        except OSError:
            key = str(steamapps)
        if key in seen or not steamapps.is_dir():
            return
        seen.add(key)
        found.append(steamapps)

    for root in STEAM_ROOTS:
        add(root / "steamapps")
        folders = root / "steamapps" / "libraryfolders.vdf"
        if not folders.is_file():
            continue
        text = folders.read_text(errors="replace")
        for path in re.findall(r'"path"\s+"([^"]+)"', text):
            add(Path(path) / "steamapps")
    return found


def iter_manifests() -> list[Path]:
    out: list[Path] = []
    seen: set[str] = set()
    for steamapps in library_steamapps():
        for man in steamapps.glob("appmanifest_*.acf"):
            appid = man.stem.removeprefix("appmanifest_")
            if appid in seen:
                continue
            seen.add(appid)
            out.append(man)
    return out


def find_manifest(appid: str) -> Path | None:
    for steamapps in library_steamapps():
        p = steamapps / f"appmanifest_{appid}.acf"
        if p.is_file():
            return p
    return None


def is_tool(name: str, installdir: str) -> bool:
    blob = f"{name} {installdir}"
    return bool(SKIP_NAME.search(blob))


def game_kind(appid: str, steamapps: Path, installdir: str) -> str:
    if (steamapps / "compatdata" / appid).is_dir():
        return "proton"
    common = steamapps / "common" / installdir
    for rel in (
        "game/bin/linuxsteamrt64",
        "bin/linuxsteamrt64",
        "bin/linux64",
        "bin/linux32",
    ):
        if (common / rel).exists():
            return "native"
    return "native"


def running_appids(ps_text: str) -> set[str]:
    ids: set[str] = set()
    for line in ps_text.splitlines():
        # Steam keeps steam://rungameid/N in its own argv after the game exits.
        if "steam://rungameid/" in line and "AppId=" not in line and "compatdata/" not in line:
            continue
        for m in re.finditer(r"(?:SteamLaunch\s+)?AppId[=:](\d+)|compatdata/(\d+)", line):
            ids.add(next(g for g in m.groups() if g))
    return ids


def ps_args() -> str:
    try:
        return subprocess.check_output(["ps", "-eo", "args"], text=True, errors="replace")
    except OSError:
        return ""


def shader_dir(appid: str) -> Path | None:
    for root in SHADER_ROOTS:
        p = root / appid
        if p.is_dir():
            return p
    return None


def dir_size(path: Path) -> int:
    total = 0
    if not path.exists():
        return 0
    for dirpath, _, filenames in os.walk(path):
        for name in filenames:
            try:
                total += (Path(dirpath) / name).stat().st_size
            except OSError:
                pass
    return total


def newest_mtime(path: Path) -> int:
    newest = 0
    if not path.exists():
        return 0
    for dirpath, _, filenames in os.walk(path):
        for name in filenames:
            try:
                newest = max(newest, int((Path(dirpath) / name).stat().st_mtime))
            except OSError:
                pass
    return newest


def fmt_bytes(n: int) -> str:
    if n >= 1073741824:
        return f" {n / 1073741824:.1f} ГиБ".strip()
    if n >= 1048576:
        return f" {n / 1048576:.1f} МиБ".strip()
    if n >= 1024:
        return f" {n / 1024:.0f} КиБ".strip()
    return f"{n} Б"


def replay_files(foz: Path | None) -> list[Path]:
    if not foz:
        return []
    return list(foz.parent.glob("replay_cache*.foz"))


def replay_stats(foz: Path | None) -> tuple[int, int]:
    """Total size and newest mtime of every fossilize replay shard."""
    files = replay_files(foz)
    total = 0
    newest = 0
    for p in files:
        try:
            st = p.stat()
        except OSError:
            continue
        total += st.st_size
        newest = max(newest, int(st.st_mtime))
    return total, newest


def replay_complete(foz: Path | None, replay: Path | None) -> bool:
    """Steam writes a tiny replay_cache even after killing fossilize at 8%."""
    if not foz:
        return False
    try:
        foz_sz = foz.stat().st_size
        foz_mtime = int(foz.stat().st_mtime)
    except OSError:
        return False
    rep_sz, rep_mtime = replay_stats(foz)
    if replay and not rep_sz:
        try:
            st = replay.stat()
            rep_sz = st.st_size
            rep_mtime = int(st.st_mtime)
        except OSError:
            return False
    if foz_sz >= 256 * 1024 * 1024:
        return rep_sz >= max(32 * 1024 * 1024, foz_sz // 50)
    if foz_sz >= 16 * 1024 * 1024:
        return rep_mtime + 60 >= foz_mtime and rep_sz >= max(256 * 1024, foz_sz // 20)
    return True


def merged_nvidia_bytes(nvidia: Path | None) -> int:
    if not nvidia or not nvidia.is_dir():
        return 0
    total = 0
    for p in nvidia.rglob("steamapp_merged_shader_cache.bin"):
        try:
            total += p.stat().st_size
        except OSError:
            pass
    return total


def foz_candidates(shader: Path) -> list[Path]:
    foz_root = shader / "fozpipelinesv6"
    if not foz_root.is_dir():
        return []
    found = [p for p in foz_root.rglob("steam_pipeline_cache.foz") if p.is_file()]
    found.sort(key=lambda p: (p.stat().st_mtime, p.stat().st_size), reverse=True)
    # Steam leaves a ~76KiB stub and old steamapprun dirs next to the live pack.
    # Replaying every historical FOZ wastes hours on dead buckets.
    big = [p for p in found if p.stat().st_size >= 16 * 1024 * 1024]
    if big:
        return [big[0]]
    return found[:1]


def foz_bundle(shader: Path) -> tuple[Path | None, Path | None, Path | None]:
    found = foz_candidates(shader)
    foz = found[0] if found else None
    whitelist = None
    replay = None
    if foz:
        whitelist = foz.parent / "steam_pipeline_cache_whitelist.foz"
        if not whitelist.is_file():
            whitelist = None
        replays = list(foz.parent.glob("replay_cache*.foz"))
        replay = max(replays, key=lambda p: p.stat().st_mtime) if replays else None
    return foz, replay, whitelist


def _progress_snapshot() -> tuple[int, int, int]:
    """compiled, foz_done, foz_total. Compile total grows while the FOZ is scanned."""
    log = CACHE / "shader-build.log"
    if not log.is_file():
        return 0, 0, 0
    try:
        tail = log.read_bytes()[-16384:].decode(errors="replace")
    except OSError:
        return 0, 0, 0
    compiled = 0
    gfx = re.findall(r"Compile graphics\s+(\d+)\s*/\s+(\d+)", tail)
    if gfx:
        compiled = int(gfx[-1][0])
    else:
        compute = re.findall(r"Compile compute\s+(\d+)\s*/\s+(\d+)", tail)
        if compute:
            compiled = int(compute[-1][0])
    ov = re.findall(r"Overall\s+(\d+)\s*/\s+(\d+)", tail)
    if not ov:
        return compiled, 0, 0
    done, total = ov[-1]
    return compiled, int(done), int(total)


def last_progress() -> str:
    compiled, done, total = _progress_snapshot()
    if compiled and total:
        return f"{compiled} пайпл. · обход {100 * done / total:.0f}%"
    if compiled:
        return f"{compiled} пайпл."
    if total:
        return f"обход {100 * done / total:.0f}% ({done}/{total})"
    return ""


def progress_percent() -> float:
    _, done, total = _progress_snapshot()
    if total <= 0:
        return 0.0
    return min(99.0, 100.0 * done / total)


def write_target(appid: str, name: str) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    TARGET_PATH.write_text(f"{appid}\n{name}\n")


def read_target() -> tuple[str, str]:
    try:
        lines = TARGET_PATH.read_text().splitlines()
    except OSError:
        return "", ""
    return (lines[0].strip() if lines else "", lines[1].strip() if len(lines) > 1 else "")


def lock_pid() -> int | None:
    try:
        pid = int(LOCK_PATH.read_text().strip())
    except (OSError, ValueError):
        return None
    try:
        os.kill(pid, 0)
    except OSError:
        return None
    return pid


def write_status(payload: dict) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = STATUS_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
    tmp.replace(STATUS_PATH)


def load_pics() -> dict:
    try:
        data = json.loads(PICS_PATH.read_text())
    except (OSError, ValueError):
        return {"ts": 0, "apps": {}}
    if not isinstance(data, dict):
        return {"ts": 0, "apps": {}}
    data.setdefault("apps", {})
    return data


def save_pics(data: dict) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = PICS_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    tmp.replace(PICS_PATH)


def fetch_public_build(appid: str) -> dict | None:
    req = urllib.request.Request(
        f"https://api.steamcmd.net/v1/info/{appid}",
        headers={"User-Agent": "aurora-shader-ctl"},
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
    except (urllib.error.URLError, TimeoutError, ValueError, OSError):
        return None
    app = (data.get("data") or {}).get(appid) or {}
    public = ((app.get("depots") or {}).get("branches") or {}).get("public") or {}
    buildid = str(public.get("buildid") or "")
    if not buildid:
        return None
    return {
        "buildid": buildid,
        "timeupdated": int(public.get("timeupdated") or public.get("timebuildupdated") or 0),
        "fetchedAt": int(time.time()),
    }


def steam_install(appid: str) -> bool:
    for cmd in (
        ["xdg-open", f"steam://install/{appid}"],
        ["steam", f"steam://install/{appid}"],
    ):
        try:
            subprocess.Popen(
                cmd,
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return True
        except OSError:
            continue
    return False


def collect() -> dict:
    building_pid = lock_pid()
    target_id, target_name = read_target()
    building_name = target_name if building_pid else ""
    pics = load_pics()
    pics_apps = pics.get("apps") or {}
    pics_ts = int(pics.get("ts") or 0)
    games = []
    live = running_appids(ps_args())
    steam_foss = fossilize_appids()
    steam_prog = steam_shader_progress()
    for man in iter_manifests():
        appid = man.stem.removeprefix("appmanifest_")
        vals = acf_values(man.read_text(errors="replace"))
        name = vals.get("name") or appid
        installdir = vals.get("installdir") or ""
        if is_tool(name, installdir):
            continue
        last_updated = int(vals.get("LastUpdated") or 0)
        state = int(vals.get("StateFlags") or 0)
        to_dl = int(vals.get("BytesToDownload") or 0)
        got = int(vals.get("BytesDownloaded") or 0)
        to_stage = int(vals.get("BytesToStage") or 0)
        staged = int(vals.get("BytesStaged") or 0)
        bytes_left = (to_dl > 0 and got < to_dl) or (to_stage > 0 and staged < to_stage)
        updating = bool(state & STATE_BUSY) or bytes_left
        if updating and to_dl <= 0 and to_stage > 0:
            to_dl, got = to_stage, staged
        steam_here = appid in steam_foss
        installed = bool(state & 4) or man.is_file()
        patch_queued = bool(state & STATE_UPDATE_REQUIRED) and not updating
        shader = shader_dir(appid)
        nvidia = shader / "nvidiav1" if shader else None
        nvidia_bytes = dir_size(nvidia) if nvidia else 0
        nvidia_mtime = newest_mtime(nvidia) if nvidia else 0
        # UI "кэш" is the compiled NVIDIA blob, not Steam's FOZ input.
        cache_bytes = nvidia_bytes
        install_bytes = int(vals.get("SizeOnDisk") or 0)
        foz, replay, _ = foz_bundle(shader) if shader else (None, None, None)
        foz_mtime = int(foz.stat().st_mtime) if foz else 0
        replay_sz, replay_mtime = replay_stats(foz)
        if replay and not replay_sz:
            try:
                replay_sz = replay.stat().st_size
                replay_mtime = int(replay.stat().st_mtime)
            except OSError:
                pass
        foz_sz = foz.stat().st_size if foz else 0
        merged_sz = merged_nvidia_bytes(nvidia)
        cache_mtime = max(nvidia_mtime, replay_mtime)
        done = replay_complete(foz, replay)
        # Dota/OW load NVIDIA's disk cache. A 1% fossilize run leaves a few
        # hundred MiB and is not a cache. Large FOZ needs a real GLCache.
        nvidia_min = 32 * 1024 * 1024
        if foz_sz >= 256 * 1024 * 1024:
            nvidia_min = max(512 * 1024 * 1024, foz_sz // 4)
        pack_mtime = max(foz_mtime, last_updated)
        nvidia_after_pack = nvidia_bytes >= nvidia_min and (
            not pack_mtime or nvidia_mtime + 120 >= pack_mtime
        )
        merged_after_pack = merged_sz >= nvidia_min and (
            not pack_mtime or nvidia_mtime + 120 >= pack_mtime
        )
        # Gameplay GLCache is not a full Steam FOZ replay. A 2GiB cache from
        # last night's match still leaves a 3GiB shader pack uncompiled.
        nvidia_fresh = (nvidia_after_pack or merged_after_pack) and (
            foz_sz < 256 * 1024 * 1024 or done
        )
        foz_newer = bool(foz_mtime and nvidia_mtime and nvidia_mtime + 120 < foz_mtime)

        this_building = bool(building_pid) and (
            appid == target_id or (not target_id and not building_name)
        )
        steam_line = steam_prog.get(appid) if steam_here else None

        if updating:
            shaders = "blocked"
            if to_dl > 0 and got < to_dl:
                detail = f"Steam качает {fmt_bytes(got)} / {fmt_bytes(to_dl)}"
            elif to_stage > 0 and staged < to_stage:
                detail = f"Steam стейджит {fmt_bytes(staged)} / {fmt_bytes(to_stage)}"
            else:
                detail = "игра обновляется"
        elif steam_here:
            shaders = "building"
            building_name = name
            if steam_line:
                detail = (
                    f"Steam собирает {steam_line['percent']:.0f}% "
                    f"({steam_line['done']}/{steam_line['total']})"
                )
            else:
                detail = "Steam собирает шейдеры"
        elif this_building:
            shaders = "building"
            building_name = target_name or name
            prog = last_progress()
            detail = f"собираю {prog}" if prog else "собираю без запуска игры"
        elif foz and foz_sz >= 256 * 1024 * 1024 and not done:
            shaders = "stale"
            if foz_newer:
                detail = (
                    f"пакет шейдеров Steam новее NVIDIA — "
                    f"{fmt_bytes(nvidia_bytes)} / FOZ {fmt_bytes(foz_sz)}"
                )
            elif nvidia_bytes:
                detail = f"FOZ не прогнан — NVIDIA {fmt_bytes(nvidia_bytes)} / FOZ {fmt_bytes(foz_sz)}"
            else:
                detail = f"FOZ {fmt_bytes(foz_sz)} не прогнан"
        elif nvidia_fresh:
            shaders = "ready"
            detail = "кэш NVIDIA на месте"
        elif done:
            shaders = "ready"
            detail = "Steam-кэш собран"
        elif last_updated and cache_mtime and cache_mtime + 120 < last_updated:
            shaders = "stale"
            detail = "игра новее кэша шейдеров"
        elif foz and foz_sz < 16 * 1024 * 1024 and nvidia_bytes >= 32 * 1024 * 1024:
            shaders = "ready"
            detail = "мелкий FOZ, кэш NVIDIA на месте"
        elif foz and (not replay or replay_mtime + 30 < foz_mtime):
            shaders = "stale"
            detail = "FOZ скачан, пайплайны не прогнаны"
        elif nvidia_bytes < 32 * 1024 * 1024:
            shaders = "missing"
            detail = "кэша ещё нет"
        else:
            shaders = "stale"
            detail = f"кэш NVIDIA {fmt_bytes(nvidia_bytes)}, сборка не догнана"

        running = appid in live

        foz_bytes = foz.stat().st_size if foz else 0
        local_build = str(vals.get("buildid") or "")
        remote = pics_apps.get(appid) if isinstance(pics_apps.get(appid), dict) else None
        remote_build = str((remote or {}).get("buildid") or "")
        game_current = None
        if remote_build:
            game_current = bool(local_build) and remote_build == local_build and not updating
            if game_current is False and not updating:
                detail = f"Steam build {remote_build}, локально {local_build or 'нет'}"
                if shaders == "ready":
                    shaders = "stale"
        elif patch_queued:
            game_current = False
            if shaders == "ready":
                shaders = "stale"
            if "обновляется" not in detail:
                detail = "Steam ждёт патч"
        shaders_ok = shaders == "ready" and game_current is not False
        can_build = bool(foz) and not running and not updating and not steam_here
        if shaders == "building":
            if steam_line:
                build_percent = float(steam_line["percent"])
            elif this_building:
                build_percent = progress_percent()
            else:
                build_percent = 0.0
        else:
            build_percent = 0.0
        download_percent = 0.0
        if to_dl > 0:
            download_percent = min(100.0, 100.0 * got / to_dl)
        if shaders == "building":
            action = f"{build_percent:.0f}%" if build_percent else "Steam"
        elif updating:
            action = f"{download_percent:.0f}%" if to_dl else "качаю"
        elif running:
            action = "в игре"
        elif game_current is False:
            action = "Патч"
        elif not foz:
            action = ""
        elif shaders in ("stale", "missing"):
            action = "Собрать"
        else:
            action = "Ещё раз"

        games.append(
            {
                "id": appid,
                "name": name,
                "kind": game_kind(appid, man.parent, installdir),
                "installed": installed,
                "updated": installed and not updating,
                "updating": updating,
                "running": running,
                "buildid": local_build,
                "gameLatest": remote_build,
                "gameCurrent": game_current,
                "shadersOk": shaders_ok,
                "checkedAt": int((remote or {}).get("fetchedAt") or pics_ts or 0),
                "lastUpdated": last_updated,
                "shaders": shaders,
                "installBytes": install_bytes,
                "cacheBytes": cache_bytes,
                "nvidiaBytes": nvidia_bytes,
                "fozBytes": foz_bytes,
                "fozNewer": foz_newer,
                "downloadBytes": got,
                "downloadTotal": to_dl,
                "downloadPercent": round(download_percent, 1),
                "buildPercent": build_percent,
                "detail": detail,
                "action": action,
                "canBuild": can_build,
            }
        )

    games.sort(
        key=lambda g: (
            not g["updating"],
            g["shaders"] != "building",
            g.get("gameCurrent") is not False,
            g["shaders"] != "stale",
            g["shaders"] != "missing",
            g["name"].lower(),
        )
    )
    stale = any(
        g["shaders"] in ("stale", "missing", "building") or g.get("gameCurrent") is False
        for g in games
    )
    downloading = [g for g in games if g.get("updating")]
    compiling = next((g for g in games if g["shaders"] == "building"), None)
    bar_percent = 0.0
    bar_kind = ""
    bar_name = ""
    if compiling:
        bar_kind = "compile"
        bar_name = compiling["name"]
        bar_percent = float(compiling.get("buildPercent") or 0)
    elif downloading:
        bar_kind = "download"
        bar_name = downloading[0]["name"]
        bar_percent = float(downloading[0].get("downloadPercent") or 0)
    elif any(g.get("gameCurrent") is False for g in games):
        bar_kind = "patch"
        bar_name = next(g["name"] for g in games if g.get("gameCurrent") is False)
    elif stale:
        bar_kind = "shaders"
    return {
        "ts": int(time.time()),
        "building": bool(building_pid) or bool(steam_foss),
        "buildingPid": building_pid or 0,
        "buildingName": building_name
        or (compiling["name"] if compiling else ""),
        "checkedAt": pics_ts,
        "stale": stale,
        "updating": bool(downloading),
        "updatingName": downloading[0]["name"] if downloading else "",
        "downloadPercent": float(downloading[0].get("downloadPercent") or 0) if downloading else 0.0,
        "barKind": bar_kind,
        "barName": bar_name,
        "barPercent": bar_percent,
        "games": games,
    }


def cmd_status() -> int:
    payload = collect()
    write_status(payload)
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def busy_game(appid: str | None = None) -> str | None:
    live = running_appids(ps_args())
    if not live:
        return None
    if appid and appid not in live:
        return None
    for man in iter_manifests():
        mid = man.stem.removeprefix("appmanifest_")
        if mid not in live:
            continue
        if appid and mid != appid:
            continue
        vals = acf_values(man.read_text(errors="replace"))
        name = vals.get("name") or mid
        if not is_tool(name, vals.get("installdir") or ""):
            return name
    return None


def nvidia_compile_env(shader: Path) -> dict[str, str]:
    # SPIR-V compile is the NVIDIA driver on CPU (libnvidia-gpucomp).
    # vkCreate*Pipeline hits the 5060 Ti. Pin that ICD so Mesa/RADV
    # cannot steal device-index 0.
    nv_cache = str(shader / "nvidiav1")
    env = {
        "__GL_SHADER_DISK_CACHE": "1",
        "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP": "1",
        "__GL_SHADER_DISK_CACHE_SIZE": "8589934592",
        "__GL_SHADER_DISK_CACHE_PATH": nv_cache,
        "DISABLE_LAYER_MESA_DEVICE_SELECT": "1",
    }
    if NVIDIA_ICD.is_file():
        icd = str(NVIDIA_ICD)
        env["VK_DRIVER_FILES"] = icd
        env["VK_ICD_FILENAMES"] = icd
    return env


def run_fossilize(shader: Path, foz: Path, replay_prefix: Path, whitelist: Path | None) -> int:
    if not FOSSILIZE.is_file():
        return 1
    # NVIDIA pipeline compile hits the GPU. 15 threads + a Quickshell
    # reload SIGTRAPs Electron (Cursor/Chrome) on this 5060 Ti.
    cpu = os.cpu_count() or 8
    threads = str(max(2, min(4, cpu // 4)))
    runner = [str(STEAM_RUN)] if STEAM_RUN.is_file() else []
    pin = nvidia_compile_env(shader)
    if NVSETTINGS.is_file():
        subprocess.run(
            [str(NVSETTINGS), "-a", "[gpu:0]/GPUPowerMizerMode=1"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    inner = ["env"]
    for key, val in pin.items():
        inner.append(f"{key}={val}")
    inner.extend(
        [
            str(FOSSILIZE),
            "--num-threads",
            threads,
            "--device-index",
            "0",
            "--shader-cache-size",
            "8192",
            "--progress",
            "--disable-rate-limiter",
            "--replayer-cache",
            str(replay_prefix),
        ]
    )
    if whitelist:
        inner.extend(["--on-disk-validation-whitelist", str(whitelist)])
    inner.append(str(foz))
    cmd = runner + inner
    env = os.environ.copy()
    env.update(pin)
    log = CACHE / "shader-build.log"
    CACHE.mkdir(parents=True, exist_ok=True)
    with log.open("ab") as fh:
        fh.write(f"\n# {time.strftime('%F %T')} {' '.join(cmd)}\n".encode())
        fh.flush()
        proc = subprocess.run(cmd, env=env, check=False, stdout=fh, stderr=subprocess.STDOUT)
    return proc.returncode


def stop_jobs() -> None:
    pid = lock_pid()
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    LOCK_PATH.unlink(missing_ok=True)
    TARGET_PATH.unlink(missing_ok=True)
    kill_replay()
    time.sleep(0.3)
    kill_replay()


def cmd_build(appid: str | None) -> int:
    steam_foss = fossilize_appids()
    if steam_foss:
        payload = collect()
        write_status(payload)
        names = [g["name"] for g in payload["games"] if g["id"] in steam_foss]
        notify("Шейдеры", "Steam уже собирает: " + ", ".join(names or ["игру"]))
        print(json.dumps(payload, ensure_ascii=False))
        return 0

    existing = lock_pid()
    if existing:
        cur_id, cur_name = read_target()
        same = bool(appid) and appid == cur_id
        if same or not appid:
            payload = collect()
            write_status(payload)
            print(json.dumps(payload, ensure_ascii=False))
            return 0
        if os.environ.get("SHADER_CTL_DAEMON") == "1":
            payload = collect()
            write_status(payload)
            print(json.dumps(payload, ensure_ascii=False))
            return 0
        payload = collect()
        new_name = next((g["name"] for g in payload["games"] if g["id"] == appid), appid)
        notify("Шейдеры", f"Останавливаю {cur_name or cur_id}, собираю {new_name}")
        stop_jobs()

    if os.environ.get("SHADER_CTL_DAEMON") != "1":
        CACHE.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["SHADER_CTL_DAEMON"] = "1"
        log = (CACHE / "shader-ctl.out").open("ab")
        subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "build"] + ([appid] if appid else []),
            env=env,
            start_new_session=True,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        time.sleep(0.3)
        payload = collect()
        write_status(payload)
        print(json.dumps(payload, ensure_ascii=False))
        return 0

    CACHE.mkdir(parents=True, exist_ok=True)
    LOCK_PATH.write_text(str(os.getpid()))
    try:
        payload = collect()
        write_status(payload)
        if appid:
            targets = [g for g in payload["games"] if g["id"] == appid and g.get("fozBytes")]
        else:
            targets = [
                g
                for g in payload["games"]
                if g.get("canBuild") and g["shaders"] in ("stale", "missing", "building")
            ]
        skipped = []
        kept = []
        for game in targets:
            busy = busy_game(game["id"])
            if busy:
                skipped.append(game["name"])
            else:
                kept.append(game)
        targets = kept
        if not targets:
            if skipped:
                notify("Шейдеры", "Сейчас запущена " + ", ".join(skipped) + " — сборка после выхода")
                payload = collect()
                payload["error"] = "running:" + ",".join(skipped)
            else:
                notify("Шейдеры", "Собирать нечего — кэш актуален или нет FOZ")
                payload = collect()
            write_status(payload)
            print(json.dumps(payload, ensure_ascii=False))
            return 2 if skipped else 0

        failed = []
        for game in targets:
            shader = shader_dir(game["id"])
            if not shader:
                failed.append(game["name"])
                continue
            bundles = []
            for foz in foz_candidates(shader):
                try:
                    sz = foz.stat().st_size
                except OSError:
                    continue
                if sz < 16 * 1024 * 1024:
                    continue
                whitelist = foz.parent / "steam_pipeline_cache_whitelist.foz"
                if not whitelist.is_file():
                    whitelist = None
                replay_prefix = foz.parent / "replay_cache"
                bundles.append((foz, replay_prefix, whitelist, sz))
            if not bundles:
                foz, replay, whitelist = foz_bundle(shader)
                if foz:
                    replay_prefix = (replay.parent if replay else foz.parent) / "replay_cache"
                    bundles.append((foz, replay_prefix, whitelist, 0))
            if not bundles:
                failed.append(game["name"])
                continue
            write_target(game["id"], game["name"])
            write_status(collect())
            notify("Шейдеры", f"Собираю {game['name']} без запуска")
            rc = 0
            for foz, replay_prefix, whitelist, _sz in bundles:
                rc = run_fossilize(shader, foz, replay_prefix, whitelist)
                if rc != 0:
                    break
            if rc != 0:
                failed.append(game["name"])
        payload = collect()
        write_status(payload)
        if failed:
            notify("Шейдеры", "Не собралось: " + ", ".join(failed))
            return 1
        notify("Шейдеры", "Готово — можно заходить")
        print(json.dumps(payload, ensure_ascii=False))
        return 0
    finally:
        try:
            if LOCK_PATH.read_text().strip().splitlines()[0] == str(os.getpid()):
                LOCK_PATH.unlink(missing_ok=True)
        except OSError:
            pass
        TARGET_PATH.unlink(missing_ok=True)
        write_status(collect())


def cmd_check(appid: str | None, quiet: bool = False) -> int:
    payload = collect()
    ids = [appid] if appid else [g["id"] for g in payload["games"]]
    pics = load_pics()
    apps = pics.setdefault("apps", {})
    failed = []

    def one(i: str) -> tuple[str, dict | None]:
        return i, fetch_public_build(i)

    with ThreadPoolExecutor(max_workers=min(4, max(1, len(ids)))) as pool:
        for i, info in pool.map(lambda x: one(x), ids):
            if info:
                apps[i] = info
            else:
                failed.append(i)
    pics["ts"] = int(time.time())
    save_pics(pics)
    payload = collect()
    payload["checkedAt"] = pics["ts"]
    payload["checkFailed"] = failed
    write_status(payload)
    names = {g["id"]: g["name"] for g in payload["games"]}
    outdated = [g["name"] for g in payload["games"] if g.get("gameCurrent") is False]
    if not quiet:
        if failed:
            notify("Steam", "Не достучался: " + ", ".join(names.get(i, i) for i in failed))
        elif outdated:
            notify("Steam", "Есть патч: " + ", ".join(outdated))
        else:
            notify("Steam", "Игры свежие — сверка с Steam PICS")
        print(json.dumps(payload, ensure_ascii=False))
    return 1 if failed else 0


def cmd_update(appid: str | None) -> int:
    cmd_check(appid, quiet=True)
    payload = collect()
    targets = [g for g in payload["games"] if appid is None or g["id"] == appid]
    if not targets:
        notify("Шейдеры", "Игра не найдена")
        print(json.dumps(payload, ensure_ascii=False))
        return 1
    launched = []
    need_build = []
    for game in targets:
        if game.get("updating") or game["id"] in fossilize_appids():
            if game.get("updating") and steam_install(game["id"]):
                launched.append(game["name"])
            continue
        if game.get("gameCurrent") is False:
            if steam_install(game["id"]):
                launched.append(game["name"])
            continue
        if game["shaders"] in ("stale", "missing", "building") or not game.get("shadersOk"):
            if game.get("canBuild") or game.get("fozBytes"):
                need_build.append(game["id"])
    if launched:
        notify("Steam", "Качаю патч: " + ", ".join(launched))
    if not need_build:
        write_status(collect())
        print(json.dumps(collect(), ensure_ascii=False))
        return 0
    if appid:
        return cmd_build(appid)
    return cmd_build(need_build[0] if len(need_build) == 1 else None)


def replay_pids() -> list[int]:
    pids: list[int] = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            comm = (proc / "comm").read_text().strip()
        except OSError:
            continue
        # comm is 16 bytes including NUL, so fossilize_replay -> fossilize_repla
        if comm.startswith("fossilize"):
            pids.append(int(proc.name))
    return pids


def kill_replay() -> None:
    for pid in replay_pids():
        if steam_owned_fossilize(pid):
            continue
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    time.sleep(1)
    for pid in replay_pids():
        if steam_owned_fossilize(pid):
            continue
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass


def cmd_stop() -> int:
    stop_jobs()
    payload = collect()
    write_status(payload)
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def main() -> int:
    args = sys.argv[1:]
    cmd = args[0] if args else "status"
    if cmd == "status":
        return cmd_status()
    if cmd == "build":
        return cmd_build(args[1] if len(args) > 1 else None)
    if cmd == "stop":
        return cmd_stop()
    if cmd == "check":
        return cmd_check(args[1] if len(args) > 1 else None)
    if cmd == "update":
        return cmd_update(args[1] if len(args) > 1 else None)
    print("usage: shader-ctl.py status|check [appid]|update [appid]|build [appid]|stop", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
