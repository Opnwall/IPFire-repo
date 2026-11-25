# Speedtest for IPFire

> Plugin version: **1.0.5** · Target: **IPFire 2.29 Core Update 206 (x86_64)**
> UI languages: English / Simplified Chinese / Traditional Chinese, including Core 206 locale identifiers.

Validation on 2026-11-25: Core 206 x86_64 syntax, translation-resource and initial English/Simplified/Traditional CGI checks passed in isolation. Live service connectivity, reboot and complete install/uninstall regression were not repeated in this run.

Speedtest adds **Services > Speedtest** to IPFire. It supports outbound-interface
selection, manual server refresh and selection, configurable parallel
connections, English/Simplified Chinese/Traditional Chinese UI, and persistent
test results.

The plugin bundles the MIT-licensed `speedtest-go` 1.7.10 Linux x86_64 engine.

```sh
chmod +x install.sh uninstall.sh
./install.sh
```
