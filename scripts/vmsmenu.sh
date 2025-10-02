#!/usr/bin/env bash
# vmsmenu.sh — Ness VMS Menu (Ubuntu TUI)
#
# Run via one-liner:
#   curl -fsSL https://nesscs.com/vmsmenu | sudo bash
#   wget -qO-  https://nesscs.com/vmsmenu | sudo bash
#
# What this does:
# - Presents a whiptail menu to launch common maintenance scripts
# - Auto-installs whiptail/curl if missing (requires sudo/root)
# - Ensures ANY child script you launch can still prompt the user
#   even though this menu is piped into bash (stdin is reattached
#   to the real terminal: /dev/tty)
# - Logs to /var/log/ness-vmsmenu.log
#
# Add/modify menu items in the “MENU ITEMS” section below.
# Each item maps to a URL; we download to /tmp and run it with the
# terminal as stdin/stdout so read/whiptail prompts work reliably.
#
# Tested on Ubuntu 18.04 — 24.04.

set -Eeuo pipefail
IFS=$'\n\t'

PROGRAM_NAME="Ness VMS Menu"
DEFAULT_MENU_URL="https://nesscs.com/vmsmenu"
LOG_FILE="/var/log/ness-vmsmenu.log"
TMP_ROOT="$(mktemp -d -t vmsmenu.XXXXXX)"

cleanup() { rm -rf "$TMP_ROOT" || true; }
trap cleanup EXIT

# --- Reattach to the real terminal so interactive prompts work ---
TTY=${TTY:-/dev/tty}
if [ ! -t 0 ] && [ -r "$TTY" ]; then
  exec <"$TTY"
fi
mkdir -p "$(dirname "$LOG_FILE")" || true
touch "$LOG_FILE" || true
chmod 0644 "$LOG_FILE" || true
# Log to file AND show on the terminal
if [ -w "$TTY" ]; then
  exec 3>"$TTY" || true
  exec > >(tee -a "$LOG_FILE" >&3) 2>&1
else
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

# --- Privileges / package helpers ---
SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    $SUDO -v || true
  fi
fi

APT_UPDATED=0
ensure_apt_updated() {
  if [ $APT_UPDATED -eq 0 ]; then
    $SUDO apt-get update -qq || true
    APT_UPDATED=1
  fi
}
APT_INSTALL() {
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -yq install "$@"
}
require_cmd() {
  # require_cmd <binary> [debian-package-name]
  local bin="$1" pkg="${2:-$1}"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "[INFO] Installing $pkg ..."
    ensure_apt_updated
    APT_INSTALL "$pkg"
  fi
}

# --- Ensure dependencies ---
require_cmd whiptail whiptail
require_cmd curl curl
require_cmd bash bash
require_cmd tee coreutils || true

# --- UI helpers ---
msg() {
  whiptail --title "$PROGRAM_NAME" --msgbox "$1" 12 78
}
ask_yesno() {
  whiptail --title "$PROGRAM_NAME" --yesno "$1" 10 78
}

# --- Run a remote script with a real TTY so prompts work ---
run_remote_script() {
  # Usage: run_remote_script "Title" "https://url/script.sh" [args...]
  local title="$1"; shift
  local url="$1"; shift || true
  local args=("$@")

  local base
  base="$(basename "${url%%\?*}")"
  base="${base:-script.sh}"
  base="${base//[^A-Za-z0-9._-]/_}"
  local tmp="$TMP_ROOT/$base"

  echo "[INFO] Fetching $title from $url"
  if ! curl -fsSL "$url" -o "$tmp"; then
    msg "Failed to download script:\n$url"
    return 1
  fi
  chmod +x "$tmp" || true

  clear
  echo "=================================================="
  echo "  Running: $title"
  echo "  Source:  $url"
  echo "  Log:     $LOG_FILE"
  echo "=================================================="
  echo

  # Give child script a real terminal for stdin/stdout/stderr
  bash "$tmp" "${args[@]}" <"$TTY" >"$TTY" 2>&1
  local rc=$?
  echo
  echo "----- Completed: $title (exit $rc) -----"
  read -r -p "Press Enter to return to the menu..." <"$TTY"
  return $rc
}

# --- Self-update (pull latest and relaunch) ---
self_update() {
  local url="${1:-$DEFAULT_MENU_URL}"
  echo "[INFO] Updating from $url"
  local latest="$TMP_ROOT/.vmsmenu.latest.sh"
  if curl -fsSL "$url" -o "$latest"; then
    chmod +x "$latest" || true
    echo "[INFO] Relaunching updated menu ..."
    exec bash "$latest"
  else
    msg "Failed to download latest menu from:\n$url"
  fi
}

# --- MENU ITEMS: tag + description, then case to map to URLs ---
declare -a MENU_ITEMS
add_item() { MENU_ITEMS+=("$1" "$2"); }

add_item "logs"     "VMS Logs: power/start/stop timeline (vmslogs)"
add_item "smart"    "SMART quick scan on all drives (smartscan)"
add_item "storage"  "Format & mount new disks (>=200GB) safely"
add_item "nvr"      "Install/Update Nx Witness or Digital Watchdog"
add_item "custom"   "Run a script by pasting a URL"
add_item "update"   "Update/Reload this menu"
add_item "about"    "About / Help"
add_item "quit"     "Quit"

# --- Main loop ---
while true; do
  CHOICE=$(
    whiptail --title "$PROGRAM_NAME" \
      --menu "Select an action:" 20 78 10 \
      "${MENU_ITEMS[@]}" \
      3>&1 1>&2 2>&3
  ) || exit 0

  case "$CHOICE" in
    logs)
      # Your published script (streams fine): https://nesscs.com/vmslogs
      run_remote_script "VMS Logs" "https://nesscs.com/vmslogs"
      ;;
    smart)
      # Your published SMART scan: https://nesscs.com/smartscan
      run_remote_script "SMART Scan" "https://nesscs.com/smartscan"
      ;;
    storage)
      # Your storage formatter/mounter: https://nesscs.com/storage
      run_remote_script "Storage Formatter/Mounter" "https://nesscs.com/storage"
      ;;
    nvr)
      # Replace with your live installer URL (feed/parser or static):
      # Examples you’ve used historically; swap to your current canonical:
      #   https://nesscs.com/nvrinstall
      run_remote_script "VMS Installer (Nx Witness / DW)" "https://nesscs.com/nvrinstall"
      ;;
    custom)
      URL=$(
        whiptail --title "$PROGRAM_NAME" \
          --inputbox "Paste a script URL to run.\n(https://..., http://..., or file:///path.sh)" \
          12 78 "" 3>&1 1>&2 2>&3
      ) || continue
      [ -z "${URL:-}" ] && continue
      run_remote_script "Custom Script" "$URL"
      ;;
    update)
      self_update "$DEFAULT_MENU_URL"
      ;;
    about)
      msg "Ness VMS Menu\n\nUsage:\n  curl -fsSL https://nesscs.com/vmsmenu | sudo bash\n  wget -qO- https://nesscs.com/vmsmenu | sudo bash\n\nNotes:\n• Child scripts are run with the real terminal as stdin/stdout, so any read/whiptail prompts work, even from a piped one-liner.\n• Output is logged to:\n  $LOG_FILE\n• Edit the menu by updating this script in GitHub; 'Update' pulls the latest and relaunches."
      ;;
    quit)
      exit 0
      ;;
  esac
done
