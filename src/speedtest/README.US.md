<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Speedtest for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.5** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

Speedtest adds a test page to IPFire's **Services** menu to measure the connection speed from the firewall itself to internet test servers.

## Features

- Automatically selects the outbound interface or lets you select an interface with an IPv4 default route and a global IPv4 address.
- Refreshes the server list manually and supports automatic or manual server selection.
- Supports 1–16 parallel connections.
- Displays download speed, upload speed, latency, jitter and packet loss, depending on the data returned by the server and engine.
- Displays the test time, ISP, public IP address, server and distance.
- Runs tests in the background while the page polls for progress.
- Saves the latest result and settings from successful tests; saved results can be cleared.
- Retries once with automatic server selection after the first test fails.

Tests use the bundled speedtest-go engine; no separate engine download is required during installation. The device must be able to reach the internet and test servers.

## Installation

### Community Repository

With the community repository and `ipfrepo` configured, run as root:

```sh
ipfrepo update
ipfrepo install speedtest
```

### Manual Installation

Download and extract the plugin archive, enter the `speedtest` directory containing `install.sh` and run as root:

```sh
chmod +x install.sh uninstall.sh
./install.sh
```

Enter `y` to confirm. The installer copies the engine, Web page, menu, language resources and permission configuration, then attempts to reload the Web service.

After installation, open **Services > Speedtest** or `/cgi-bin/speedtest.cgi` on the management interface.

## Usage

1. Select an outbound interface; **Automatic** is usually suitable.
2. Click **Refresh Servers**. Refresh the list again after changing the interface.
3. Keep automatic server selection or select a server from the list.
4. Set the number of connections and click **Start Test**.
5. Wait for the results. Click **Clear Result** to remove the saved result.

Download and upload speeds are displayed in **Mbps**, and latency and jitter in **ms**. Tests consume internet bandwidth. Results depend on server load, the network path, device performance and the number of connections.

This plugin measures the connection from IPFire to internet servers. Test LAN clients' Wi-Fi or Ethernet performance separately.

## File Locations

| Purpose | Path |
| --- | --- |
| Management page | `/srv/web/ipfire/cgi-bin/speedtest.cgi` |
| Test engine | `/usr/local/bin/ipfire-speedtest` |
| Management helper | `/usr/local/sbin/ipfire-speedtestctl` |
| Settings, server cache and latest result | `/var/ipfire/speedtest/` |
| Latest result file | `/var/ipfire/speedtest/result.json` |

## Troubleshooting

**No outbound interfaces, or an interface is missing:** Check for an IPv4 default route and a global IPv4 address on the interface. Interface filtering currently uses IPv4 routes.

**Unable to retrieve servers:** Check IPFire's DNS resolution, internet connection and outbound access policies, then refresh the list. Server retrieval has a 45-second timeout.

**Tests fail or take a long time:** Try automatic server selection, refresh the server list or reduce the number of connections. Each engine invocation has a 120-second timeout and is retried once on failure, so the total wait can exceed two minutes.

**The interface language does not change:** Check the IPFire GUI language setting and reopen the page. The plugin recognizes English and the Simplified/Traditional Chinese locale identifiers used by Core 206.

## Uninstallation

Run as root from the extracted plugin directory:

```sh
./uninstall.sh
```

After confirmation, uninstallation removes the page, engine, menu, permissions and language resources. **It also deletes the settings, server cache and results in `/var/ipfire/speedtest/`.** Back up any data you want to keep first.

## Third-Party License

The bundled speedtest-go engine uses the MIT license. A copy is included at `third_party/speedtest-go.LICENSE`.

## Disclaimer

This is an unofficial community-maintained project with no affiliation to the IPFire team. Users are responsible for assessing and accepting the risks of use.
