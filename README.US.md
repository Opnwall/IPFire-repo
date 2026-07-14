# Opnwall IPFire Community Repository

An unofficial community plugin repository for **IPFire 2.29 x86_64**. It uses an independent `opnwall` manager and does not replace or modify the official Pakfire repository or its GPG trust chain.

## Install the repository

Run as `root`:

```sh
curl -fsSL https://opnwall.github.io/IPFire-repo/install-opnwall.sh | sh
```

## Usage

```sh
opnwall list
opnwall info adguardhome
opnwall install adguardhome
opnwall remove adguardhome
opnwall update
opnwall upgrade
```

Every package is SHA-256 verified before its own install or uninstall script is executed. State is stored under `/opt/opnwall/`.

## Packages

The repository currently provides AdGuard Home, firewall backup, extended DDNS providers, Chinese localization, Lucky, Mihomo, reports, sing-box, Syncthing, Tailscale, ttyd and ZeroTier integrations.

## Source code

Complete project sources are under [`src/`](src/), while release packages are under [`repo/x86_64/All/`](repo/x86_64/All/).

## Disclaimer

This repository is not affiliated with or supported by the IPFire project. Third-party plugins may modify firewall, DNS, proxy or system services. Back up the configuration and test outside production first.
