# VMS4 Power Script

This script injects a command line into Grub as directed via Hikvision to tweak power saving functions on the VMS4

## Requirements
You have installed the latest version of Ubuntu LTS 18.04.3 on your VMS Hardware

## Warning
Although these scripts are public facing, they are not intended for general consumption. Do not blindly run these scrips, they are unsupported. 
You WILL NOT receive technical support if you run these without direction.

## Installation

Press Ctrl-Alt-T to launch the system terminal and type in this command:

```bash
sudo wget -O - https://nesscs.com/vms4power | bash
```
Enter your password when prompted

## Un-Installation

Press Ctrl-Alt-T to launch the system terminal and type in this command:

This will check for the presence of the original boot file on the system, If the system did not have the patch run, it wont do anything.

```bash
sudo wget -O - https://nesscs.com/vms4powerdisble | bash
```
Enter your password when prompted

## Support
There is no support! Contact Kieran for changes.

## License
MIT License

Copyright (c) 2019 Ness Corporation

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
