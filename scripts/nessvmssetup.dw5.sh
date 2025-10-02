#!/bin/bash
#Ness VMS Server Setup Script
#https://github.com/nesscs/NessVMS
#This script is for DW Spectrum Server V5
#This script is unsupported, do not blindly run it

#Set Machine Hostname to Last 4 digits of Network Interface
interface=$(ip route | grep '^default' | awk '{print $5}') # Get the primary network interface (e.g., eth0, enp3s0, etc.)
mac_address=$(cat /sys/class/net/$interface/address) # Get the MAC address of the primary network interface
last_four_digits=$(echo "$mac_address" | awk -F: '{print $(NF-1) $NF}') # Extract the last 4 digits of the MAC address
current_hostname=$(hostname) # Get the current hostname
new_hostname="${current_hostname}-${last_four_digits}" # Append the last 4 digits of the MAC address to the hostname
sudo hostnamectl set-hostname "$new_hostname" # Set the new hostname

#Set Repo's to Australia
sudo sed -i 's|http://archive.|http://au.archive.|g' /etc/apt/sources.list
sudo apt update
#Disable Screensaver
gsettings set org.gnome.desktop.session idle-delay 86400
#Wait for Auto updgrades to finish
echo -e "\e[7mWaiting for Auto Upgrades to finish\e[0m"
echo "This may take a while"
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 20; done
#Remove Amazon Shortcuts
echo -e "\e[7mRemove Amazon Shortcuts\e[0m"
sudo rm /usr/share/applications/ubuntu-amazon-default.desktop
sudo rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/Amazon.user.js
sudo rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/manifest.json
#Remove Extra Uneeded Apps
echo -e "\e[7mRemove Extra Uneeded Apps\e[0m"
sudo apt -y purge libreoffice* thunderbird rhythmbox aisleriot cheese gnome-mahjongg gnome-mines gnome-sudoku transmission*
#Grab dependencies
echo -e "\e[7mGrab dependencies\e[0m"
sudo apt -y install gdebi cockpit screen unzip
#Catch all Upgrade Server OS
echo ""
echo ""
echo -e "\e[7mUpgrade Server OS\e[0m"
echo "This may take a while"
echo ""
echo ""
sudo apt upgrade -y
#Download the latest DW Spectrum Server Release, enter desired build below
dx_build=5.1.5.39242 #Builds from here https://updates.digital-watchdog.com/digitalwatchdog/ Note full build No.
echo ""
echo ""
echo -e "\e[7mDownload DW Spectrum Build $dx_build \e[0m"
echo ""
echo ""
wget "https://updates.digital-watchdog.com/digitalwatchdog/$dx_build/linux/dwspectrum-server-$dx_build-linux_x64.deb" -P ~/Downloads
#Install DW Spectrum Server
echo ""
echo ""
echo -e "\e[7mInstall DW Spectrum \e[0m"
echo ""
echo ""
sudo DEBIAN_FRONTEND=noninteractive apt install -y ~/Downloads/dwspectrum-server-$dx_build-linux_x64.deb
sudo DEBIAN_FRONTEND=noninteractive apt install -f -y
#Download Wallpaper
echo -e "\e[7mSet Wallpaper\e[0m"
sudo wget "https://github.com/nesscs/NessVMS/raw/master/wallpaper/dw5bg.png" -P /opt/Ness/Wallpaper
sudo wget "https://github.com/nesscs/NessVMS/raw/master/wallpaper/dw5lock.png" -P /opt/Ness/Wallpaper
#Set Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file://///opt/Ness/Wallpaper/dw5bg.png'
gsettings set org.gnome.desktop.screensaver picture-uri 'file://///opt/Ness/Wallpaper/dw5lock.png'
#ReEnable Screensaver
gsettings set org.gnome.desktop.session idle-delay 600
#Final Cleanup
sudo apt -y upgrade
sudo apt -y clean
sudo apt -y autoremove
#Finished!
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mAll Done!\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
