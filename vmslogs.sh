#!/usr/bin/env bash
# vmslogs.sh - Summarise restart/power events with timestamp and reason (Ubuntu 18–24)
# Hosted at: https://nesscs.com/vmslogs
#
# Quick run (no install):
#   sudo wget -qO- https://nesscs.com/vmslogs | sudo bash
#
# With options (example: look back 7 days with debug enabled):
#   sudo wget -qO- https://nesscs.com/vmslogs | sudo bash -s -- --since 7days --debug
#
# Options:
#   --since <timespec>   e.g. 7days, "2025-01-01"
#   --until <timespec>   end of window
#   --debug              write detailed journal snippets to /var/log/vmslogs-debug.log
#   --help               show this usage message

set -euo pipefail
export LC_ALL=C

# ---- Configurable look-back/around windows ----
# (widened a bit to catch slow/late shutdown logs)
AROUND_BEFORE_MIN=${AROUND_BEFORE_MIN:-20}
AROUND_AFTER_MIN=${AROUND_AFTER_MIN:-10}
OOM_LOOKBACK_MIN=${OOM_LOOKBACK_MIN:-60}

SINCE=""
UNTIL=""
DEBUG=0
DEBUG_LOG="/var/log/vmslogs-debug.log"

show_help() {
  cat <<EOF
Usage:
  sudo wget -qO- https://nesscs.com/vmslogs | sudo bash -s -- [options]

Options:
  --since <timespec>   e.g. 7days, "2025-01-01"
  --until <timespec>   end of window
  --debug              write detailed journal snippets to $DEBUG_LOG
  --help               show this message

Examples:
  sudo wget -qO- https://nesscs.com/vmslogs | sudo bash
  sudo wget -qO- https://nesscs.com/vmslogs | sudo bash -s -- --since 7days --debug
EOF
}

# If running in a pipe (wget|bash or curl|bash), print a hint
if [[ -t 1 && -p /dev/stdin ]]; then
  echo "# Running vmslogs.sh from stream"
  echo "# Tip: use --help for usage info"
  echo
fi

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) shift; SINCE="${1:-}";;
    --until) shift; UNTIL="${1:-}";;
    --debug) DEBUG=1;;
    --help) show_help; exit 0;;
    *) echo "Unknown arg: $1"; echo "Use --help for usage."; exit 1;;
  esac
  shift || true
done

# --- Helpers / prerequisites ---
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
require_cmd last
require_cmd awk
require_cmd date

JOURNALCTL_OK=1
if ! command -v journalctl >/dev/null 2>&1; then
  JOURNALCTL_OK=0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo) so journal entries are accessible." >&2
  exit 1
fi

# Prepare debug log if needed
if [[ $DEBUG -eq 1 ]]; then
  mkdir -p "$(dirname "$DEBUG_LOG")"
  {
    echo "========== vmslogs run $(date '+%Y-%m-%d %H:%M:%S') =========="
  } >>"$DEBUG_LOG"
fi

# Warn if persistent journal is not enabled
if [[ $JOURNALCTL_OK -eq 1 && ! -d /var/log/journal ]]; then
  echo "# Note: /var/log/journal is missing (journal not persistent)."
  echo "# You may only see current-boot details."
fi

# --- Time helpers (epoch-safe) ---
to_iso() { date -d "$1" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$1"; }
to_epoch() { date -d "$1" +%s 2>/dev/null || echo 0; }
epoch_to_iso() { date -d "@$1" +"%Y-%m-%d %H:%M:%S"; }
shift_minutes() {
  local base_ts; base_ts=$(to_epoch "$1")
  local delta_sec=$(( $2 * 60 ))
  local new_ts=$(( base_ts + delta_sec ))
  epoch_to_iso "$new_ts"
}

within_bounds() {
  local t_iso="$1"
  if [[ -n "$SINCE" ]]; then
    local s; s=$(date -d "$SINCE" +%s 2>/dev/null || echo 0)
    local ts; ts=$(to_epoch "$t_iso")
    (( ts < s )) && return 1
  fi
  if [[ -n "$UNTIL" ]]; then
    local u; u=$(date -d "$UNTIL" +%s 2>/dev/null || echo 32503680000)
    local ts; ts=$(to_epoch "$t_iso")
    (( ts > u )) && return 1
  fi
  return 0
}

log_debug() {
  if [[ $DEBUG -eq 1 ]]; then
    echo "$@" >>"$DEBUG_LOG"
  fi
}

# --- Classification using journalctl + fallbacks ---
journal_reason() {
  local t_iso="$1"       # "YYYY-MM-DD HH:MM:SS"
  local event_type="$2"  # reboot|shutdown

  local start_win end_win start_oom
  start_win=$(shift_minutes "$t_iso" $((-AROUND_BEFORE_MIN)))
  end_win=$(shift_minutes "$t_iso" $((AROUND_AFTER_MIN)))
  start_oom=$(shift_minutes "$t_iso" $((-OOM_LOOKBACK_MIN)))

  if [[ $JOURNALCTL_OK -ne 1 ]]; then
    echo "unknown"
    return 0
  fi

  local J
  J="$(journalctl -o short-iso --no-pager --since "$start_win" --until "$end_win" 2>/dev/null || true)"

  # --- Clean shutdown/reboot (cover Ubuntu 18–24 variants) ---
  if grep -Eiq 'systemd-shutdown\[[0-9]+\]: (Powering down\.|Rebooting\.)' <<<"$J"; then
    log_debug "[$t_iso] matched systemd-shutdown final line"
    [[ "$event_type" == "shutdown" ]] && echo "clean poweroff" || echo "clean reboot"
    return 0
  fi
  if grep -Eiq 'systemd-logind\[[0-9]+\]: (System is powering down|Power key pressed|Power Button)' <<<"$J"; then
    log_debug "[$t_iso] matched logind powerdown/button"
    [[ "$event_type" == "shutdown" ]] && echo "clean poweroff" || echo "clean reboot"
    return 0
  fi
  if grep -Eiq 'systemd\[1\]: (Starting Power-Off|Reached target Shutdown|Shutting down\.)' <<<"$J"; then
    log_debug "[$t_iso] matched systemd power-off/target/shutting down"
    [[ "$event_type" == "shutdown" ]] && echo "clean poweroff" || echo "clean reboot"
    return 0
  fi
  if grep -Eiq '\breboot: (Power down|Restarting system)\b' <<<"$J"; then
    log_debug "[$t_iso] matched kernel reboot/power down line"
    [[ "$event_type" == "shutdown" ]] && echo "clean poweroff" || echo "clean reboot"
    return 0
  fi

  # --- Operator/UPS/fault signatures ---
  if grep -Eiq '(apcupsd|apcdaemon|upsmon|nut)\[.*\].*(on battery|LOWBATT|shutdown|power off)' <<<"$J"; then
    log_debug "[$t_iso] UPS initiated shutdown"
    echo "UPS initiated"; return 0
  fi
  if grep -Eiq 'Kernel panic|panic:|Oops:|BUG: unable to handle kernel' <<<"$J"; then
    log_debug "[$t_iso] kernel panic/oops"
    echo "kernel panic"; return 0
  fi
  if grep -Eiq 'watchdog.*(hard LOCKUP|reboot|NMI watchdog)' <<<"$J"; then
    log_debug "[$t_iso] watchdog reset"
    echo "watchdog reset"; return 0
  fi
  if grep -Eiq '(Thermal|thermal).* (critical|overheat|overheated|shutdown)' <<<"$J"; then
    log_debug "[$t_iso] thermal protection"
    echo "thermal protection"; return 0
  fi

  # --- OOM earlier can precede reset ---
  local JOOM
  JOOM="$(journalctl -o short-iso --no-pager --since "$start_oom" --until "$end_win" 2>/dev/null || true)"
  if grep -Eiq 'Out of memory: Killed process' <<<"$JOOM"; then
    log_debug "[$t_iso] out-of-memory event before shutdown"
    echo "out-of-memory"; return 0
  fi

  # --- Filesystem recovery implies prior unclean shutdown ---
  if grep -Eiq 'EXT4-fs .*recovering journal|xfslog.*Mounting|dirty log' <<<"$J"; then
    log_debug "[$t_iso] filesystem recovery suggests prior unclean shutdown"
    echo "unclean shutdown (likely power loss)"; return 0
  fi

  # --- Fallbacks when journal lacks clean signatures ---
  # If this event is a reboot and there was a shutdown shortly before, assume clean.
  if [[ "$event_type" == "reboot" ]]; then
    local t_epoch prev_epoch
    t_epoch=$(to_epoch "$t_iso")
    prev_epoch=$(to_epoch "$(shift_minutes "$t_iso" -20)")
    if last -xF | awk -v start="$prev_epoch" -v end="$t_epoch" '
        tolower($1)=="shutdown" {
          n=NF; year=$(n); time=$(n-1); day=$(n-2); mon=$(n-3); dow=$(n-4);
          gsub(/,/, "", dow); gsub(/,/, "", mon); gsub(/,/, "", day); gsub(/,/, "", time); gsub(/,/, "", year);
          cmd="date -d \""dow" "mon" "day" "time" "year"\" +%s"; cmd | getline se; close(cmd);
          if (se>=start && se<=end) { print "HIT"; exit }
        }' | grep -q HIT; then
      log_debug "[$t_iso] fallback: found recent 'shutdown' in last -x"
      echo "clean reboot (fallback via last)"; return 0
    fi
  fi

  # If this event is a shutdown entry from last(1), trust it as clean.
  if [[ "$event_type" == "shutdown" ]]; then
    log_debug "[$t_iso] fallback: trusting 'shutdown' event from last -x"
    echo "clean poweroff (fallback via last)"; return 0
  fi

  # No match
  log_debug "[$t_iso] no signature matched; journal window below:"
  log_debug "$J"
  echo "unknown"
}

# --- Build list of events from `last -xF`, oldest -> newest ---
mapfile -t EVENTS < <(
  last -xF \
  | awk '
      BEGIN { OFS="|" }
      tolower($1) ~ /^(reboot|shutdown)$/ {
        n = NF
        year = $(n)
        time = $(n-1)
        day  = $(n-2)
        mon  = $(n-3)
        dow  = $(n-4)
        gsub(/,/, "", dow); gsub(/,/, "", mon); gsub(/,/, "", day); gsub(/,/, "", time); gsub(/,/, "", year)
        start = dow" "mon" "day" "time" "year
        printf "%s|%s\n", tolower($1), start
      }
    ' \
  | tac
)

# --- Output ---
for line in "${EVENTS[@]}"; do
  IFS='|' read -r etype start_raw <<<"$line"
  t_iso="$(to_iso "$start_raw")"
  within_bounds "$t_iso" || continue
  reason="$(journal_reason "$t_iso" "$etype")"
  printf "%s  %s\n" "$t_iso" "$reason"
done

if [[ $DEBUG -eq 1 ]]; then
  echo "# Debug output written to $DEBUG_LOG"
fi
