#!/bin/bash
#Ness VMS Server uninstall Script
#https://github.com/nesscs/NxVMS
#This script is unsupported, do not blindly run it
while true; do

read -p "Do you want to proceed? (y/n) " yn

case $yn in 
	[yY] ) echo ok, we will proceed;
		break;;
	[nN] ) echo exiting...;
		exit;;
	* ) echo invalid response;;
esac

done

echo doing stuff...
echo Uninstalling...

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
