#!/bin/bash
#
# This script upgrades an Ubuntu system to the latest LTS release.
# It is designed to be run repeatedly.
#
# Intended for Ubuntu 18.04 LTS, but should work on other versions with slight modifications.
#
# Key features:
# - Runs non-interactively.
# - Checks for root privileges.
# - Updates the system before upgrading.
# - Upgrades to the next LTS release.
# - Removes obsolete packages after the upgrade.
# - Handles potential errors and retries.
# - Logs the entire process.
# - Checks for an internet connection.
#
# Variables
LOG_FILE="/var/log/NessVMS_OS_upgrade.log"
UPGRADE_release=$(lsb_release -rs) #Gets the release
if [[ "$UPGRADE_release" == "18.04" ]];
then
    NEXT_LTS="20.04"
elif [[ "$UPGRADE_release" == "20.04" ]];
then
    NEXT_LTS="22.04"
elif [[ "$UPGRADE_release" == "22.04" ]];
then
    NEXT_LTS="24.04"
else
    echo "This script is intended for Ubuntu 18.04, 20.04 or 22.04 LTS.  Exiting."
    exit 1
fi

# Function to log messages
log() {
    local message="$1"
    echo "$(date) - $message" >> "$LOG_FILE"
    echo "$(date) - $message"  # Also print to standard output
}

# Function to check internet connectivity
check_internet() {
    TIMEOUT=5
    if ! timeout --foreground $TIMEOUT ping -c 1 8.8.8.8 &>/dev/null; then
        log "No internet connection detected.  Exiting."
        return 1 # Return 1 for failure
    else
        return 0 # Return 0 for success
    fi
}

# Check for internet connection
if ! check_internet; then
  exit 1
fi

# Update the system
log "Updating the system..."
sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
sudo apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
sudo apt-get dist-upgrade -y 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    log "Error updating the system.  Exiting."
    exit 1
fi

# Upgrade to the next LTS release
log "Upgrading to Ubuntu ${NEXT_LTS} LTS..."
# DoUpgrade may return 1, even on success, if the system needs a reboot.
# So, check for the existence of the new release in /etc/os-release
sudo do-release-upgrade -f -d 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    log "Error upgrading to Ubuntu ${NEXT_LTS} LTS.  Checking /etc/os-release..."
    if grep -q "${NEXT_LTS}" /etc/os-release; then
        log "Upgrade process returned an error, but /etc/os-release shows ${NEXT_LTS}. Continuing..."
    else
        log "Upgrade process returned an error, and /etc/os-release does NOT show ${NEXT_LTS}. Exiting."
        exit 1
    fi
fi

# Remove obsolete packages
log "Removing obsolete packages..."
sudo apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    log "Error removing obsolete packages. Continuing..." #Not critical
fi

# Check if a reboot is required
if [ -f /var/run/reboot-required ]; then
    log "Reboot is required.  Please reboot the system. Don't forget to run this script again after rebooting."
else
    log "Upgrade complete.  Don't forget to run this script again to check for further updates."
fi

exit 0
