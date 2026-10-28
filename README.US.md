<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# IPFire Community Repository

> **Core 204 release.** 

Only the latest package for each plugin is retained in the download directory. Back up configuration and preserve `/opt/ipfrepo/cache/`: removing an older installation requires its cached archive. If that cache is missing, upgrade to the latest version before uninstalling. Historical packages remain recoverable from Git history.

<p align="center">

**An unofficial community package repository for IPFire 2.29 Core Update 204 (x86_64)**

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Core Update](https://img.shields.io/badge/Core_Update-204-red)
![Architecture](https://img.shields.io/badge/x86__64-Supported-blue)
![Community](https://img.shields.io/badge/Community-Maintained-brightgreen)
![SHA256](https://img.shields.io/badge/Integrity-SHA256-success)

</p>

## Features

- Independent of the official Pakfire repository
- SHA-256 verification before every package installation
- Unified package management with `ipfrepo`
- Does not modify the official repository or GPG trust chain
- Community-maintained with continuously expanding packages
- Every current package has been install, syntax, and uninstall-restoration tested on IPFire 2.29 Core Update 204

## Install Repository

Run the following command as **root**:

```bash
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh | sh
```

## Install a Package

```bash
ipfrepo update
ipfrepo install mihomo
```

## Common Commands

```bash
ipfrepo list                       # List packages
ipfrepo info <package>             # Show package information
ipfrepo install <package>          # Install a package
ipfrepo remove <package>           # Remove a package
ipfrepo update                     # Update repository metadata
ipfrepo upgrade                    # Upgrade installed packages
```

## Available Packages

| Package | Version | Description |
| --- | --- | --- |
| `adguardhome` | 1.0.4 | AdGuard Home DNS filtering and management |
| `backup` | 1.0.3 | Firewall configuration backup manager |
| `captive-enhanced` | 1.1.10 | Multilingual Captive Portal with coupons, manual client authorization, and PDF export |
| `dns-firewall-custom-lists` | 1.1.3 | Custom HTTPS RPZ list management for the DNS Firewall |
| `ipfire-dyndns` | 1.0.3 | DDNS patch for Cloudflare, Alibaba Cloud and Tencent Cloud |
| `lang` | 1.0.4 | Chinese localization update tool |
| `lucky` | 1.0.4 | Lucky network toolbox |
| `mihomo` | 1.0.4 | Mihomo proxy and transparent proxy manager |
| `reports` | 1.0.6 | Firewall, IDS, URL Filter and DNS Firewall reporting |
| `sing-box` | 1.0.4 | sing-box proxy service |
| `speedtest` | 1.0.4 | Internet speed test |
| `syncthing` | 1.0.4 | Syncthing file synchronization |
| `tailscale` | 1.0.4 | Tailscale VPN integration |
| `easytier` | 1.0.0 | EasyTier mesh VPN |
| `ttyd` | 1.0.4 | Web-based terminal |
| `zerotier` | 1.0.4 | ZeroTier VPN integration |

## Component Versions

Upstream versions bundled with or used by the current packages:

| Component | Version | Source |
| --- | --- | --- |
| Mihomo | 1.19.33 | Bundled |
| sing-box | 1.14.4 | Bundled (glibc amd64) |
| AdGuard Home | 0.107.79 | Bundled |
| Lucky | 2.27.2 | Bundled |
| Syncthing | 2.1.7 | Bundled |
| Tailscale | 1.104.2 | Bundled |
| Speedtest Go | 1.8.3 | Bundled |
| ttyd | 1.7.7 | Bundled |
| ZeroTier | 1.16.2 | Bundled |

## Repository Structure

```text
.
├── src/                # Package source code
├── repo/
│   └── x86_64/All/     # Released packages
├── install-repo.sh     # Repository installation script
└── README.md
```

## Disclaimer

This project is community-maintained; the plugins are largely AI-generated or sourced from the community and do not have official support from the IPFire team.

Third-party packages may modify firewall, DNS, proxy, or other system services. Please be sure to back up your configuration before installation and, whenever possible, test these packages in a non-production environment.
