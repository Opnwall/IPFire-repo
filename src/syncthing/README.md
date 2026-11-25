<div align="center">
  <a href="README.md">English</a> |
  <a href="README.CN.md">中文</a>
</div>

# Syncthing for IPFire

> Plugin version: **1.0.5** · Target: **IPFire 2.29 Core Update 206 (x86_64)**
> UI languages: English / Simplified Chinese / Traditional Chinese, including Core 206 locale identifiers.

Validation on 2026-11-25: Core 206 x86_64 syntax, translation-resource and initial English/Simplified/Traditional CGI checks passed in isolation. Live service connectivity, reboot and complete install/uninstall regression were not repeated in this run.

![IPFire](https://img.shields.io/badge/IPFire-2.29%20Core%20Update%206-red)
![Architecture](https://img.shields.io/badge/Architecture-x86__64-blue)

Syncthing is a free and open-source continuous file synchronization tool that securely syncs files directly between devices without relying on a central cloud server. Data is transferred using end-to-end encryption, ensuring privacy and security. Syncthing supports Windows, macOS, Linux, and many other platforms, making it an ideal solution for self-hosted, peer-to-peer file synchronization across computers and networks.

This plugin installs **Syncthing** on IPFire and provides an easy way to deploy and manage Syncthing on your firewall system.

## Features

- Quick installation and removal
- Native integration with IPFire
- Browser-based Syncthing management interface

## Screenshot

![](image/syncthing.png)

## Installation

```sh
sh install.sh
```

Copy the project directory to your IPFire system and run the installer as **root**.

Installation complete; go to Services > Syncthing to proceed.

## Uninstallation

```sh
sh uninstall.sh
```

## Tested Environment

| Component | Version |
|-----------|---------|
| IPFire | 2.29 |
| Core Update | 206 |
| Architecture | x86_64 |

## Disclaimer
This is an unofficial community project with no affiliation to the IPFire team; use it at your own risk.
