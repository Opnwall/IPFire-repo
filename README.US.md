<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a> 
</div>

# IPFire Community Repository

<p align="center">

**An unofficial community package repository for IPFire 2.29 (x86_64)**

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
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
| `adguardhome` | 1.0.1 | AdGuard Home DNS filtering and management |
| `backup` | 1.0.1 | Firewall configuration backup manager |
| `ipfire-dyndns` | 1.0.1 | DDNS patch for Cloudflare, Alibaba Cloud and Tencent Cloud |
| `lang` | 1.0.1 | Chinese localization update tool |
| `lucky` | 1.0.1 | Lucky network toolbox |
| `mihomo` | 1.0.1 | Mihomo proxy and transparent proxy manager |
| `reports` | 1.0.1 | Firewall, IDS and DNS reporting |
| `sing-box` | 1.0.1 | sing-box proxy service |
| `syncthing` | 1.0.1 | Syncthing file synchronization |
| `tailscale` | 1.0.1 | Tailscale VPN integration |
| `ttyd` | 1.0.1 | Web-based terminal |
| `zerotier` | 1.0.1 | ZeroTier VPN integration |

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

This project is maintained by the community and is **not affiliated with or supported by the official IPFire Project**.

Third-party packages may modify firewall, DNS, proxy, or other system services. Always back up your configuration before installation and test packages in a non-production environment whenever possible.
