# Guide to upgrading NessVMS OS

## Warning
Although this guide & scripts are public facing, they are not intended for general consumption. Do not blindly run these scripts, they are unsupported. 

## Prerequisites
NessVMS OS is based upon Ubuntu LTS with extremely minimal changes. Some VMS will have shipped with Ubuntu 18.04 LTS which is now end of life and soon to be unsupported by NxWitness/DW Spectrum. 
It is recommended to upgrade to the latest Ubuntu LTS release to ensure that the OS is a supported release and covered by Security updates.
To upgrade to the latest Ubuntu LTS release you must step through all subsequent LTS releases sequentially.
eg. If running 18.04 LTS you must upgrade to 20.04 LTS THEN 22.04 LTS THEN 24.04 LTS. You cannot "Upgrade" directly from 18.04 LTS to 24.04 LTS.

There is supported method to upgrade Ubuntu LTS versions as detailed below. 
As a matter of time savings, it is debateable whether one would choose to simply start a fresh new MessVMS OS install with the latest version of NessVMS OS running on Ubuntu 24.04 LTS.
The caveat being that you must manually deactivate/migrate/reactivate licenses and backup/restore your VMS Database. 

Arguably users should already be doing this.

Instead, it may be "simpler" to just upgrade following the recommended steps. To this end the script below has been created to assist in this method. 
It will follow Ubuntu recommended steps to upgrade through releases and should not require the user to change anything with their NxWitness/DW Spectrum install.


**Backup Important Data**

First of all, It is strongly recommended to backup your important data, configuration files, and anything that you can’t afford to lose.

## Auto Upgrade your NessVMS OS

Run the following command to automatically being the NessVMS OS upgrade proces, note that you will need to repeatedly run this command until you reach the latest version.

Press Ctrl-Alt-T to launch the system terminal and type in this command:

```bash
sudo wget -O - https://nesscs.com/nessvmsupgrade | bash
```

## Manually Upgrade your NessVMS OS

Press Ctrl-Alt-T to launch the system terminal and type in this command:

```bash
sudo apt update && sudo apt upgrade -y
```
Enter your password when prompted

Reboot after upgrading

```bash
sudo reboot
```

## Remote Manual Upgrade of NessVMS OS
It is strongly recommend to use Screen tool when attempting to upgrade a remote server via SSH. This will keep running the upgrade the process in case your SSH session is dropped for any reason.

To install the screen tool, Enter:

```bash
sudo apt install screen
```
Once it’s installed, start the screen session with command:
```bash
screen
```

If your SSH connection is broken when upgrading, you can re-attach to the upgrade session easily with command:

```bash
screen -Dr
```

## Start the Upgrade
Start the upgrade with this command
```bash
sudo do-release-upgrade
```

If you’re running the upgrade process under SSH session, the following warning message will appear. Just type “y” to continue.

Follow the prompts and push Enter to continue.

After a few seconds, the upgrade wizard will display the summary of how many packages are going to be removed, how many packages will be upgraded, how many new packages are going to be newly installed and the total download size.

Press “y” to start the upgrade process. This will take a while to complete depending upon the speed of your Internet connection.

During the upgrade process, some services installed on your system need to be restarted when certain libraries are upgraded. Since these restarts may cause interruptions of service for the system, you will normally be prompted on each upgrade for the list of services you wish to restart. Say yes to restarting services as required.

If you are prompted for configuration updates, you can choose to leave existing configurations in place.

After the upgrade is complete, allow the server to reboot.

You can check verify the Ubuntu version using command:

```bash
lsb_release -a
```

## Support
There is no support! Contact Kieran for changes.

## License
MIT License

Copyright (c) 2025 Ness Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
