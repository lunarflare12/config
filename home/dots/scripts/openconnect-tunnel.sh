#!/usr/bin/env bash
# Interactive SoftServe / AnyConnect tunnel via openconnect.
# Usage: openconnect-tunnel.sh up|down NAME
# Config: /etc/openconnect/NAME.conf or ~/.config/openconnect/NAME.conf
set -eu
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-dd}/bin:${PATH:-}"

action="${1:-}"
name="${2:-}"
if [[ -z $action || -z $name || ! $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
  echo "usage: openconnect-tunnel.sh up|down NAME" >&2
  exit 2
fi

run_dir=/run/aurora-openconnect
pid_file="$run_dir/${name}.pid"
state_file="$run_dir/${name}.bypass"

find_conf() {
  local c
  for c in "/etc/openconnect/${name}.conf" "${HOME:-/home/dd}/.config/openconnect/${name}.conf"; do
    if [[ -f $c ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

read_kv() {
  # shellcheck disable=SC2034
  local key=$1 file=$2
  awk -v k="$key" '
    BEGIN { IGNORECASE=1 }
    /^[[:space:]]*#/ { next }
    NF == 0 { next }
    {
      line=$0
      sub(/#.*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") next
      split(line, a, /[[:space:]]*=[[:space:]]*|[[:space:]]+/)
      if (tolower(a[1]) == tolower(k)) {
        sub(/^[^[:space:]=]+[[:space:]]*=?[[:space:]]*/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

lan_gw() {
  ip -4 route show default 2>/dev/null | awk '
    /dev en/ { print $3; exit }
    /dev eth/ { print $3; exit }
    { print $3; exit }
  '
}

lan_dev() {
  ip -4 route show default 2>/dev/null | awk '
    {
      for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i+1); exit }
    }
  '
}

apply_bypass() {
  local host gw dev
  gw=$(lan_gw)
  dev=$(lan_dev)
  [[ -n ${gw:-} && -n ${dev:-} ]] || return 0
  : >"$state_file"
  for host in "$@"; do
    [[ $host =~ ^[0-9.]+$ ]] || continue
    if ip route replace "$host/32" via "$gw" dev "$dev"; then
      printf '%s\n' "$host" >>"$state_file"
    fi
  done
}

clear_bypass() {
  local host
  [[ -f $state_file ]] || return 0
  while read -r host; do
    [[ $host =~ ^[0-9.]+$ ]] || continue
    ip route del "$host/32" 2>/dev/null || true
  done <"$state_file"
  rm -f "$state_file"
}

alive_pid() {
  local pid
  [[ -f $pid_file ]] || return 1
  pid=$(tr -d '[:space:]' <"$pid_file" || true)
  [[ -n ${pid:-} && -d /proc/$pid ]] || return 1
  tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q openconnect
}

kill_tunnel() {
  local pid
  if alive_pid; then
    pid=$(tr -d '[:space:]' <"$pid_file")
    kill "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
  clear_bypass
  # Drop leftover named tun if still around.
  local iface
  iface=$(read_kv interface "$conf" 2>/dev/null || true)
  [[ -n ${iface:-} ]] && ip link delete "$iface" 2>/dev/null || true
}

conf=$(find_conf) || {
  echo "openconnect config not found for $name" >&2
  exit 1
}

mkdir -p "$run_dir"

case $action in
  down)
    kill_tunnel
    echo "openconnect $name down"
    exit 0
    ;;
  up)
    if alive_pid; then
      echo "openconnect $name already up (pid $(tr -d '[:space:]' <"$pid_file"))"
      exit 0
    fi
    url=$(read_kv url "$conf")
    user=$(read_kv user "$conf")
    protocol=$(read_kv protocol "$conf")
    iface=$(read_kv interface "$conf")
    bypass=$(read_kv bypass "$conf")
    protocol=${protocol:-anyconnect}
    iface=${iface:-$name}
    [[ -n $url ]] || {
      echo "url missing in $conf" >&2
      exit 1
    }

    # SoftServe (and similar) break TLS when routed through Amnezia split tunnels.
    if [[ -n ${bypass:-} ]]; then
      # shellcheck disable=SC2086
      apply_bypass $bypass
    fi

    args=(
      openconnect
      --protocol="$protocol"
      --interface="$iface"
      --pid-file="$pid_file"
    )
    [[ -n ${user:-} ]] && args+=(--user="$user")
    args+=("$url")

    echo "Connecting $name → $url (password + MFA in this terminal)"
    echo "Ctrl+C disconnects."
    exec "${args[@]}"
    ;;
  *)
    echo "usage: openconnect-tunnel.sh up|down NAME" >&2
    exit 2
    ;;
esac
