<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Backup for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.4** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

This plugin integrates firewall configuration backups into the IPFire Web UI, allowing administrators to create, restore, download and delete firewall-rule backups.

## Features

- IPFire Web UI menu integration.
- Create firewall configuration backups.
- Restore existing backups.
- Download and delete backups.
- Integrated language resources.

## Installation

Log in as root and run in the plugin directory:

```sh
bash install.sh
```

## Uninstallation

Log in as root and run in the plugin directory:

```sh
bash uninstall.sh
```

## Access

After installation, open the following menu in the IPFire Web UI:

```text
Services > Firewall Backup
```

## Project Structure

```text
src/
install.sh
uninstall.sh
```

The installer copies files from `src/` to the IPFire root filesystem and sets permissions for the CGI page, menu, language files and backup directory.

## Disclaimer

This is an unofficial community-maintained project with no affiliation to the IPFire team. Users are responsible for assessing and accepting the risks of use.
