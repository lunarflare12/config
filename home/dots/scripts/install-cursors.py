#!/usr/bin/env python3
"""Install Aurora cursor packs from vsthemes archives into XCursor themes."""
from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

HOME = Path.home()
REPO = HOME / "config/home/dots/cursors"
SRC = REPO / "_src"
THEMES = REPO / "themes"
PREVIEW = HOME / "config/home/dots/aurora-qs/assets/cursors/previews"
CATALOGUE = HOME / "config/home/dots/aurora-qs/assets/cursors/catalogue.json"
DOWNLOADS = HOME / "Downloads"
ICONS = HOME / ".local/share/icons"
ICONS_ALT = HOME / ".icons"
WIN2XCUR = Path("/tmp/win2xcur")
MAGICK = os.environ.get("MAGICK") or shutil.which("magick") or ""

ARCHIVES = {
    "miku-niner": ["miku-niner_*VSTHEMES-ORG.zip"],
    "agnes-tachyon": ["agnes-tachyon_*VSTHEMES-ORG.zip"],
    "curren-chan": ["curren-chan*_VSTHEMES-ORG.zip"],
    "moga": ["moga_*VSTHEMES-ORG.zip"],
    "purple-neon-glass": ["purple-neon-glass_*VSTHEMES-ORG.zip"],
    "hatsune-miku": ["hatsune-miku_*VSTHEMES-ORG.zip"],
    "mita": ["mita_*VSTHEMES-ORG.zip"],
    "overwatch-pointer": ["overwatch-pointer_*VSTHEMES-ORG.rar"],
    "castorice": ["castorice_*VSTHEMES-ORG.zip"],
    "gradient-blue": ["gradient-blue_*VSTHEMES-ORG.rar"],
    "frieren": ["frieren_*VSTHEMES-ORG.zip"],
    "terracota": ["terracota_*VSTHEMES-ORG.rar"],
}

PACKS = list(ARCHIVES) + [
    "hatsune-miku-static",
    "castorice-static",
    "mita-static",
    "frieren-winter",
]


def base_id(item_id: str) -> str:
    for suffix in ("-static", "-winter"):
        if item_id.endswith(suffix):
            return item_id[: -len(suffix)]
    return item_id


def pack_kind(item_id: str) -> str:
    if item_id.endswith("-static"):
        return "static"
    if item_id.endswith("-winter"):
        return "winter"
    return "default"

ALIASES = {
    "left_ptr": ("arrow", "default", "top_left_arrow", "left_ptr"),
    "question_arrow": ("help", "question_arrow"),
    "wait": ("watch", "wait"),
    "left_ptr_watch": ("progress", "left_ptr_watch"),
    "xterm": ("ibeam", "text", "xterm"),
    "pointer": ("hand1", "hand2", "pointer"),
    "crosshair": ("cross", "crosshair"),
    "crossed_circle": ("not-allowed", "circle", "dnd-no-drop", "crossed_circle"),
    "pencil": ("pencil",),
    "fleur": ("move", "size_all", "all-scroll", "fleur"),
    "sb_h_double_arrow": ("ew-resize", "col-resize", "size_hor", "sb_h_double_arrow"),
    "sb_v_double_arrow": ("ns-resize", "row-resize", "size_ver", "sb_v_double_arrow"),
    "bd_double_arrow": ("nwse-resize", "size_bdiag", "bd_double_arrow"),
    "fd_double_arrow": ("nesw-resize", "size_fdiag", "fd_double_arrow"),
    "center_ptr": ("center_ptr",),
}


def catalogue() -> list[dict]:
    data = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    return data if isinstance(data, list) else data.get("cursors", [])


def theme_name(item_id: str) -> str:
    for item in catalogue():
        if item.get("id") == item_id:
            return item.get("theme") or item_id
    return item_id


def latest(patterns: list[str]) -> Path | None:
    hits: list[Path] = []
    for pat in patterns:
        hits.extend(DOWNLOADS.glob(pat))
        hits.extend(SRC.glob(pat))
    if not hits:
        return None
    return max(hits, key=lambda p: p.stat().st_mtime)


def extract_archive(src: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(src):
        zipfile.ZipFile(src).extractall(dest)
        return
    for cmd in (
        ["unar", "-f", "-o", str(dest), str(src)],
        ["unrar", "x", "-o+", str(src), str(dest) + "/"],
        ["7z", "x", "-y", f"-o{dest}", str(src)],
        ["bsdtar", "-xf", str(src), "-C", str(dest)],
    ):
        if shutil.which(cmd[0]):
            subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
            return
    raise RuntimeError(f"cannot extract {src.name}")


def find_linux_cursors(root: Path) -> Path | None:
    ranked: list[tuple[int, Path]] = []
    for path in root.rglob("cursors"):
        if not path.is_dir():
            continue
        text = str(path).lower()
        if "macos" in text or "windows" in text or "hyprcursor" in text:
            continue
        if "linux" in text or (path / "left_ptr").exists() or (path / "default").exists():
            n = sum(1 for p in path.iterdir() if p.is_file() or p.is_symlink())
            ranked.append((n, path))
    if not ranked:
        return None
    ranked.sort(key=lambda x: x[0], reverse=True)
    return ranked[0][1]


def win_files(root: Path, item_id: str) -> list[Path]:
    files = [p for p in root.rglob("*") if p.suffix.lower() in {".cur", ".ani"}]
    kind = pack_kind(item_id)
    keep = []
    for path in files:
        parts = [part.lower() for part in path.parts]
        low = str(path).lower()
        if "macos" in parts:
            continue
        if kind == "static":
            if "static" not in parts:
                continue
        elif kind == "winter":
            if "winter" not in low:
                continue
        else:
            if "static" in parts:
                continue
            if base_id(item_id) == "frieren" and "winter" in low:
                continue
        keep.append(path)
    if base_id(item_id) == "frieren":
        if kind == "winter":
            keep = [p for p in keep if "winter" in str(p).lower()]
        else:
            keep = [p for p in keep if "frieren cursor" in str(p).lower() and "winter" not in str(p).lower()]
    return keep


def role_of(name: str) -> str | None:
    n = name.lower().replace("\\", "/").split("/")[-1]
    n = n.rsplit(".", 1)[0]
    n = n.replace("_", " ").replace("-", " ")
    for prefix in (
        "frieren w ",
        "frierenw ",
        "frieren ",
        "vs cursor ",
        "purple neon glass cursor ",
    ):
        if n.startswith(prefix):
            n = n[len(prefix) :]
    n = " ".join(n.split())
    table = [
        (("normal", "arrow", "default", "pointer", "pointer select", "normal select"), "left_ptr"),
        (("help", "ayuda", "question"), "question_arrow"),
        (("busy", "ocupado", "wait"), "wait"),
        (("working", "work", "appstarting", "segundo plano", "working in background"), "left_ptr_watch"),
        (("text", "texto", "ibeam", "beam"), "xterm"),
        (("link", "hand"), "pointer"),
        (("precision", "crosshair", "cross"), "crosshair"),
        (("unavailable", "unavailiable", "no disponible", "forbidden", "not allowed", "unavralible"), "crossed_circle"),
        (("move", "mover", "fleur", "sizeall", "size all"), "fleur"),
        (("horizontal", "sizewe", "ew resize", "horz"), "sb_h_double_arrow"),
        (("vertical", "sizens", "ns resize", "vert"), "sb_v_double_arrow"),
        (("diagonal 1", "diagonal1", "diagonal resize 1", "diagonal rezise 1", "dgn1", "nwse"), "bd_double_arrow"),
        (("diagonal 2", "diagonal2", "diagonal resize 2", "diagonal rezise 2", "dgn2", "nesw"), "fd_double_arrow"),
        (("handwriting", "escritura a mano", "pen", "pencil"), "pencil"),
        (("alternate", "alt", "alternative", "up", "center"), "center_ptr"),
    ]
    for keys, role in table:
        if n in keys or any(n.endswith(k) or n == k for k in keys):
            return role
    return None


def convert_windows(files: list[Path], dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["PYTHONPATH"] = str(WIN2XCUR) + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    raw = dest / "_raw"
    raw.mkdir(parents=True, exist_ok=True)
    for path in files:
        try:
            subprocess.run(
                [sys.executable, "-m", "win2xcur.main.win2xcur", "-o", str(raw), str(path)],
                check=True,
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
            )
        except subprocess.CalledProcessError as exc:
            print(f"install-cursors: skip {path.name}: {exc.stderr[-200:]}", file=sys.stderr)
    for path in raw.iterdir():
        if not path.is_file():
            continue
        role = role_of(path.name)
        if not role:
            continue
        target = dest / role
        if target.exists():
            continue
        shutil.copy2(path, target)
    shutil.rmtree(raw, ignore_errors=True)


def link_aliases(cursors: Path) -> None:
    for role, names in ALIASES.items():
        src = cursors / role
        if not src.exists():
            for alias in names:
                cand = cursors / alias
                if cand.exists() and not src.exists():
                    src.symlink_to(alias)
                    break
        if not src.exists():
            continue
        for alias in names:
            if alias == role:
                continue
            target = cursors / alias
            if target.exists() or target.is_symlink():
                continue
            target.symlink_to(role)


def write_index(dest: Path, name: str) -> None:
    (dest / "index.theme").write_text(
        f"[Icon Theme]\nName={name}\nComment={name}\nInherits=macOS\n",
        encoding="utf-8",
    )
    (dest / "cursor.theme").write_text(
        f"[Icon Theme]\nName={name}\nInherits={name}\n",
        encoding="utf-8",
    )


def link_icons(theme: str, dest: Path) -> None:
    for root in (ICONS, ICONS_ALT):
        root.mkdir(parents=True, exist_ok=True)
        link = root / theme
        if link.is_symlink() or link.exists():
            if link.is_symlink() or link.is_dir():
                if link.is_symlink():
                    link.unlink()
                else:
                    shutil.rmtree(link)
        link.symlink_to(dest, target_is_directory=True)


XCUR_IMAGE = 0xFFFD0002
XCUR_SIZES = (24, 32, 48, 64, 96)


def parse_xcur_frames(path: Path) -> list[dict]:
    data = path.read_bytes()
    if data[:4] != b"Xcur":
        return []
    _magic, _hs, _ver, ntoc = struct.unpack_from("<4sIII", data, 0)
    frames: list[dict] = []
    off = 16
    for _ in range(ntoc):
        ctype, _subtype, pos = struct.unpack_from("<III", data, off)
        off += 12
        if ctype != XCUR_IMAGE:
            continue
        _size, _atype, nominal, _ver2, width, height, hx, hy, delay = struct.unpack_from("<9I", data, pos)
        blob = data[pos + 36 : pos + 36 + width * height * 4]
        if len(blob) != width * height * 4:
            continue
        frames.append(
            {
                "nominal": nominal,
                "w": width,
                "h": height,
                "hx": hx,
                "hy": hy,
                "delay": delay,
                "bgra": blob,
            }
        )
    return frames


def write_xcur(path: Path, frames: list[dict]) -> None:
    header = struct.pack("<4sIII", b"Xcur", 16, 65536, len(frames))
    pos = 16 + len(frames) * 12
    toc = b""
    chunks = b""
    for frame in frames:
        chunk = struct.pack(
            "<9I",
            36,
            XCUR_IMAGE,
            frame["nominal"],
            1,
            frame["w"],
            frame["h"],
            frame["hx"],
            frame["hy"],
            frame["delay"],
        )
        chunk += frame["bgra"]
        toc += struct.pack("<III", XCUR_IMAGE, frame["nominal"], pos)
        chunks += chunk
        pos += len(chunk)
    path.write_bytes(header + toc + chunks)


def scale_bgra(bgra: bytes, width: int, height: int, size: int) -> bytes:
    if width == size and height == size:
        return bgra
    out = bytearray(size * size * 4)
    for y in range(size):
        sy = min(height - 1, y * height // size)
        for x in range(size):
            sx = min(width - 1, x * width // size)
            src = (sy * width + sx) * 4
            dst = (y * size + x) * 4
            out[dst : dst + 4] = bgra[src : src + 4]
    return bytes(out)


def expand_xcursor(path: Path, sizes: tuple[int, ...] = XCUR_SIZES) -> None:
    frames = parse_xcur_frames(path)
    if not frames:
        return
    by_size: dict[int, list[dict]] = {}
    for frame in frames:
        by_size.setdefault(frame["nominal"], []).append(frame)
    if all(size in by_size for size in sizes):
        return
    src_size = max(by_size)
    src_frames = by_size[src_size]
    out: list[dict] = []
    for size in sizes:
        if size in by_size:
            out.extend(by_size[size])
            continue
        for frame in src_frames:
            out.append(
                {
                    "nominal": size,
                    "w": size,
                    "h": size,
                    "hx": max(0, min(size - 1, round(frame["hx"] * size / max(1, frame["w"])))),
                    "hy": max(0, min(size - 1, round(frame["hy"] * size / max(1, frame["h"])))),
                    "delay": frame["delay"],
                    "bgra": scale_bgra(frame["bgra"], frame["w"], frame["h"], size),
                }
            )
    write_xcur(path, out)


def expand_theme_sizes(cursors: Path) -> None:
    for path in cursors.iterdir():
        if path.is_symlink() or not path.is_file():
            continue
        try:
            expand_xcursor(path)
        except Exception as exc:
            print(f"install-cursors: expand skip {path.name}: {exc}", file=sys.stderr)


def xcursor_best_frame(path: Path) -> tuple[int, int, bytes] | None:
    data = path.read_bytes()
    if data[:4] != b"Xcur":
        return None
    _magic, _hs, _ver, ntoc = struct.unpack_from("<4sIII", data, 0)
    best = None
    off = 16
    for _ in range(ntoc):
        ctype, _subtype, pos = struct.unpack_from("<III", data, off)
        off += 12
        if ctype != 0xFFFD0002:
            continue
        _size, _atype, nominal, _ver2, width, height, _hx, _hy, _delay = struct.unpack_from("<9I", data, pos)
        blob = data[pos + 36 : pos + 36 + width * height * 4]
        if len(blob) != width * height * 4:
            continue
        raw = bytearray(blob)
        for i in range(0, len(raw), 4):
            a = raw[i + 3]
            if a and a < 255:
                raw[i] = min(255, raw[i] * 255 // a)
                raw[i + 1] = min(255, raw[i + 1] * 255 // a)
                raw[i + 2] = min(255, raw[i + 2] * 255 // a)
        if best is None or nominal > best[0]:
            best = (nominal, width, height, bytes(raw))
    if not best:
        return None
    return best[1], best[2], best[3]


def write_thumb(cursors: Path, item_id: str) -> None:
    if not MAGICK:
        raise RuntimeError("no magick")
    src = None
    for name in ("left_ptr", "default", "arrow"):
        cand = cursors / name
        if cand.exists():
            src = cand.resolve() if cand.is_symlink() else cand
            break
    if not src:
        return
    frame = xcursor_best_frame(src)
    if not frame:
        return
    width, height, raw = frame
    PREVIEW.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aurora-thumb-") as tmp:
        bgra = Path(tmp) / "frame.bgra"
        png = Path(tmp) / "frame.png"
        card = PREVIEW / f"{item_id}.png"
        bgra.write_bytes(raw)
        subprocess.run(
            [MAGICK, "-size", f"{width}x{height}", "-depth", "8", f"bgra:{bgra}", str(png)],
            check=True,
        )
        subprocess.run(
            [
                MAGICK,
                "-size",
                "360x216",
                "xc:#141418",
                "(",
                str(png),
                "-background",
                "none",
                "-resize",
                "160x160",
                ")",
                "-gravity",
                "center",
                "-compose",
                "over",
                "-composite",
                str(card),
            ],
            check=True,
        )


def macos_thumb() -> None:
    roots = list(Path("/nix/store").glob("*-apple-cursor-*/share/icons/*/cursors/left_ptr"))
    icons = HOME / ".icons/macOS/cursors/left_ptr"
    local = HOME / ".local/share/icons/macOS/cursors/left_ptr"
    src = None
    for cand in (*roots, icons, local):
        if cand.exists():
            src = cand
            break
    if src:
        parent = src.parent
        write_thumb(parent, "macos")
        return
    if MAGICK:
        subprocess.run(
            [
                MAGICK,
                "-size",
                "360x216",
                "xc:#141418",
                "-fill",
                "#f5f5f7",
                "-draw",
                "polygon 138,42 138,158 168,128 198,178 218,168 188,118 232,118",
                str(PREVIEW / "macos.png"),
            ],
            check=True,
        )


def install_one(item_id: str) -> None:
    theme = theme_name(item_id)
    archive = latest(ARCHIVES[base_id(item_id)])
    if not archive:
        print(f"install-cursors: missing {item_id}", file=sys.stderr)
        return
    SRC.mkdir(parents=True, exist_ok=True)
    stored = SRC / f"{base_id(item_id)}{archive.suffix.lower()}"
    if archive.resolve() != stored.resolve():
        shutil.copy2(archive, stored)
    dest = THEMES / theme
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    cursors = dest / "cursors"
    kind = pack_kind(item_id)
    with tempfile.TemporaryDirectory(prefix="aurora-pack-") as tmp:
        root = Path(tmp)
        extract_archive(stored, root)
        linux = None if kind in {"static", "winter"} else find_linux_cursors(root)
        if linux and ((linux / "left_ptr").exists() or (linux / "default").exists()):
            shutil.copytree(linux, cursors)
            parent = linux.parent
            for name in ("index.theme", "cursor.theme"):
                src = parent / name
                if src.exists():
                    shutil.copy2(src, dest / name)
        else:
            files = win_files(root, item_id)
            if not files:
                print(f"install-cursors: no cursors in {archive.name}", file=sys.stderr)
                shutil.rmtree(dest, ignore_errors=True)
                return
            convert_windows(files, cursors)
    if not (cursors / "left_ptr").exists() and (cursors / "default").exists():
        (cursors / "left_ptr").symlink_to("default")
    link_aliases(cursors)
    if not (dest / "index.theme").exists():
        write_index(dest, theme)
    else:
        write_index(dest, theme)
    expand_theme_sizes(cursors)
    link_icons(theme, dest)
    write_thumb(cursors, item_id)
    roles = sorted(p.name for p in cursors.iterdir() if p.is_file() and not p.is_symlink())
    print(f"install-cursors: {theme} files={len(roles)} from {archive.name}")


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--expand"]
    expand_only = "--expand" in sys.argv[1:]
    if expand_only and not args:
        for dest in sorted(THEMES.iterdir()):
            cursors = dest / "cursors"
            if cursors.is_dir():
                expand_theme_sizes(cursors)
                print(f"install-cursors: expanded {dest.name}")
        return 0
    wanted = args or list(PACKS)
    for item_id in wanted:
        if item_id not in PACKS and base_id(item_id) not in ARCHIVES:
            print(f"install-cursors: skip {item_id}", file=sys.stderr)
            continue
        try:
            install_one(item_id)
        except Exception as exc:
            print(f"install-cursors: {item_id} failed: {exc}", file=sys.stderr)
    macos_thumb()
    items = catalogue()
    changed = False
    for item in items:
        if item.get("id") == "macos":
            continue
        if item.get("thumb", "").endswith(".gif"):
            item["thumb"] = item["id"] + ".png"
            changed = True
    if changed:
        CATALOGUE.write_text(json.dumps(items, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
