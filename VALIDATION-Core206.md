# Core 206 release validation — 2026-11-25

All sixteen catalog packages are published for IPFire 2.29 Core Update 206 x86_64. Package versions and SHA-256 values are generated from their final sources. Each package includes a source manifest.

## Passed checks

- 38 shell scripts passed `bash -n`.
- 108 isolated checks on a Core 206 device passed: 24 Perl syntax checks, 42 English/Simplified/Traditional translation-resource checks and 42 initial CGI output checks across fourteen UI plugins.
- Core 206 domain validation uses `Network::check_fqdn` with a gated legacy fallback; valid and invalid domain checks passed.
- Report shell output was checked separately in English, Simplified Chinese and Traditional Chinese.
- The four missing legacy language keys found during testing were supplied in all three languages. The DNS custom-list plugin now installs isolated English/Simplified/Traditional dictionaries and does not require the removed core language cache.
- Report generation recognizes `zh_CN`/`zh-CN` and `zh_TW`/`zh-TW`. Captive error/coupon language selection uses the same aliases.
- The DDNS provider patch applies cleanly to Core 206's installed Python source and compiles. DDNS keeps the native upstream multilingual web interface.
- Localization 1.0.6 successfully downloaded the 20,552-byte patch from the existing cloud share, installed both 532-entry supplements, and retained 2,589 entries per language. Each redirect receives its own cache-busting query, avoiding stale Cloudflare objects. Six major pages per language were separately checked after installation.
- Every final archive is checked against its source manifest and catalog SHA-256; official download directories retain one current archive per plugin.

## Limits

CGI checks used the actual Core 206 Perl modules and gettext backend with per-process language selection; stateful UI checks used private state copies. They did not install or start every network service on the user's live firewall. Service binary upgrades, complete install/uninstall restoration, reboot, external provider API transactions, VPN peering, portal authentication, all form submissions and all error branches were not retested as part of this compatibility release. Existing data and service binaries are retained.

The source dictionaries use the GPL-licensed IPFire Core 204 translation data only as a fallback for removed legacy keys; native Core 206 gettext strings take precedence. The compatibility loaders do not replace `/var/ipfire/lang.pl` or the native gettext catalogs.

本次通过 Core 206 隔离语法、英简繁资源和初始页面输出检查；不等同于全部服务的完整功能、重启及安装卸载回归测试。汉化插件的真实远程下载和简繁安装已在设备上验证。
