<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Mihomo for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.5** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

Mihomo is an open-source proxy engine compatible with the Clash configuration format. It supports multiple proxy protocols, rule-based routing, DNS management, load balancing and transparent proxying.

This plugin runs Mihomo on IPFire and provides transparent proxy functionality.

## Included Software

[Mihomo](https://github.com/metacubex/mihomo).

## Notes

1. The current package supports x86_64 only.
2. The scripts include default settings; replace the proxy and rule sections with your own configuration.
3. After troubleshooting, set the log level to `error` to reduce retained logs during long-term operation.

## Installation

Log in as root and run:

```sh
bash install.sh
```

## Uninstallation

Log in as root and run:

```sh
bash uninstall.sh
```

## Configuration

1. Open **Services > Mihomo**, edit the configuration and save it.
2. Click **Start** and use the logs to identify and fix configuration errors.

## Additional Information

1. The plugin provides boot autostart support.
2. The default configuration enables the API. Open `http://lan_ip:9090/ui` to access the Mihomo dashboard (metacubexd).

## Disclaimer

This is an unofficial community project with no affiliation to the IPFire team. You are responsible for its use and any resulting risks.
