<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# IPFire Community Repository

**An unofficial community package repository for IPFire 2.29 Core Update 206 (x86_64)**

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Core Update](https://img.shields.io/badge/Core_Update-206-red)
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
- Core 206 isolated syntax, translation-resource and English/Simplified/Traditional CGI checks passed; see [validation scope](VALIDATION-Core206.md)

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
| `adguardhome` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/adguardhome-1.0.5-x86_64.tar.gz) | AdGuard Home DNS filtering and management |
| `backup` | [1.0.4](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/backup-1.0.4-x86_64.tar.gz) | Firewall configuration backup manager |
| `captive-enhanced` | [1.1.13](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/captive-enhanced-1.1.13-x86_64.tar.gz) | Multilingual Captive Portal with coupons, manual client authorization, and PDF export |
| `dns-firewall-custom-lists` | [1.1.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/dns-firewall-custom-lists-1.1.5-x86_64.tar.gz) | Custom HTTPS RPZ list management for the DNS Firewall |
| `ipfire-dyndns` | [1.0.4](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/ipfire-dyndns-1.0.4-x86_64.tar.gz) | DDNS patch for Cloudflare, Alibaba Cloud and Tencent Cloud |
| `lang` | [1.0.8](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/lang-1.0.8-x86_64.tar.gz) | Chinese localization update tool |
| `lucky` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/lucky-1.0.5-x86_64.tar.gz) | Lucky network toolbox |
| `mihomo` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/mihomo-1.0.5-x86_64.tar.gz) | Mihomo proxy and transparent proxy manager |
| `reports` | [1.0.7](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/reports-1.0.7-x86_64.tar.gz) | Firewall, IDS, URL Filter and DNS Firewall reporting |
| `sing-box` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/sing-box-1.0.5-x86_64.tar.gz) | sing-box proxy service |
| `speedtest` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/speedtest-1.0.5-x86_64.tar.gz) | Internet speed test |
| `syncthing` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/syncthing-1.0.5-x86_64.tar.gz) | Syncthing file synchronization |
| `tailscale` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/tailscale-1.0.5-x86_64.tar.gz) | Tailscale VPN integration |
| `easytier` | [1.0.2](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/easytier-1.0.2-x86_64.tar.gz) | EasyTier mesh VPN with custom node hostname |
| `ttyd` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/ttyd-1.0.5-x86_64.tar.gz) | Web-based terminal |
| `zerotier` | [1.0.5](https://opnwall.github.io/IPFire-repo/repo/x86_64/All/zerotier-1.0.5-x86_64.tar.gz) | ZeroTier VPN integration |

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


## Custom Repository URL

The installer and client support IPFire Core 206 on x86_64 only. Specify a custom repository root when installing or reinstalling:

```sh
IPFREPO_BASE_URL=https://mirror.example/IPFire-repo sh install-repo.sh
```

The URL is saved in `/opt/ipfrepo/repository.url` and reused by subsequent `ipfrepo` commands and reinstalls. Precedence is the `IPFREPO_BASE_URL` environment variable, the saved URL, then the default community repository. An environment override for a single `ipfrepo` command is temporary and does not rewrite the saved URL. HTTP/HTTPS URLs are supported; whitespace, query strings and fragments are not allowed.
