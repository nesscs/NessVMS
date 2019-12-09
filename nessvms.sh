#Ness VMS Server Setup Script
#https://github.com/kvellaNess/NxVMS
#Disable Screensaver
gsettings set org.gnome.desktop.session idle-delay 86400
#Wait for Audo updgrades to finish
echo ""
echo ""
echo -e "\e[7mWaiting for Auto Upgrades to finish, this can take some time"
echo ""
echo ""
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 10; done
#Grab some dependencies
echo ""
echo ""
echo -e "\e[7mGrab some dependencies"
echo ""
echo ""
sudo apt update
sudo apt -y install figlet beep gdebi cockpit
#Remove Amazon Crap
echo ""
echo ""
echo "Remove Amazon Stuff" | figlet
echo ""
echo ""
sudo rm /usr/share/applications/ubuntu-amazon-default.desktop
sudo rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/Amazon.user.js
sudo rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/manifest.json
#Remove Extra stuff
echo ""
echo ""
echo "Remove Other Apps" | figlet
echo ""
echo ""
sudo apt -y purge libreoffice* thunderbird rhythmbox
sudo apt -y clean
sudo apt -y autoremove
#Update Server
echo ""
echo ""
echo "Update Server" | figlet
echo ""
echo ""
sudo apt -y upgrade
#Download the latest Nx Server Release
echo ""
echo ""
echo "Download NxWitness" | figlet
echo ""
echo ""
wget "http://updates.networkoptix.com/default/29987/linux/nxwitness-server-4.0.0.29987-linux64.deb" -P ~/Downloads
#Download the latest Nx Desktop Client Release
wget "http://updates.networkoptix.com/default/29987/linux/nxwitness-client-4.0.0.29987-linux64.deb" -P ~/Downloads
#Install NX Server
echo ""
echo ""
echo "Install NxWitness" | figlet
echo ""
echo ""
sudo gdebi --non-interactive ~/Downloads/nxwitness-server-4.0.0.29987-linux64.deb
#Install Nx Client
sudo gdebi --non-interactive ~/Downloads/nxwitness-client-4.0.0.29987-linux64.deb
#Download Wallpaper
echo ""
echo ""
echo "Set Wallpaper" | figlet
echo ""
echo ""
wget "https://github.com/kvellaNess/NxVMS/raw/master/NxBG.png" -P ~/Pictures
wget "https://github.com/kvellaNess/NxVMS/raw/master/NxLock.png" -P ~/Pictures
#Set Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file:////home/user/Pictures/NxBG.png'
gsettings set org.gnome.desktop.screensaver picture-uri 'file:////home/user/Pictures/NxLock.png'
#ReEnable Screensaver
gsettings set org.gnome.desktop.session idle-delay 600
#Finished!
echo "All Done!" | figlet