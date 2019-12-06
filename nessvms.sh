#Ness VMS Server Setup Script
#Grab some dependencies
sudo apt -y install figlet beep gdebi cockpit
#Remove Amazon Crap
echo "Remove Amazon Stuff" | figlet
sudo rm /usr/share/applications/ubuntu-amazon-default.desktop
sudo rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/Amazon.user.js
sudo rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/manifest.json
#Remove Extra stuff
echo "Remove Other Apps" | figlet
sudo apt -y purge libreoffice* thunderbird rhythmbox
sudo apt -y clean
sudo apt -y autoremove
#Update Server
echo "Update Server" | figlet
sudo apt -y update
sudo apt -y upgrade
#Download the latest Nx Server Release
echo "Download NxWitness" | figlet
wget "http://updates.networkoptix.com/default/29987/linux/nxwitness-server-4.0.0.29987-linux64.deb" -P ~/Downloads
#Download the latest Nx Desktop Client Release
wget "http://updates.networkoptix.com/default/29987/linux/nxwitness-client-4.0.0.29987-linux64.deb" -P ~/Downloads
#Install NX Server
echo "Install NxWitness" | figlet
sudo gdebi --non-interactive ~/Downloads/nxwitness-server-4.0.0.29987-linux64.deb
#Install Nx Client
sudo gdebi --non-interactive ~/Downloads/nxwitness-client-4.0.0.29987-linux64.deb
#Finished!
echo "All Done!" | figlet