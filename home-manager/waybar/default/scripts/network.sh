#!/usr/bin/env bash
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-mode"
CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-ip.json"
BW="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-bw.prev"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-ip.lock"

# фиксированная ширина блока (символы, моноширинный шрифт)
WIDTH=26

fmt_rate() {
  local b=$1
  if ((b < 1024)); then
    printf '%d B/s' "$b"
  elif ((b < 1048576)); then
    awk -v v="$b" 'BEGIN { printf "%.1f KB/s", v/1024 }'
  elif ((b < 1073741824)); then
    awk -v v="$b" 'BEGIN { printf "%.1f MB/s", v/1048576 }'
  else
    awk -v v="$b" 'BEGIN { printf "%.1f GB/s", v/1073741824 }'
  fi
}

pad_center() {
  local s=$1
  local len
  len=$(printf '%s' "$s" | wc -m | tr -d ' ')
  if ((len > WIDTH)); then
    s=$(printf '%s' "$s" | head -c "$WIDTH")
    len=$WIDTH
  fi
  local pad=$((WIDTH - len))
  local left=$((pad / 2))
  local right=$((pad - left))
  printf '%*s%s%*s' "$left" '' "$s" "$right" ''
}

default_iface() {
  local iface
  iface=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  if [[ -n "${iface:-}" ]]; then
    printf '%s' "$iface"
    return 0
  fi
  ip -o route get 1.1.1.1 2>/dev/null | awk '
    / dev / {
      for (i = 1; i <= NF; i++)
        if ($i == "dev") { print $(i + 1); exit }
    }'
}

read_counters() {
  awk -v d="$1:" '$0 ~ d {print $2, $10; exit}' /proc/net/dev
}

# без sleep: считаем скорость по разнице с прошлым замером
bandwidth_text() {
  local iface rx tx now prev_rx prev_tx prev_t dt drx dtx
  iface=$(default_iface) || return 1
  read -r rx tx < <(read_counters "$iface")
  now=$(date +%s)

  if [[ -f "$BW" ]]; then
    read -r prev_rx prev_tx prev_t <"$BW" || true
    dt=$((now - prev_t))
    if ((dt > 0)); then
      drx=$(( (rx - prev_rx) / dt ))
      dtx=$(( (tx - prev_tx) / dt ))
      ((drx < 0)) && drx=0
      ((dtx < 0)) && dtx=0
      printf '%s' "$(pad_center "󰓅 $(fmt_rate "$drx") 󰓆 $(fmt_rate "$dtx")")"
      printf '%s %s %s\n' "$rx" "$tx" "$now" >"$BW"
      return 0
    fi
  fi

  printf '%s %s %s\n' "$rx" "$tx" "$now" >"$BW"
  pad_center "󰓅 0 B/s  󰓆 0 B/s"
}

interface_text() {
  local iface ip cidr raw
  iface=$(default_iface) || return 1
  cidr=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4; exit}')
  ip=${cidr%%/*}

  if [[ -n "${ip:-}" ]]; then
    raw="${iface} · ${ip}"
  else
    raw="${iface}"
  fi

  # если длинно — только имя интерфейса (главное чтобы оно было видно)
  if (($(printf '%s' "$raw" | wc -m) > WIDTH - 2)); then
    raw="${iface}"
  fi

  pad_center "󰈀 ${raw}"
}

fetch_public_ip_bg() {
  [[ -f "$LOCK" ]] && return 0
  touch "$LOCK"
  (
    local iface ip_now
    iface=$(default_iface 2>/dev/null || echo "?")
    if resp=$(curl -sf --max-time 3 https://api.ipify.org); then
      jq -cn --arg ip "$resp" --arg iface "$iface" --argjson ts "$(date +%s)" \
        '{ts: $ts, ip: $ip, iface: $iface}' >"$CACHE"
    fi
    rm -f "$LOCK"
  ) &
}

public_text() {
  local now ts ip iface raw
  now=$(date +%s)
  iface=$(default_iface 2>/dev/null || echo "?")

  if [[ -f "$CACHE" ]]; then
    ts=$(jq -r '.ts // 0' "$CACHE" 2>/dev/null || echo 0)
    ip=$(jq -r '.ip // empty' "$CACHE" 2>/dev/null || true)
    iface=$(jq -r '.iface // empty' "$CACHE" 2>/dev/null || echo "$iface")
    [[ -z "$iface" || "$iface" == "?" ]] && iface=$(default_iface 2>/dev/null || echo "?")

    if [[ -n "${ip:-}" ]]; then
      raw="${iface} · ${ip}"
      if (($(printf '%s' "$raw" | wc -m) > WIDTH - 2)); then
        raw="${iface}"
      fi
      pad_center "$raw"
      if ((now - ts > 3600)); then
        fetch_public_ip_bg
      fi
      return 0
    fi
  fi

  fetch_public_ip_bg
  pad_center "…"
}

mode=$(cat "$STATE" 2>/dev/null || echo 0)

if [[ "${1:-}" == "next" ]]; then
  echo $(( (mode + 1) % 3 )) >"$STATE"
  exit 0
fi

# один раз при старте сессии — подтянуть IP в фоне
if [[ ! -f "$CACHE" ]]; then
  fetch_public_ip_bg
fi

class=connected
text=""
tooltip=""

case "$mode" in
  0)
    if text=$(bandwidth_text); then
      tooltip="Скорость · клик: интерфейс"
    else
      text=$(pad_center "󰤭 Offline")
      class=disconnected
      tooltip="Нет сети"
    fi
    ;;
  1)
    if text=$(interface_text); then
      tooltip="Интерфейс · клик: публичный IP"
    else
      text=$(pad_center "󰤭 Offline")
      class=disconnected
      tooltip="Нет сети"
    fi
    ;;
  2)
    text=$(public_text)
    tooltip="Публичный IP · клик: скорость"
    ;;
esac

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
