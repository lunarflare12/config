#!/usr/bin/env bash
# IntelliJ IDEA Ultimate inside wayland-box (namespaces + isolated HOME).
# Host PATH keeps idea-oss; this binary is never installed as `idea`.
set -euo pipefail

BOX="${HOME}/.config/scripts/wayland-box.sh"
PROJECTS="${HOME}/IdeaProjects"
CONFIG_REPO="${HOME}/config"
BOX_HOME="${HOME}/.local/share/wayland-box/idea-ultimate"
JB_CONFIG="${HOME}/.config/JetBrains"
JB_SHARE="${HOME}/.local/share/JetBrains"
JB_CACHE="${HOME}/.cache/JetBrains"

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

mkdir -p "$PROJECTS" "$JB_CONFIG" "$JB_CACHE" \
  "$JB_SHARE/IntelliJIdea2026.2" \
  "$BOX_HOME/.config/JetBrains" \
  "$BOX_HOME/.local/share/JetBrains" \
  "$BOX_HOME/.cache/JetBrains"
BIN="$(readlink -f "$(resolve_idea)")"
if [[ ! -x "$BIN" ]]; then
  echo "idea-ultimate: resolved binary is not executable: $BIN" >&2
  exit 1
fi

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

# Private pid ns left PID 2 in .lock; host kthreadd is also 2, so drop dead locks.
drop_stale_locks "$BOX_HOME/.config/JetBrains"
drop_stale_locks "$JB_CONFIG"

BINDS=(
  --bind "$PROJECTS"
  --bind "$JB_CONFIG"
  --bind "$JB_SHARE"
  --bind "$JB_CACHE"
)
[[ -d "$CONFIG_REPO" ]] && BINDS+=(--bind "$CONFIG_REPO")

exec "$BOX" --name idea-ultimate "${BINDS[@]}" -- "$BIN" "$@"
