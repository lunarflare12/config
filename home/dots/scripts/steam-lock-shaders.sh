#!/usr/bin/env bash
# Pin Proton launch wrappers. Do not kill Steam's fossilize or clear
# its shader queue — cache rebuilds belong to Steam.
set -euo pipefail

HOME="${HOME:-/home/dd}"

python3 - "$HOME" <<'PY'
import re
import sys
from pathlib import Path

home = Path(sys.argv[1])
script = home / ".config/scripts"
wanted = {
    "570": f"{script}/dota.sh %command%",
    "444090": f"{script}/paladins.sh %command%",
    "761890": f"{script}/albion.sh %command%",
    "2357570": f"{script}/overwatch.sh %command%",
}


def app_block_span(text, appid):
    for m in re.finditer(rf'"{appid}"\s*\n(\t+)\{{', text):
        indent = m.group(1)
        brace = m.end() - 1
        depth = 0
        for i in range(brace, len(text)):
            ch = text[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return m.start(), brace + 1, i, indent
    return None


for cfg in (home / ".local/share/Steam/userdata").glob("*/config/localconfig.vdf"):
    text = cfg.read_text(errors="replace")
    orig = text
    for appid, cmd in wanted.items():
        span = app_block_span(text, appid)
        if not span:
            continue
        start, body_at, body_end, indent = span
        body = text[body_at:body_end]
        line = f'{indent}\t"LaunchOptions"\t\t"{cmd}"\n'
        if re.search(r'"LaunchOptions"\s*"[^"]*"', body):
            body = re.sub(
                r'"LaunchOptions"\s*"[^"]*"',
                f'"LaunchOptions"\t\t"{cmd}"',
                body,
                count=1,
            )
        else:
            body = "\n" + line + body.lstrip("\n")
        text = text[:body_at] + body + text[body_end:]
    if text != orig:
        cfg.write_text(text)
PY
