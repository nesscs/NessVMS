#Ness VMS Server Setup Script
#https://github.com/kvellaNess/NxVMS
#Wait for updates
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done
#Grab some dependencies
echo "Grab some dependencies"
sudo apt update
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
#Download Wallpaper
wget "https://github.com/kvellaNess/NxVMS/raw/master/NxBG.png" -P ~/Pictures
wget "https://github.com/kvellaNess/NxVMS/raw/master/NxLock.png" -P ~/Pictures
#Set Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file:////home/user/Pictures/NxBG.png'
gsettings set org.gnome.desktop.screensaver picture-uri 'file:////home/user/Pictures/NxLock.png'
#Finished!
echo "All Done!" | figlet