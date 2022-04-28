#!/bin/bash
#Ness VMS4 Power tweak
#https://github.com/kvellaNess/NxVMS
cd ~/Downloads
wget https://raw.githubusercontent.com/kvellaNess/NxVMS/master/vms4/etc/default/grub
sudo cp ~/Downloads/grub /etc/default/grub

# update-grub
