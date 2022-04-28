#!/bin/bash
#Ness VMS4 Power tweak
#https://github.com/kvellaNess/NxVMS
#Download updated file
cd ~/Downloads
wget https://raw.githubusercontent.com/kvellaNess/NxVMS/master/vms4/etc/default/grub
#Backup old file
sudo cp /etc/default/grub /etc/default/grub.old
#Replace with new file
sudo mv ~/Downloads/grub /etc/default/grub

# update-grub
