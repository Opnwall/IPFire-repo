<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# sing-box for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.5** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

sing-box is an open-source network proxy platform supporting multiple proxy protocols. It provides flexible configuration for proxying, traffic routing, load balancing and secure access.

This plugin integrates sing-box into the IPFire Web UI, with transparent proxying, configuration editing, service management, status monitoring and log viewing.

## Included Software

[sing-box](https://github.com/SagerNet/sing-box/releases).

## Notes

1. The current package supports x86_64 only.
2. Default settings are included; adapt the node information to your environment.
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

1. Open **Services > Sing-Box**, edit the configuration and save it.
2. Click **Start** and use the logs to identify and fix configuration errors.
3. After startup, visit `ip111.cn` from a client to check traffic routing.

## Additional Information

1. The plugin provides boot autostart support.
2. The default configuration enables the API. Open `http://lan_ip:9090/ui` to access the dashboard.

## Disclaimer

This is an unofficial community project with no affiliation to the IPFire team. You are responsible for its use and any resulting risks.
