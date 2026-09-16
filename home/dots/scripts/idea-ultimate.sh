#!/usr/bin/env bash
# IntelliJ IDEA Ultimate inside wayland-box (namespaces + isolated HOME).
# Host PATH keeps idea-oss; this binary is never installed as `idea`.
set -euo pipefail

BOX="${HOME}/.config/scripts/wayland-box.sh"
PROJECTS="${HOME}/IdeaProjects"
CONFIG_REPO="${HOME}/config"

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

mkdir -p "$PROJECTS"
BIN="$(readlink -f "$(resolve_idea)")"
if [[ ! -x "$BIN" ]]; then
  echo "idea-ultimate: resolved binary is not executable: $BIN" >&2
  exit 1
fi

BINDS=(--bind "$PROJECTS")
[[ -d "$CONFIG_REPO" ]] && BINDS+=(--bind "$CONFIG_REPO")

exec "$BOX" --name idea-ultimate "${BINDS[@]}" -- "$BIN" "$@"
