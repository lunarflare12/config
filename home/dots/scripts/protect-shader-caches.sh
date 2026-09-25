#!/usr/bin/env bash
# Keep Steam / DXVK / NVIDIA shader caches on durable /home storage.
# Never delete cache trees. Never replace a larger cache with a smaller one.
set -euo pipefail

HOME="${HOME:-/home/dd}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

shader_root="${XDG_CACHE_HOME}/steam-shadercache"
dxvk_root="${XDG_CACHE_HOME}/dxvk"
ow_dxvk="${dxvk_root}/overwatch"
ow_dxvk_file="${ow_dxvk}/Overwatch.dxvk-cache"
ow_nv="${shader_root}/2357570/nvidiav1"
# Durable mirror only. The live NVIDIA path is steam-shadercache (bind).
ow_nv_keep="${XDG_CACHE_HOME}/nvidia/overwatch"
ow_pfx_dxvk="/steam/steamapps/compatdata/2357570/pfx/drive_c/users/steamuser/AppData/Local/dxvk"
ow_pfx_file="${ow_pfx_dxvk}/Overwatch.dxvk-cache"
steam_nv="/steam/steamapps/shadercache/2357570/nvidiav1"

mkdir -p "$shader_root" "$dxvk_root" "$ow_dxvk" "$ow_nv" "$ow_nv_keep" "$ow_pfx_dxvk" \
  "$shader_root/2357570" "$shader_root/761890" "$shader_root/105600"

chmod u+rwx "$shader_root" "$dxvk_root" 2>/dev/null || true

# Copy src → dst only when src exists and is strictly larger (or dst missing).
promote_larger() {
  local src=$1 dst=$2
  local sb db
  [ -f "$src" ] || return 0
  if [ ! -f "$dst" ]; then
    cp -a "$src" "$dst" || true
    return 0
  fi
  sb=$(wc -c <"$src" 2>/dev/null || echo 0)
  db=$(wc -c <"$dst" 2>/dev/null || echo 0)
  if [ "${sb:-0}" -gt "${db:-0}" ]; then
    cp -a "$src" "$dst" || true
  fi
}

# Home is canonical. Never hardlink into the prefix: DXVK writes a 51-byte
# stub there on boot and that would truncate the real cache.
sync_dxvk_hardlink() {
  promote_larger "$ow_pfx_file" "$ow_dxvk_file"
  # Drop prefix stubs so Proton does not pick the empty file.
  if [ -f "$ow_pfx_file" ]; then
    local psz
    psz=$(wc -c <"$ow_pfx_file" 2>/dev/null || echo 0)
    if [ "${psz:-0}" -lt 4096 ]; then
      rm -f "$ow_pfx_file"
    fi
  fi
  [ -f "$ow_dxvk_file" ] || return 0
}

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
keep_nvidia() {
  local src=$1 dest_root=$2
  [ -d "$src" ] || return 0
  mkdir -p "$dest_root"
  printf 'frozen\n' >"${dest_root}/.frozen"
  printf 'protected\n' >"${dest_root}/.aurora-no-delete"
  local f rel dst
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    dst="${dest_root}/${rel}"
    link_larger "$f" "$dst"
  done < <(find "$src" -type f -print0 2>/dev/null)
}

# NVIDIA GLCache lives under ~/.cache and is bind-mounted at
# /steam/steamapps/shadercache — same directory. Never wipe it; only
# seed an empty home tree from steam if somehow empty (should be rare).
seed_nvidia_if_empty() {
  if [ -d "$ow_nv/GLCache" ]; then
    return 0
  fi
  if [ -d "$steam_nv/GLCache" ] && ! [ "$ow_nv" -ef "$steam_nv" ]; then
    cp -a "$steam_nv/." "$ow_nv/" || true
  fi
}

dxvk_magic_ok() {
  local f=$1
  [ -f "$f" ] || return 1
  # DXVK state cache magic "DXVK" + version u32
  head -c 4 "$f" 2>/dev/null | grep -q '^DXVK$' || return 1
  # Reject empty/tiny stubs
  local sz
  sz=$(wc -c <"$f" 2>/dev/null || echo 0)
  [ "${sz:-0}" -ge 4096 ]
}

nvidia_cache_ok() {
  local root merged sz f
  for root in "$ow_nv_keep" "$ow_nv"; do
    [ -d "$root/GLCache" ] || continue
    merged=""
    for f in "$root"/GLCache/*/*/steamapp_merged_shader_cache.bin \
             "$root"/GLCache/*/*/steamapp_shader_cache1.bin \
             "$root"/GLCache/*/*/steamapp_shader_cache0.bin; do
      [ -f "$f" ] || continue
      sz=$(wc -c <"$f" 2>/dev/null || echo 0)
      # Real OW cache is multi-GB; <64MiB means wiped/corrupt stub.
      if [ "${sz:-0}" -ge 67108864 ]; then
        return 0
      fi
    done
  done
  return 1
}

sync_dxvk_hardlink
seed_nvidia_if_empty
keep_nvidia "$ow_nv" "$ow_nv_keep"
if [ -d "$steam_nv" ] && ! [ "$steam_nv" -ef "$ow_nv" ]; then
  keep_nvidia "$steam_nv" "$ow_nv_keep"
fi
# Same rule for the other boxes. Their bins must not be replaced either.
keep_nvidia "${shader_root}/105600/nvidiav1" "${XDG_CACHE_HOME}/nvidia/terraria"
keep_nvidia "${shader_root}/761890/nvidiav1" "${XDG_CACHE_HOME}/nvidia/albion"
keep_nvidia "/steam/steamapps/shadercache/105600/nvidiav1" "${XDG_CACHE_HOME}/nvidia/terraria"
keep_nvidia "/steam/steamapps/shadercache/761890/nvidiav1" "${XDG_CACHE_HOME}/nvidia/albion"

# Stamp: tools must not rm -rf these trees.
printf 'protected\n' >"${shader_root}/.aurora-no-delete"
printf 'protected\n' >"${dxvk_root}/.aurora-no-delete"
printf 'protected\n' >"${ow_nv}/.aurora-no-delete"
printf 'protected\n' >"${ow_nv_keep}/.aurora-no-delete"
printf 'protected\n' >"${XDG_CACHE_HOME}/nvidia/terraria/.aurora-no-delete"
printf 'protected\n' >"${XDG_CACHE_HOME}/nvidia/albion/.aurora-no-delete"

nv_bytes=0
if [ -d "$ow_nv" ]; then
  nv_bytes=$(du -sb "$ow_nv" 2>/dev/null | awk '{print $1}')
fi
dxvk_bytes=0
if [ -f "$ow_dxvk_file" ]; then
  dxvk_bytes=$(wc -c <"$ow_dxvk_file")
fi

nv_ok=0
dxvk_ok=0
nvidia_cache_ok && nv_ok=1
dxvk_magic_ok "$ow_dxvk_file" && dxvk_ok=1

printf 'shader-protect: nvidia=%s ok=%s dxvk=%s ok=%s link=%s path=%s\n' \
  "${nv_bytes:-0}" "$nv_ok" "${dxvk_bytes:-0}" "$dxvk_ok" \
  "$(if [ -e "$ow_pfx_file" ] && [ -f "$ow_dxvk_file" ]; then
       if [ -L "$ow_pfx_file" ]; then echo sym
       elif [ "$ow_dxvk_file" -ef "$ow_pfx_file" ]; then echo hard
       else echo copy
       fi
     else echo missing
     fi)" \
  "$shader_root"

# Non-zero if caches look wiped — caller may warn; do not delete anything.
if [ "$nv_ok" -ne 1 ] || [ "$dxvk_ok" -ne 1 ]; then
  exit 2
fi
exit 0
