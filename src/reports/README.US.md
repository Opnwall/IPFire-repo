<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Reports for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.7** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

This plugin integrates Reports into the IPFire Web UI to generate and view firewall, IDS, URL Filter and DNS Firewall reports.

## Features

- Integration with the IPFire Web UI **Services** menu.
- Firewall, IDS, URL Filter and DNS Firewall reports.
- Responsive HTML reports, SVG charts and email-safe report bodies.
- Statistics for firewall attack patterns, IDS severity, URL categories and DNS Firewall lists.
- Hourly, daily, weekly and monthly scheduled jobs.
- Integrated language resources, including complete Simplified Chinese report translations for IPFire's `LANGUAGE=zh` setting.

## Installation

Log in as root and run in the plugin directory:

```sh
bash install.sh
```

## Uninstallation

Log in as root and run in the plugin directory:

```sh
bash uninstall.sh
```

## Access

After installation, open:

```text
Services > Reports
```

## Project Structure

```text
src/
install.sh
uninstall.sh
```

The installer copies files from `src/` to the IPFire root filesystem and sets permissions for the CGI page, scheduled jobs, report directory and language files.

## Disclaimer

This is an unofficial community-maintained project with no affiliation to the IPFire team. Users are responsible for assessing and accepting the risks of use.
