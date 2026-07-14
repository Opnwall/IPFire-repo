# IPFire Community Repository

An unofficial community plugin repository for **IPFire 2.29 x86_64**. It uses an independent `ipfrepo` manager and does not replace or modify the official Pakfire repository or its GPG trust chain.

## Install the repository

Run as `root`:

```sh
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh | sh
```

## Usage

```sh
ipfrepo list
ipfrepo info adguardhome
ipfrepo install adguardhome
ipfrepo remove adguardhome
ipfrepo update
ipfrepo upgrade
```

Every package is SHA-256 verified before its own install or uninstall script is executed. State is stored under `/opt/ipfrepo/`.

## Packages

The repository currently provides AdGuard Home, firewall backup, extended DDNS providers, Chinese localization, Lucky, Mihomo, reports, sing-box, Syncthing, Tailscale, ttyd and ZeroTier integrations.

## Source code

Complete project sources are under [`src/`](src/), while release packages are under [`repo/x86_64/All/`](repo/x86_64/All/).

## Disclaimer

This repository is not affiliated with or supported by the IPFire project. Third-party plugins may modify firewall, DNS, proxy or system services. Back up the configuration and test outside production first.
