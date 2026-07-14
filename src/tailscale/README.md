
<div align="center">
  <a href="README.md">English</a> |
  <a href="README.CN.md">中文</a>
</div>

# Tailscale for IPFire

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Architecture](https://img.shields.io/badge/Arch-x86__64-blue)
![License](https://img.shields.io/badge/License-GPLv3-green)

Tailscale for IPFire provides a native Web UI for managing Tailscale directly from the IPFire administration interface.

![Screenshot](image/tailscale.png)

## Features

- Native IPFire Web UI integration
- Join Tailscale networks using authentication keys
- Supports custom hostnames, subnet routing, and exit node configuration
- Automatically detects platform architecture and downloads official Tailscale static binaries
- Supports English, Simplified Chinese, and Traditional Chinese; defaults to English for other languages

## Tested Platforms

| Platform | Version |
|----------|----------|
| IPFire | 2.29 Core Update 202 |
| Architecture | x86_64 / amd64 |

## Installation

```bash
sh install.sh
```

## Uninstallation

```bash
sh uninstall.sh
```

## Configuration

After installation, open:

```text
Services > Tailscale
```

First, click Start and enter the authentication key, then configure the following items as needed:

- Hostname
- Accept Routes
- Advertised Routes
- Exit Node

Click "Save Settings," then click:

```text
Join Network
```

Once completed:
1. Open the Tailscale admin console.
2. Select the corresponding IPFire device.
3. Configure the settings to disable key expiry and enable advertised routes or exit node options.

## Tailscale Binaries

The installer downloads official static binaries from:

https://pkgs.tailscale.com/stable/#static

## Notes

- Automatic deployment via the plugin settings page requires an authentication key.
- Route advertisements and exit nodes must be manually approved in the Tailscale admin console.
- DNS takeover is disabled by default (`--accept-dns=false`) to avoid overwriting the local IPFire DNS configuration.

## Disclaimer
This is an unofficial community project with no affiliation to the IPFire team; use it at your own risk.
