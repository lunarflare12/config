#!/usr/bin/env bash
set -euo pipefail

light=0
[[ "${1:-}" == light ]] && light=1

read -r _ u n s i w x y z _ < /proc/stat
total=$((u + n + s + i + w + x + y + z))
idle=$((i + w))

mt=0
ma=0
st=0
sf=0
while read -r key value _; do
  case "$key" in
    MemTotal:) mt=$value ;;
    MemAvailable:) ma=$value ;;
    SwapTotal:) st=$value ;;
    SwapFree:) sf=$value ;;
  esac
done < /proc/meminfo

cpuTemp=0
for d in /sys/class/hwmon/hwmon*; do
  [[ -r "$d/name" ]] || continue
  n=$(<"$d/name")
  if [[ $n == k10temp && -r $d/temp1_input ]]; then
    cpuTemp=$(<"$d/temp1_input")
    break
  fi
done

if [[ $cpuTemp -eq 0 ]]; then
  for d in /sys/class/hwmon/hwmon*; do
    n=$(<"$d/name" 2>/dev/null || true)
    case "$n" in
      nvme | spd5118 | amdgpu) continue ;;
    esac
    if [[ -r $d/temp1_input ]]; then
      cpuTemp=$(<"$d/temp1_input")
      break
    fi
  done
fi
cpuTempC=$((cpuTemp / 1000))

read -r rx tx < <(awk 'NR > 2 { gsub(/:/, "", $1); if ($1 != "lo") { rx += $2; tx += $10 } } END { print rx + 0, tx + 0 }' /proc/net/dev)

gpuUtil=0
gpuTemp=-1
vramUsed=0
vramTotal=0
du=0
dt=0

if [[ $light -eq 0 ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    IFS=',' read -r gpuUtil gpuTemp vramUsed vramTotal <<<"$line"
    gpuUtil=${gpuUtil:-0}
    gpuTemp=${gpuTemp:--1}
    vramUsed=${vramUsed:-0}
    vramTotal=${vramTotal:-0}
  fi
  read -r du dt < <(df -B1 --output=used,size / 2>/dev/null | awk 'NR == 2 { print $1, $2 }')
  du=${du:-0}
  dt=${dt:-0}
fi

printf '%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s\n' \
  "$total" "$idle" "$mt" "$ma" "$cpuTempC" "$rx" "$tx" \
  "$gpuUtil" "$gpuTemp" "$vramUsed" "$vramTotal" "$st" "$sf" "$du" "$dt"
