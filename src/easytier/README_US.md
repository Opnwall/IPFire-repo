<div align="center">
  <a href="README.md">中文</a> |
  <a href="README_US.md">English</a>
</div>

# EasyTier for IPFire

A community EasyTier mesh VPN plugin for IPFire. Configure a network name, password and peers through the Web UI to connect devices across locations and optionally access remote LANs.

This is not an official IPFire or EasyTier plugin.

## Compatibility

| Item | Details |
| --- | --- |
| Plugin version | 1.0.0 |
| Bundled binaries | EasyTier 2.6.4 core / CLI |
| Validated system | IPFire 2.29 Core Update 204 |
| Architecture | x86_64 |
| Menu | Services → EasyTier |
| UI languages | Simplified Chinese, Traditional Chinese and English, following the GUI setting |

The installer accepts only this Core version and architecture. This package is not suitable for ARM or other Core versions.

## Features

- Join a private network using a network name and password. Passwords are not displayed; a blank password on save preserves the existing value.
- Automatic or static virtual IPv4, multiple peers and optional TCP/UDP listeners.
- Advertise IPv4 subnets reachable through this device.
- Start, stop, restart and optional automatic startup.
- Horizontally scrollable peer and route tables.
- Optional WAN access synchronized with native IPFire firewall rules.
- Optional bidirectional GREEN/BLUE forwarding and LAN source NAT.

No shared credentials or public relay are preconfigured. On a fresh installation the service is stopped; automatic startup, WAN access, LAN forwarding and NAT are disabled.

## Installation

Back up IPFire first; take a VM snapshot where applicable and retain SSH or console access. Run the following commands as root on IPFire.

For first-time repository users, download and review the repository installer before running it:

```sh
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh -o /tmp/install-ipfrepo.sh
sh /tmp/install-ipfrepo.sh
```

Install EasyTier:

```sh
ipfrepo update
ipfrepo install easytier
```

Skip repository setup if ipfrepo is already installed. The client verifies the package SHA-256. See the [community repository](https://opnwall.github.io/IPFire-repo/) for available packages.

For offline installation, download and verify the archive, transfer it to IPFire, then run:

```sh
tar -xzf easytier-1.0.0-x86_64.tar.gz
cd easytier
bash install.sh
```

Open **Services → EasyTier** after confirming installation. Unmanaged conflicting files are not overwritten. Upgrades retain plugin settings but stop the service.

## Quick setup

1. Enter the same network name and password as the other members.
2. Enter a reachable peer, one per line, such as `tcp://vpn.example.net:11010`.
3. Keep automatic virtual addressing enabled, or disable it and assign an unused static address such as `10.126.0.10/24`.
4. Click Save, then Start.
5. Check Peers and Routes for connectivity and advertised subnets.
6. Verify connectivity and management access before enabling automatic startup or additional permissions.

Automatic addresses may change after a restart. Use a verified unused static address when a stable endpoint is needed.

## Configuration

| Setting | Description |
| --- | --- |
| Network name | Private network identifier, shared by members |
| Network password | Private network password; blank preserves the saved value |
| Virtual IPv4 | Static address/prefix, such as 10.126.0.10/24; empty in automatic mode |
| Listener port | Configures TCP/UDP listeners; 0 means no configured transport listeners |
| Automatic virtual IP | Select a virtual IPv4 automatically |
| Start at boot | Start with IPFire |
| Allow WAN listener port | Allow the configured nonzero listener port |
| Enable LAN forwarding | Allow bidirectional traffic between local GREEN/BLUE and the VPN |
| LAN source NAT | Translate LAN traffic leaving through the tunnel to the VPN address; requires forwarding |
| Peers | One URL per line; tcp, udp, ws, wss and quic are accepted |
| Advertised IPv4 subnets | Publish reachable subnets, such as 192.168.50.0/24 |

**Save does not restart the process, but applies firewall options immediately.** Restart after changing network identity, virtual addressing, peers, listener port or advertised subnets.

## WAN access

An outbound-only node can generally leave listeners and WAN access disabled. To accept connections, set a nonzero listener port and enable WAN access.

Two native entries appear under **Firewall → Firewall Rules**:

```text
EasyTier managed WAN TCP
EasyTier managed WAN UDP
```

They match the RED interface, firewall RED address and configured port. Saving, starting/stopping, changing the port or uninstalling synchronizes these entries. Manage them through EasyTier; do not manually edit, rename or copy them, or reuse their remarks on unrelated rules.

If IPFire is behind another router, configure upstream port forwarding as required. The management RPC is not exposed by this option.

## LAN forwarding

To preserve client addresses, enable LAN forwarding without NAT and ensure:

- Clients or their default gateway route remote subnets through IPFire.
- The remote side has a return route to local GREEN/BLUE subnets.
- Firewalls and destination services permit access.

Advertising a subnet does not configure client/upstream routes or grant firewall permission.

### Remote access

If IPFire can access a remote website but LAN clients cannot, try enabling both **LAN forwarding** and **LAN source NAT**.

NAT matches only local GREEN/BLUE source subnets and traffic actually leaving through `easytier0`. It accommodates changing remote subnet advertisements and includes VPN virtual addresses; ordinary WAN traffic is not translated.

Remote devices see IPFire's VPN address instead of the original client address. NAT does not create routes or fix subnet conflicts, unavailable services or every remote access restriction.

LAN/NAT use dedicated ETIER_FORWARD and ETIER_NAT chains, restored through a managed block in /etc/sysconfig/firewall.local. They do not appear as separate native firewall entries. Disabling the options, stopping or uninstalling cleans up the corresponding rules.

## Important notes

- Avoid overlapping networks: remote advertisements must not duplicate local GREEN/BLUE subnets, and virtual addresses must not conflict with existing LANs or VPNs.
- LAN forwarding grants trusted VPN members bidirectional access to local GREEN/BLUE; it does not automatically include ORANGE/RED forwarding.
- The plugin does not explicitly rewrite DNS, default routes or global forwarding sysctls. EasyTier can learn member-advertised routes, so trust every member of the private network.
- The interface is fixed at easytier0 and management RPC at 127.0.0.1:15889; avoid conflicts with other software.
- The GUI requires authenticated administrator HTTPS access and provides POST/CSRF checks, field validation and password redaction.
- Configuration, logs and uninstall backups may contain secrets. Do not publish them.

## Troubleshooting

```sh
/usr/local/sbin/easytierctrl status
/usr/local/sbin/easytierctrl peers
/usr/local/sbin/easytierctrl routes
tail -n 80 /var/log/easytier.log
```

If ping succeeds but Web access fails, compare tests from IPFire and a LAN client to distinguish service, firewall and return-routing issues. Verify the destination identity before accepting HTTPS certificate warnings.

If SSH/Web management becomes unreachable, stop the service from the local console, then inspect overlapping subnets, learned routes and client gateways:

```sh
/usr/local/sbin/easytierctrl stop
```

Once management is restored, disable automatic startup or relevant options as needed. Do not mask routing problems by broadly opening firewall permissions.

## Uninstall

For repository-managed installations:

```sh
ipfrepo remove easytier
```

For offline installations, run from the extracted plugin directory:

```sh
bash uninstall.sh
```

Uninstall stops the service, backs up settings to /root/easytier-uninstall.XXXXXX/config/, and removes plugin programs, menu, sudo rules, startup entries, managed firewall rules and hooks. Root-only /var/log/easytier.log and configuration backups are retained. Shared TUN modules are not unloaded.

## Upstream and license

- [EasyTier project](https://github.com/EasyTier/EasyTier)
- [Bundled v2.6.4 release](https://github.com/EasyTier/EasyTier/releases/tag/v2.6.4)
- [Source provenance](UPSTREAM-SOURCE.md)
- [Upstream LGPL-3.0 license](UPSTREAM-LICENSE.txt)
