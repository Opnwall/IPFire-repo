# ttyd for IPFire

[![IPFire](https://img.shields.io/badge/IPFire-2.29%20Core%20203-red)](https://www.ipfire.org/)
[![ttyd](https://img.shields.io/badge/ttyd-Web%20Terminal-blue)](https://github.com/tsl0922/ttyd)

ttyd is a lightweight command-line tool that shares a terminal over the web. It allows users to access and interact with a shell session directly from a web browser using modern web technologies such as WebSockets. ttyd is easy to deploy, supports secure remote access, and is useful for web-based administration, troubleshooting, and remote system management.

This unofficial plugin integrates the excellent ttyd web terminal into the IPFire WebUI, allowing administrators to access a terminal session directly from their browser without needing a separate SSH client.

## Features

* Adds a ttyd entry under Services in the IPFire WebUI
* Adds Start, Stop, and Restart controls in the ttyd WebUI page
* Registers ttyd as an add-on service so it appears on the IPFire Services page
* Installs disabled-at-boot and stopped by default, so the terminal can be enabled only when needed
* Browser-based terminal access
* Simple installation and removal scripts

Tested on IPFire 2.29 (x86_64) Core Update 203

![](image/ttyd.png)

## Installation

```sh
sh install.sh
```
Run the installer as root from the project directory after copying it to your IPFire system.

The installer does not start ttyd automatically and leaves boot autostart disabled. Start it from `Services > ttyd`, or use `Status > Services` to start it and optionally enable boot autostart.

## Uninstallation

```sh
sh uninstall.sh
```
## Disclaimer
This is an unofficial community project with no affiliation to the IPFire team; use it at your own risk.