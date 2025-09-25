#!/usr/bin/env bash
# smartscan.sh
# Run SMART short tests on all disks in parallel with robust waits + retries, show live progress, then PASS/FAIL.
#
# wget -O - https://nesscs.com/smartscan | sudo bash

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

# Parse "Short self-test routine recommended polling time: N minutes."
capability_poll_secs() {
  local dev="$1" mins
  mins=$(smartctl -c "$dev" 2>/dev/null | awk -F: 'BEGIN{IGNORECASE=1} /Short self-test.*polling time/ {gsub(/[^0-9]/,"",$2); print $2; exit}' || true)
  if [[ -n "${mins:-}" ]]; then
    echo $(( mins * 60 ))
    return
  fi
  # NVMe often doesn’t report; default 2 min
  echo 120
}

# Extract announced wait from "-t short" output if present
start_wait_secs_from_text() {
  local text="$1" s
  s=$(echo "$text" | grep -i "Please wait" | grep -oE '[0-9]+' | head -n1 || true)
  [[ -n "${s:-}" ]] && echo "$s" || echo ""
}

# Detect if a short self-test is currently in progress. Echo completed% (0-100) or empty if not in progress.
completed_pct_if_in_progress() {
  local dev="$1" out rem
  out=$(smartctl -a "$dev" 2>/dev/null || true)

  # Common phrasings:
  # - "Self-test routine in progress... xx% remaining"
  # - "Self-test execution status: ... xx% of test remaining"
  # - "Background short self test in progress ... xx% remaining"
  rem=$(echo "$out" | grep -iE 'Self-?test.*(in progress|execution status)|xx% remaining' \
        | grep -oE '[0-9]+%[[:space:]]*remaining' | head -n1 | grep -oE '^[0-9]+' || true)
  if [[ -n "${rem:-}" ]]; then
    echo $(( 100 - rem ))
    return
  fi
  # Some firmwares report a code in "Self-test execution status: (nn)". If != 0x00, treat as in-progress.
  if echo "$out" | grep -qi 'Self-test execution status'; then
    local code
    code=$(echo "$out" | sed -n 's/.*Self-test execution status:[^0-9]*\([0-9][0-9]*\).*/\1/ip;q' | head -n1 | tr -d '[:space:]' || true)
    if [[ -n "${code:-}" && "$code" != "0" ]]; then
      echo 5  # unknown progress; show minimal movement
      return
    fi
  fi
  # Not in progress
  echo ""
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

# Attempt to start a short test with retries and auto device-type hint
start_short_test_robust() {
  local dev="$1" args=() out rc=0
  # Ensure SMART is enabled (ATA/SATA)
  smartctl -s on "$dev" >/dev/null 2>&1 || true

  # If a test is already running, don't reissue, just return OK with message
  if [[ -n "$(completed_pct_if_in_progress "$dev")" ]]; then
    echo "Test already in progress"
    return 0
  fi

  out=$(smartctl -t short "${args[@]}" "$dev" 2>&1) || rc=$?
  if (( rc != 0 )); then
    # Retry with -d sat if it asks for device type (common on USB/SATA bridges)
    if echo "$out" | grep -qi "Please specify device type with the -d option"; then
      out=$(smartctl -d sat -t short "$dev" 2>&1) || rc=$?
      if (( rc == 0 )); then
        echo "$out"
        return 0
      fi
    fi
    # If it says "Background short self test in progress", treat as success (already running)
    if echo "$out" | grep -qi "self test.*in progress"; then
      echo "$out"
      return 0
    fi
    # Some devices require waking; a second try may succeed
    sleep 2
    out2=$(smartctl -t short "$dev" 2>&1) || true
    echo "$out$'\n'$out2"
    return 0
  fi
  echo "$out"
  return 0
}

print_results_table() {
  printf "\n%-16s %-24s %-10s %s\n" "DEVICE" "MODEL" "RESULT" "REASON"
  printf "%s\n" "$@"
}

# ===== Main =====
need_root
ensure_smartctl

mapfile -t NAMES < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}')
((${#NAMES[@]})) || { echo "No block devices of type 'disk' found."; exit 0; }

declare -a DEVS MODELS START_TS DURATION CUSHION DONE TIMEOUT REASON_START
for i in "${!NAMES[@]}"; do
  DEVS[$i]=$(normdev "${NAMES[$i]}")
  MODELS[$i]=$(get_model "${DEVS[$i]}")
  DONE[$i]=0        # 0=running,1=done,2=unsupported,3=timeout
  TIMEOUT[$i]=0
done

echo "Starting SMART short self-tests on ${#DEVS[@]} disk(s) in parallel..."
echo

# Kick off + compute expected durations with cushion
for i in "${!DEVS[@]}"; do
  dev="${DEVS[$i]}"
  start_text=$(start_short_test_robust "$dev")
  START_TS[$i]=$(date +%s)

  # Prefer capability polling time
  cap_secs=$(capability_poll_secs "$dev")
  # If start output had "Please wait N seconds", prefer that
  start_secs=$(start_wait_secs_from_text "$start_text")
  [[ -n "$start_secs" ]] && cap_secs="$start_secs"

  # Cushion: 1.5x + 60s (handles slow/USB/SMR)
  CUSHION[$i]=$(( cap_secs + cap_secs/2 + 60 ))

  # Mark unsupported if clearly stated
  if echo "$start_text" | grep -qi "Command not supported"; then
    DONE[$i]=2
    REASON_START[$i]="Self-test not supported"
  fi

  echo "▶ $(printf '%-12s' "$dev") (${MODELS[$i]})  $( [[ ${DONE[$i]} -eq 2 ]] && echo '[N/A]' || echo "[starting]")"
done

# Allocate one progress line per device
for _ in "${!DEVS[@]}"; do echo "    [----------------------------------------]   0%"; done

# Live refresh loop with hard timeout
all_done=0
while (( ! all_done )); do
  printf "\033[%dA" "${#DEVS[@]}"
  all_done=1
  for i in "${!DEVS[@]}"; do
    dev="${DEVS[$i]}"

    if (( DONE[$i] == 1 )); then
      printf "    "; draw_bar 100; printf "  \n"; continue
    elif (( DONE[$i] == 2 )); then
      printf "    [----------------------------------------]  N/A\n"; continue
    elif (( DONE[$i] == 3 )); then
      printf "    [########################################] TIMEOUT\n"; continue
    fi

    pct_live="$(completed_pct_if_in_progress "$dev")"
    now=$(date +%s)
    elapsed=$(( now - START_TS[$i] ))
    est=$(( elapsed * 100 / (CUSHION[$i] > 30 ? CUSHION[$i] : 30) ))
    (( est > 99 )) && est=99

    if [[ -n "$pct_live" ]]; then
      pct="$pct_live"
      (( pct >= 100 )) && DONE[$i]=1 || all_done=0
    else
      # no explicit signal; still within timeout?
      if (( elapsed >= CUSHION[$i] )); then
        # One last check: maybe it just finished but not reporting progress
        st_now=$(last_selftest_status "$dev")
        if echo "$st_now" | grep -qi "completed"; then
          DONE[$i]=1
          pct=100
        else
          DONE[$i]=3
          TIMEOUT[$i]=1
          pct=100
        fi
      else
        pct="$est"
        all_done=0
      fi
    fi

    printf "    "; draw_bar "$pct"; printf "  \n"
  done
  (( all_done )) || sleep 3
done

echo

# Summarize results
declare -a ROWS
any_fail=0
for i in "${!DEVS[@]}"; do
  dev="${DEVS[$i]}"; model="${MODELS[$i]}"
  status="PASS"; reasons=()

  if (( DONE[$i] == 2 )); then
    reasons+=("${REASON_START[$i]:-Self-test not supported}")
  elif (( DONE[$i] == 3 )); then
    status="FAIL"; reasons+=("Self-test timed out (~${CUSHION[$i]}s)")
  fi

  allout=$(smartctl -a "$dev" 2>/dev/null || true)
  if overall_health_fail "$dev"; then status="FAIL"; reasons+=("SMART overall-health failed"); fi
  if r=$(nvme_crit_warn "$allout"); then status="FAIL"; reasons+=("$r"); fi
  if r=$(attr_nonzero_flags "$allout"); then status="FAIL"; reasons+=("$r"); fi

  stmsg=$(last_selftest_status "$dev")
  if [[ -n "$stmsg" ]]; then
    if echo "$stmsg" | grep -iq "failure\|aborted\|with issues"; then status="FAIL"; fi
    reasons+=("$stmsg")
  fi

  [[ "$status" == "FAIL" ]] && any_fail=1
  [[ ${#reasons[@]} -eq 0 ]] && reasons+=("SMART ok; self-test passed")
  ROWS+=("$(printf "%-16s %-24.24s %-10s %s" "$dev" "$model" "$status" "$(IFS='; '; echo "${reasons[*]}")")")
done

print_results_table "${ROWS[@]}"

exit $any_fail
