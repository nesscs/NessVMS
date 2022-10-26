#!/bin/bash
# Disable Ness VMS4 Power tweak
#https://github.com/nesscs/NxVMS
#Backup patched power file
sudo cp /etc/default/grub /etc/default/grub.powepatch
#Check the old file exists and copy it across
FILE=/etc/default/grub.old
if [ -f "$FILE" ]; then
    echo "$FILE exists."
    #Restore old file
    sudo cp /etc/default/grub.old /etc/default/grub
    #Update Grub file with new command line
    sudo update-grub
    #Finished!
    echo ""
    echo ""
    echo ""
    echo ""
    echo -e "\e[7mAll Done! Please Reboot\e[0m"
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
else 
    echo ""
    echo ""
    echo "$FILE does not exist."
    echo ""
    echo "Power Patch was not run on this machine"
    echo ""
    echo ""
fi
