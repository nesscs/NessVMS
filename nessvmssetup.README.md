# NessVMS Install Script

Setup Scripts for Ness VMS Servers, this will:
1. Set Auto Updates for Australian Servers
2. Delete unecessary pakages
3. Install required dependencies
4. Update Server OS
5. Download & install Video management software.
6. Download & Set Wallpaper

## Warning
Although these scripts are public facing, they are not intended for general consumption. Do not blindly run these scrips, they are unsupported. 
You WILL NOT receive technical support if you run these without direction.

## Requirements
You have installed the latest version of Ubuntu LTS 24.04 on your VMS Hardware

## Installation

Press Ctrl-Alt-T to launch the system terminal and type in this command to install Nx Witness:

```bash
sudo wget -O - https://nesscs.com/nessvms | bash
```

Press Ctrl-Alt-T to launch the system terminal and type in this command to install DW Spectrum:

```bash
sudo wget -O - https://nesscs.com/nessdwvms | bash
```

Enter your password when prompted

For legacy support of older versions of Nxwitness OR DW Spectrum, these scripts are available, the names should be self explanatory eg:
```bash
sudo wget -O - https://nesscs.com/nx4 | bash
sudo wget -O - https://nesscs.com/nx5 | bash
sudo wget -O - https://nesscs.com/nx6 | bash
sudo wget -O - https://nesscs.com/dw5 | bash
sudo wget -O - https://nesscs.com/dw6 | bash
```

## Uninstall Script
To cleanly remove Video Management Software you can run this script, it will not remove footage.

**Note:** There is no confirmation, this script will run and remove your VMS install
```bash
sudo wget -O - https://nesscs.com/uninstallvms | bash
```

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
