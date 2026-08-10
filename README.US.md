<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# IPFire Community Repository

<p align="center">

**An unofficial community package repository for IPFire 2.29 Core Update 203 (x86_64)**

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Core Update](https://img.shields.io/badge/Core_Update-203-red)
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
- Every current package has been install, syntax, and uninstall-restoration tested on IPFire 2.29 Core Update 203

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
| `adguardhome` | 1.0.3 | AdGuard Home DNS filtering and management |
| `backup` | 1.0.2 | Firewall configuration backup manager |
| `ipfire-dyndns` | 1.0.2 | DDNS patch for Cloudflare, Alibaba Cloud and Tencent Cloud |
| `lang` | 1.0.3 | Chinese localization update tool |
| `lucky` | 1.0.3 | Lucky network toolbox |
| `mihomo` | 1.0.3 | Mihomo proxy and transparent proxy manager |
| `reports` | 1.0.2 | Firewall, IDS and DNS reporting |
| `sing-box` | 1.0.3 | sing-box proxy service |
| `speedtest` | 1.0.3 | Internet speed test |
| `syncthing` | 1.0.3 | Syncthing file synchronization |
| `tailscale` | 1.0.3 | Tailscale VPN integration |
| `ttyd` | 1.0.3 | Web-based terminal |
| `zerotier` | 1.0.3 | ZeroTier VPN integration |

## Component Versions

Upstream versions bundled with or used by the current packages:

| Component | Version | Source |
| --- | --- | --- |
| Mihomo | 1.19.29 | Bundled |
| sing-box | 1.13.14 | Bundled (glibc amd64) |
| AdGuard Home | 0.107.78 | Bundled |
| Lucky | 2.27.2 | Bundled |
| Syncthing | 2.1.3 | Downloaded from the official release during installation |
| Tailscale | 1.102.2 | Downloaded from the official stable release during installation |
| Speedtest Go | 1.7.10 | Bundled |
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
