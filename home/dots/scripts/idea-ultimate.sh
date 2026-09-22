#!/usr/bin/env bash
# IntelliJ Ultimate on the host. wayland-box + JBR WLToolkit maps no
# Hyprland window (JVM lives, compositor never sees a client). XWayland
# is the toolkit that actually shows a frame on this session.
set -euo pipefail

JB_CONFIG="${HOME}/.config/JetBrains"

resolve_idea() {
  if [[ -n "${IDEA_ULTIMATE_BIN:-}" && -x "${IDEA_ULTIMATE_BIN}" ]]; then
    printf '%s\n' "$IDEA_ULTIMATE_BIN"
    return 0
  fi

  local link="${HOME}/.local/share/idea-ultimate/nix/bin/idea"
  if [[ -x "$link" ]]; then
    printf '%s\n' "$link"
    return 0
  fi

  local p root info
  for p in /nix/store/*-idea-*/bin/idea; do
    [[ -x "$p" ]] || continue
    root=$(readlink -f "$p")
    root="${root%/bin/idea}"
    info=""
    if [[ -f "$root/idea/product-info.json" ]]; then
      info="$root/idea/product-info.json"
    elif [[ -f "$root/product-info.json" ]]; then
      info="$root/product-info.json"
    else
      continue
    fi
    if grep -q '"productCode": "IU"' "$info"; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  echo "idea-ultimate: IntelliJ IDEA Ultimate (IU) not found in the nix store" >&2
  exit 1
}

drop_stale_locks() {
  local root="$1" lock pid
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' lock; do
    pid=$(tr -cd '0-9' <"$lock" || true)
    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$lock"
    fi
  done < <(find "$root" -name '.lock' -type f -print0 2>/dev/null)
}

# Previous invisible WLToolkit instance still holds the single-instance
# lock. Next clicks only poke that JVM; Hyprland still has no window.
kill_invisible_instance() {
  local lock pid
  lock="${JB_CONFIG}/IntelliJIdea2026.2/.lock"
  [[ -f "$lock" ]] || return 0
  pid=$(tr -cd '0-9' <"$lock" || true)
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || return 0
  if hyprctl clients -j 2>/dev/null | grep -Eqi '"class":\s*"jetbrains-idea'; then
    return 0
  fi
  kill "$pid" 2>/dev/null || true
  sleep 0.2
  kill -9 "$pid" 2>/dev/null || true
  pkill -f 'wayland-box.sh --name idea-ultimate' 2>/dev/null || true
  rm -f "$lock"
}

mkdir -p "$JB_CONFIG" "${HOME}/.local/share/JetBrains" "${HOME}/.cache/JetBrains" \
  "${HOME}/IdeaProjects"
kill_invisible_instance
drop_stale_locks "$JB_CONFIG"

BIN="$(readlink -f "$(resolve_idea)")"
if [[ ! -x "$BIN" ]]; then
  echo "idea-ultimate: resolved binary is not executable: $BIN" >&2
  exit 1
fi

export _JAVA_AWT_WM_NONREPARENTING=1
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+${JAVA_TOOL_OPTIONS} }-Dawt.toolkit.name=XToolkit"

exec "$BIN" "$@"
