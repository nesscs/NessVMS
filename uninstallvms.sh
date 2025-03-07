#!/bin/bash
# Set the environment variable for non-interactive operation
export DEBIAN_FRONTEND=noninteractive
#Ness VMS Server uninstall Script
#https://github.com/nesscs/NessVMS
#This script is unsupported, do not blindly run it
clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   10 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   09 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   08 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   07 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   06 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   05 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   04 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   03 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   02 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   01 \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7m   You are about to wipe Nx Witness or DW Spectrum!  CTRL - C to Cancel   Too Late! \e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 1.5 

clear

# Stop Nx Witness & DW Spectrum (handle if services aren't running)
sudo service networkoptix-mediaserver stop || true
sudo service digitalwatchdog-mediaserver stop || true

# Uninstall Nx Witness & DW Spectrum
sudo apt remove networkoptix-client -y
sudo apt remove networkoptix-mediaserver -y
sudo apt remove digitalwatchdog-mediaserver -y
sudo apt remove digitalwatchdog-client -y

sudo apt clean -y
sudo apt autoremove -y

# Remove Lingering Nx Witness Files
rm -rf /opt/networkoptix/
rm -rf /home/$USER/.config/'Network Optix'/
rm -rf /home/$USER/.local/share/'Network Optix'/

echo "Uninstallation complete."
