#!/usr/bin/env bash
set -euo pipefail

real="${BRIGHTNESSCTL_REAL:-brightnessctl}"

if "$real" -c backlight info >/dev/null 2>&1; then
  exec "$real" -c backlight "$@"
fi

machine=0
action=""
value=""
for arg in "$@"; do
  case "$arg" in
    -m|--machine) machine=1 ;;
    set|info|-l|--list) action="$arg" ;;
    *) value="$arg" ;;
  esac
done

read_vcp() {
  ddcutil --brief --sleep-multiplier .2 getvcp 10 2>/dev/null | awk '/^VCP / { print $(NF-1), $NF; exit }'
}

print_machine() {
  local cur max pct
  read -r cur max <<<"$(read_vcp)"
  if [[ -z "${cur:-}" || -z "${max:-}" || "$max" -eq 0 ]]; then
    echo "ddc,backlight,0,0%,100"
    return 1
  fi
  pct=$((cur * 100 / max))
  echo "ddc,backlight,$cur,${pct}%,$max"
}

set_from_spec() {
  local spec=$1 cur max target n
  read -r cur max <<<"$(read_vcp)"
  if [[ -z "${cur:-}" || -z "${max:-}" || "$max" -eq 0 ]]; then
    echo "No DDC/CI backlight on this monitor" >&2
    return 1
  fi

  case "$spec" in
    +*% | +*)
      n=${spec#+}; n=${n%\%}
      target=$((cur + n * max / 100))
      ;;
    *%+)
      n=${spec%\%+}
      target=$((cur + n * max / 100))
      ;;
    *%-)
      n=${spec%\%-}
      target=$((cur - n * max / 100))
      ;;
    *%)
      n=${spec%\%}
      target=$((n * max / 100))
      ;;
    *)
      target=$spec
      ;;
  esac

  if ((target < 0)); then target=0; fi
  if ((target > max)); then target=$max; fi
  ddcutil --noverify --sleep-multiplier .2 setvcp 10 "$target" >/dev/null
}

case "$action" in
  set)
    set_from_spec "$value"
    ;;
  info|-l|--list)
    print_machine >/dev/null
    echo "Device 'ddc' of class 'backlight':"
    read -r cur max <<<"$(read_vcp)"
    echo "	Current brightness: ${cur:-0} ($(print_machine | cut -d, -f4))"
    echo "	Max brightness: ${max:-100}"
    ;;
esac

if [[ "$machine" -eq 1 ]]; then
  print_machine || true
fi
