<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Localization Patch for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.8** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

This plugin targets GNU gettext in Core 206. It downloads the new `IPFire_lang.zip` from the address saved on the management page, reads the Simplified and Traditional Chinese JSON dictionaries and merges the translations into the installed catalogues. System pages no longer use the legacy `langs/zh.pl`, `addon-lang/*.zh.pl` or language-cache updater.

## Translation Files

`src/usr/local/share/ipfire-lang/zh_CN.json` and `zh_TW.json` contain reviewable supplementary translations. Installation merges each dictionary into `/usr/share/locale/<language>/LC_MESSAGES/ipfire.mo`, preserving existing contexts, plurals and metadata. Catalogues are validated before atomic replacement. The first installation preserves `ipfire.mo.before-community-zh`.

Country and territory names are based on Babel's CLDR Simplified Chinese territory data, with additional legacy codes and special regions.

## Installation

Run as root from the complete plugin directory:

```sh
bash install.sh
```

## Usage

1. Upload the new `IPFire_lang.zip` to the cloud drive.
2. Open **System > Localization Patch**.
3. Save the HTTPS direct download URL. Downloads are currently restricted to `cloud.pfchina.org`.
4. Click the localization installation button and check the installation log.

## Notes

- The plugin does not execute scripts from the downloaded archive or overwrite arbitrary paths supplied by it.
- Upstream system updates may replace translation catalogues and display adaptations; reinstall the patch if needed.
- When system source code changes, recheck the source patterns used by display adaptations before applying them.

## Disclaimer

This is an unofficial community-maintained project with no affiliation to the IPFire team. Users are responsible for assessing and accepting the risks of use.
