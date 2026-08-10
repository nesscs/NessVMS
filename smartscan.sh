#!/usr/bin/env bash
# smartscan.sh
# Run SMART short tests on all disks in parallel with robust waits + retries,
# show live progress, then PASS/FAIL.
#
# Run directly from Ness:
# wget -qO- https://nesscs.com/smartscan | bash

set -euo pipefail

SCRIPT_URL="https://nesscs.com/smartscan"

# ===== Privilege Elevation =====

if [[ $EUID -ne 0 ]]; then
    echo
    echo "SMART Scan requires administrator privileges."
    echo "Please enter your sudo password when prompted."
    echo

    if ! command -v sudo >/dev/null 2>&1; then
        echo "ERROR: sudo is not installed."
        exit 2
    fi

    # Explicitly use the terminal for the sudo prompt.
    # This is important because stdin is currently being used by the
    # wget | bash pipeline.
    if ! sudo -v </dev/tty; then
        echo "ERROR: Unable to obtain administrator privileges."
        exit 2
    fi

    echo
    echo "Administrator privileges granted."
    echo "Starting SMART Scan..."
    echo

    # Re-download and execute the script as root.
    exec sudo -n bash -c "wget -qO- '$SCRIPT_URL' | bash"
fi

# We are root from this point onward.

# ===== Helpers =====

ensure_smartctl() {
    if ! command -v smartctl >/dev/null 2>&1; then
        echo "smartctl not found. Installing smartmontools..."

        apt-get update -y
        apt-get install -y smartmontools >/dev/null || {
            echo "Failed to install smartmontools."
            exit 3
        }
    fi
}
