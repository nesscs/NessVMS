#!/bin/bash
#Ness VMS Server uninstall Script
#https://github.com/nesscs/NxVMS
#This script is unsupported, do not blindly run it
clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m10\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m09\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m08\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m07\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m06\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m05\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m04\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m03\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m02\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m01\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m"
echo -e "\e[7m00\e[0m"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 1.0

#Stop Nx Witness
sudo service networkoptix-mediaserver stop

#Uninstall Nx Witness
sudo apt remove networkoptix-client -y
sudo apt remove networkoptix-mediaserver -y
sudo apt clean -y
sudo apt autoremove -y

#Remove Lingering Nx Witness Files
rm -rf /opt/networkoptix/
rm -rf /home/$USER/.config/'Network Optix'/
rm -rf /home/$USER/.local/share/'Network Optix'/
