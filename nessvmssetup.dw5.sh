#!/bin/bash
#Ness VMS Server Setup Script
#https://github.com/nesscs/NessVMS
#This script is for DW Spectrum Server V5
#This script is unsupported, do not blindly run it

#Set Machine Hostname to Last 4 digits of Eth0
macaddy=$(cat /sys/class/net/enp3s0/address | tr -d ':' | grep -o '....$')
sudo hostnamectl set-hostname NessVMS-$macaddy
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
sudo apt -y clean
sudo apt -y autoremove
#Grab dependencies
echo -e "\e[7mGrab dependencies\e[0m"
sudo apt -y install gdebi cockpit screen unzip
#Catch all Update Server
echo ""
echo ""
echo -e "\e[7mUpdate Server OS\e[0m"
echo "This may take a while"
echo ""
echo ""
sudo apt -y upgrade
#Download the latest DW Spectrum Server Release
echo ""
echo ""
echo -e "\e[7mDownload DW Spectrum \e[0m"
echo ""
echo ""
wget "https://digital-watchdog.com/admin/assets/_downloads/dwspectrum-server-5.0.0.36871-linux_x64.zip" -P ~/Downloads
#Extract Zip File, Thanks for making things difficult guys
unzip ~/Downloads/dwspectrum-server-5.0.0.36871-linux_x64.zip
#Install DW Spectrum Server
echo ""
echo ""
echo -e "\e[7mInstall DW Spectrum \e[0m"
echo ""
echo ""
sudo gdebi --non-interactive ~/dwspectrum-server-5.0.0.36871-linux_x64.deb
#Download Wallpaper
echo -e "\e[7mSet Wallpaper\e[0m"
sudo wget "https://github.com/nesscs/NessVMS/raw/master/wallpaper/dw5bg.png" -P /opt/Ness/Wallpaper
sudo wget "https://github.com/nesscs/NessVMS/raw/master/wallpaper/dw5lock.png" -P /opt/Ness/Wallpaper
#Set Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file://///opt/Ness/Wallpaper/dw5bg.png'
gsettings set org.gnome.desktop.screensaver picture-uri 'file://///opt/Ness/Wallpaper/dw5lock.png'
#ReEnable Screensaver
gsettings set org.gnome.desktop.session idle-delay 600
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
