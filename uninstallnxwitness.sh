#!/bin/bash
#Ness VMS Server uninstall Script
#https://github.com/nesscs/NxVMS
#This script is unsupported, do not blindly run it
clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  10" 
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  09"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  08"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  07"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  06"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  05"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  04"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  03"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  02"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  01"
#Flash!
printf "\x1b[?5h"; sleep .1; printf "\x1b[?5l"
sleep 0.5

clear
echo ""
echo ""
echo ""
echo ""
echo -e "\e[7mYou are about to wipe NxWitness, CTRL - C to cancel\e[0m\  \  Too Late"
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
