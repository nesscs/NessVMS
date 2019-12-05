#Ness VMS Server Setup Script
#Update Server
sudo apt update && apt upgrade
#Grab some dependencies
sudo apt install wget
sudo apt install gdebi
#Download the latest Nx Server Release
wget "http://updates.networkoptix.com/default/29987/linux/nxwitness-server-4.0.0.29987-linux64.deb" /Downloads
#Download the latest Nx Desktop Client Release
wget "http://updates.networkoptix.com/default/29987/linux/nxwitness-client-4.0.0.29987-linux64.deb"
#Install NX Server
sudo gdebi nxwitness-server-4.0.0.29987-linux64.deb
#Install Nx Client
sudo gdebi nxwitness-client-4.0.0.29987-linux64.deb