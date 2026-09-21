#!/usr/bin/env bash
# Keep the Amnezia/WireGuard server reachable when AllowedIPs is a split
# prefix like 0.0.0.0/2 instead of 0.0.0.0/0. awg-quick only installs the
# fwmark exception for /0, so the endpoint otherwise blackholes into the
# tunnel and the handshake never completes.
set -u
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-dd}/bin:${PATH:-}"

action="${1:-}"
iface="${2:-}"
if [[ -z $action || -z $iface || ! $iface =~ ^[A-Za-z0-9_=+.-]{1,15}$ ]]; then
  echo "usage: awg-protect-endpoint.sh up|down IFACE" >&2
  exit 2
fi

state_dir=/run/aurora
state="$state_dir/awg-endpoint.$iface"

endpoint_from_conf() {
  local conf line value
  for conf in "/etc/amnesia/${iface}.conf" "/etc/amnezia/${iface}.conf" "/etc/wireguard/${iface}.conf"; do
    [[ -f $conf ]] || continue
    line=$(grep -E '^[[:space:]]*Endpoint[[:space:]]*=' "$conf" | tail -n1) || true
    [[ -n ${line:-} ]] || continue
    value="${line#*=}"
    value="${value//[[:space:]]/}"
    value="${value%%#*}"
    [[ -n $value ]] || continue
    printf '%s\n' "$value"
    return 0
  done
  return 1
}

host_of_endpoint() {
  local ep=$1
  if [[ $ep == \[*\]:* ]]; then
    ep="${ep#*[}"
    printf '%s\n' "${ep%]*}"
    return
  fi
  printf '%s\n' "${ep%:*}"
}

ipv4_of() {
  getent ahostsv4 "$1" | awk '{ print $1; exit }'
}

route_parts() {
  ip -4 route get "$1" 2>/dev/null | awk '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == "via") via = $(i + 1)
        if ($i == "dev") dev = $(i + 1)
      }
      print via, dev
    }
  '
}

apply_host_route() {
  local ipaddr=$1 via=$2 dev=$3
  [[ -n $ipaddr && -n $dev ]] || return 0
  if [[ -n $via ]]; then
    ip route replace "$ipaddr/32" via "$via" dev "$dev"
  else
    ip route replace "$ipaddr/32" dev "$dev"
  fi
}

case "$action" in
  up)
    mkdir -p "$state_dir" 2>/dev/null || true
    if [[ -f $state ]]; then
      saved_ip="" saved_via="" saved_dev=""
      read -r saved_ip a b c d <"$state" || true
      if [[ ${a:-} == via ]]; then
        saved_via=$b
        saved_dev=$d
      elif [[ ${a:-} == dev ]]; then
        saved_dev=$b
      fi
      apply_host_route "$saved_ip" "$saved_via" "$saved_dev"
      exit 0
    fi
    ep=$(endpoint_from_conf) || exit 0
    host=$(host_of_endpoint "$ep")
    ipaddr=$(ipv4_of "$host")
    [[ -n ${ipaddr:-} ]] || exit 0
    read -r via dev _ <<<"$(route_parts "$ipaddr")"
    [[ -n ${dev:-} ]] || exit 0
    [[ $dev == "$iface" ]] && exit 0
    apply_host_route "$ipaddr" "$via" "$dev"
    if [[ -n ${via:-} ]]; then
      printf '%s via %s dev %s\n' "$ipaddr" "$via" "$dev" >"$state"
    else
      printf '%s dev %s\n' "$ipaddr" "$dev" >"$state"
    fi
    ;;
  down)
    ipaddr=""
    if [[ -f $state ]]; then
      read -r ipaddr _ <"$state" || true
      rm -f "$state"
    fi
    if [[ -z ${ipaddr:-} ]]; then
      ep=$(endpoint_from_conf) || exit 0
      ipaddr=$(ipv4_of "$(host_of_endpoint "$ep")")
    fi
    [[ -n ${ipaddr:-} ]] || exit 0
    ip route del "$ipaddr/32" 2>/dev/null || true
    ;;
  *)
    echo "usage: awg-protect-endpoint.sh up|down IFACE" >&2
    exit 2
    ;;
esac
