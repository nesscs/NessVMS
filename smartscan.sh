#!/usr/bin/env bash
# smartscan.sh
# Run SMART short tests on all disks in parallel, show live progress, then PASS/FAIL per drive.

set -euo pipefail

# ===== Helpers =====
need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root (sudo)." >&2
    exit 2
  fi
}

ensure_smartctl() {
  if ! command -v smartctl >/dev/null 2>&1; then
    echo "smartctl not found. Installing smartmontools..."
    apt-get update -y && apt-get install -y smartmontools >/dev/null || {
      echo "Failed to install smartmontools. Install it manually and re-run." >&2
      exit 3
    }
  fi
}

normdev() { [[ "$1" == /* ]] && echo "$1" || echo "/dev/$1"; }

get_model() {
  local dev="$1" m
  m=$(smartctl -i "$dev" 2>/dev/null | awk -F: '/Model Family|Device Model|Product:|Model Number|Model/{print $2; exit}' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || true
  [[ -z "${m:-}" ]] && m=$(lsblk -dn -o MODEL "$dev" 2>/dev/null | sed 's/[[:space:]]*$//') || true
  echo "${m:-Unknown}"
}

draw_bar() {
  local pct="$1" width=40
  (( pct<0 )) && pct=0
  (( pct>100 )) && pct=100
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf "["
  printf "%0.s#" $(seq 1 "$filled")
  printf "%0.s-" $(seq 1 "$empty")
  printf "] %3d%%" "$pct"
}

parse_wait_secs() {
  # parse "Please wait N seconds" from smartctl output (fallback to 120s)
  local s
  s=$(grep -i "Please wait" | grep -oE '[0-9]+' | head -n1 || true)
  [[ -n "${s:-}" ]] && echo "$s" || echo 120
}

remaining_pct_from_smart() {
  # echo 0-100 completed (based on "xx% remaining"); empty if not visible
  local dev="$1" line rem
  line=$(smartctl -a "$dev" 2>/dev/null | grep -iE 'Self-test.+in progress|Self-test execution status|self-test routine is in progress' || true)
  rem=$(echo "$line" | grep -oE '[0-9]+%[[:space:]]*remaining' | head -n1 | grep -oE '^[0-9]+' || true)
  if [[ -n "${rem:-}" ]]; then
    echo $(( 100 - rem ))
  fi
}

overall_health_fail() {
  local dev="$1" oh
  oh=$(smartctl -H "$dev" 2>&1 || true)
  echo "$oh" | grep -qi "failed\|failing"
}

nvme_crit_warn() {
  local all="$1" c
  if echo "$all" | grep -qi "critical warning\|critical_warning"; then
    c=$(echo "$all" | grep -i -m1 "critical warning\|critical_warning" | grep -oE '[0-9]+' || true)
    [[ -n "$c" && "$c" != "0" ]] && { echo "NVMe Critical Warning=$c"; return 0; }
  fi
  return 1
}

attr_nonzero_flags() {
  local all="$1" reasons=() raw
  while IFS= read -r attr; do
    raw=$(echo "$all" | awk -v a="$attr" 'BEGIN{IGNORECASE=1} $0 ~ a {print $NF; exit}')
    if [[ -n "$raw" && "$raw" =~ ^[0-9]+$ && "$raw" -gt 0 ]]; then
      reasons+=("$attr=$raw")
    fi
  done < <(printf "%s\n" Reallocated_Sector_Ct Reallocated_Sector_Count Reallocated_Event_Count Current_Pending_Sector Current_Pending_Sectors Offline_Uncorrectable Offline_Uncorrectable_Sector)
  ((${#reasons[@]})) && { printf "%s" "$(IFS='; '; echo "${reasons[*]}")"; return 0; }
  return 1
}

last_selftest_status() {
  local dev="$1" log status
  log=$(smartctl -l selftest "$dev" 2>/dev/null || true)
  status=$(echo "$log" | awk 'BEGIN{IGNORECASE=1} /# 1/ || /Num  Test_Description/ {hdr=1} hdr && /Completed|Aborted|Interrupted|Fatal|read failure|unknown/ {print; exit}' || true)
  [[ -z "$status" ]] && status=$(smartctl -a "$dev" 2>/dev/null | grep -i "Self-test" | head -n1 || true)
  if echo "$status" | grep -iq "Completed without error"; then
    echo "Self-test: completed without error"
  elif echo "$status" | grep -iq "Completed"; then
    echo "Self-test: completed with issues"
  elif echo "$status" | grep -iq "Aborted"; then
    echo "Self-test: aborted"
  elif echo "$status" | grep -iq "read.*fail\|failure"; then
    echo "Self-test: read failure"
  elif [[ -n "$status" ]]; then
    echo "Self-test: $(echo "$status" | sed 's/^[[:space:]]*//')"
  fi
}

print_results_table() {
  printf "\n%-16s %-24s %-8s %s\n" "DEVICE" "MODEL" "RESULT" "REASON"
  printf "%s\n" "$@"
}

# ===== Main =====
need_root
ensure_smartctl

mapfile -t NAMES < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}')
((${#NAMES[@]})) || { echo "No block devices of type 'disk' found."; exit 0; }

# Build arrays
declare -a DEVS MODELS START_TS DURATION DONE
for i in "${!NAMES[@]}"; do
  DEVS[$i]=$(normdev "${NAMES[$i]}")
  MODELS[$i]=$(get_model "${DEVS[$i]}")
  DONE[$i]=0
  DURATION[$i]=120
done

echo "Starting SMART short self-tests on ${#DEVS[@]} disk(s) in parallel..."
echo

# Kick off all tests
for i in "${!DEVS[@]}"; do
  dev="${DEVS[$i]}"
  start_out=$(smartctl -t short "$dev" 2>&1 || true)
  START_TS[$i]=$(date +%s)
  # parse announced wait time if present
  DURATION[$i]=$(echo "$start_out" | parse_wait_secs)
  # Handle devices that don't support testing: mark as immediately "done" (we'll still evaluate health)
  if echo "$start_out" | grep -qi "Command not supported"; then
    DONE[$i]=2  # 2 = no self-test support
  fi
done

# Progress header
for i in "${!DEVS[@]}"; do
  printf "▶ %-12s (%s)\n" "${DEVS[$i]}" "${MODELS[$i]}"
done
# Allocate one progress line per device
for _ in "${!DEVS[@]}"; do echo "    [----------------------------------------]   0%"; done

# Live refresh loop
all_done=0
while (( ! all_done )); do
  # Move cursor up N progress lines to redraw in place
  printf "\033[%dA" "${#DEVS[@]}"
  all_done=1
  for i in "${!DEVS[@]}"; do
    dev="${DEVS[$i]}"
    if (( DONE[$i] == 1 )); then
      # already complete -> show 100%
      printf "    "
      draw_bar 100
      printf "  \n"
      continue
    fi
    if (( DONE[$i] == 2 )); then
      # not supported -> show NA
      printf "    [----------------------------------------]  N/A\n"
      continue
    fi

    # Try to read live % from SMART; otherwise estimate by elapsed/duration
    pct_live=$(remaining_pct_from_smart "$dev" || true)
    if [[ -n "${pct_live:-}" ]]; then
      pct="$pct_live"
    else
      now=$(date +%s)
      elapsed=$(( now - START_TS[$i] ))
      dur=${DURATION[$i]}
      (( dur < 30 )) && dur=30
      pct=$(( elapsed * 100 / dur ))
      (( pct > 99 )) && pct=99
    fi

    # Check completion: when smart no longer reports "remaining" AND elapsed >= duration
    if [[ -z "${pct_live:-}" ]]; then
      now=$(date +%s)
      elapsed=$(( now - START_TS[$i] ))
      if (( elapsed >= DURATION[$i] )); then
        DONE[$i]=1
        pct=100
      else
        all_done=0
      fi
    else
      (( pct >= 100 )) && DONE[$i]=1 || all_done=0
    fi

    printf "    "
    draw_bar "$pct"
    printf "  \n"
  done
  (( all_done )) || sleep 3
done

echo

# Summarize results
declare -a ROWS
any_fail=0
for i in "${!DEVS[@]}"; do
  dev="${DEVS[$i]}"; model="${MODELS[$i]}"
  allout=$(smartctl -a "$dev" 2>/dev/null || true)
  status="PASS"
  reasons=()

  if overall_health_fail "$dev"; then
    status="FAIL"; reasons+=("SMART overall-health failed")
  fi
  if r=$(nvme_crit_warn "$allout"); then
    status="FAIL"; reasons+=("$r")
  fi
  if r=$(attr_nonzero_flags "$allout"); then
    status="FAIL"; reasons+=("$r")
  fi

  stmsg=$(last_selftest_status "$dev")
  if [[ -n "${stmsg:-}" ]]; then
    if echo "$stmsg" | grep -iq "failure\|aborted\|with issues"; then status="FAIL"; fi
    reasons+=("$stmsg")
  else
    [[ ${DONE[$i]} -eq 2 ]] && reasons+=("Self-test not supported")
  fi

  [[ "$status" == "FAIL" ]] && any_fail=1
  ROWS+=("$(printf "%-16s %-24.24s %-8s %s" "$dev" "$model" "$status" "$(IFS='; '; echo "${reasons[*]:-SMART ok; self-test passed}")")")
done

print_results_table "${ROWS[@]}"

exit $any_fail
