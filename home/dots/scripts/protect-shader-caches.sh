#!/usr/bin/env bash
# Keep Steam / NVIDIA shader caches on durable /home storage.
# Never delete cache trees. Never replace a larger cache with a smaller one.
set -euo pipefail

HOME="${HOME:-/home/dd}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

shader_root="${XDG_CACHE_HOME}/steam-shadercache"
dxvk_root="${XDG_CACHE_HOME}/dxvk"

mkdir -p "$shader_root" "$dxvk_root" \
  "$shader_root/761890" "$shader_root/105600" \
  "${XDG_CACHE_HOME}/nvidia/terraria" "${XDG_CACHE_HOME}/nvidia/albion"

chmod u+rwx "$shader_root" "$dxvk_root" 2>/dev/null || true

# Separate inode. A hardlink would die with the Steam copy: Steam truncates
# that path on the next launch. Never replace a larger file with a smaller one.
# Once a real cache is frozen, Steam's next rebuild must not overwrite it.
link_larger() {
  local src=$1 dst=$2
  local sb db
  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  sb=$(wc -c <"$src" 2>/dev/null || echo 0)
  db=0
  if [ -f "$dst" ]; then
    db=$(wc -c <"$dst" 2>/dev/null || echo 0)
  fi
  # A real file stays. Replacing it is how a Steam rebuild used to wipe
  # a cache that was still growing. Only a missing file or a tiny stub
  # may be filled.
  if [ "${db:-0}" -ge 4096 ]; then
    return 0
  fi
  if [ "${sb:-0}" -le "${db:-0}" ]; then
    return 0
  fi
  cp -a "$src" "$dst" || true
}

# Mirror a GLCache tree into the durable directory. Never delete either side.
# Only stamp .frozen when the tree is a real multi‑GB cache — mid‑compile
# stubs must stay unfrozen so Steam keeps writing.
keep_nvidia() {
  local src=$1 dest_root=$2
  [ -d "$src" ] || return 0
  mkdir -p "$dest_root"
  printf 'protected\n' >"${dest_root}/.aurora-no-delete"
  local f rel dst total=0
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    dst="${dest_root}/${rel}"
    link_larger "$f" "$dst"
  done < <(find "$src" -type f -name '*.bin' -print0 2>/dev/null)
  total=$(du -sb "$dest_root" 2>/dev/null | awk '{print $1}')
  if [ "${total:-0}" -ge 2147483648 ]; then
    printf 'frozen\n' >"${dest_root}/.frozen"
  else
    rm -f "${dest_root}/.frozen"
  fi
}

keep_nvidia "${shader_root}/105600/nvidiav1" "${XDG_CACHE_HOME}/nvidia/terraria"
keep_nvidia "${shader_root}/761890/nvidiav1" "${XDG_CACHE_HOME}/nvidia/albion"
keep_nvidia "/steam/steamapps/shadercache/105600/nvidiav1" "${XDG_CACHE_HOME}/nvidia/terraria"
keep_nvidia "/steam/steamapps/shadercache/761890/nvidiav1" "${XDG_CACHE_HOME}/nvidia/albion"

# Stamp: tools must not rm -rf these trees.
printf 'protected\n' >"${shader_root}/.aurora-no-delete"
printf 'protected\n' >"${dxvk_root}/.aurora-no-delete"
printf 'protected\n' >"${XDG_CACHE_HOME}/nvidia/terraria/.aurora-no-delete"
printf 'protected\n' >"${XDG_CACHE_HOME}/nvidia/albion/.aurora-no-delete"

printf 'shader-protect: terraria+albion ok path=%s\n' "$shader_root"
exit 0
