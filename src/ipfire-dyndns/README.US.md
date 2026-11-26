<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# DDNS Provider Patch for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> Plugin version: **1.0.4** · Target: **IPFire 2.29 Core Update 206 (x86_64)**

This package adds extra DDNS providers to IPFire's `ddns` package:

- `cloudflare.com`
- `alidns.aliyuncs.com`
- `dnspod.tencentcloudapi.com`

## Files

```text
ipfire-dyndns/
├── install.sh
├── uninstall.sh
├── README.md
├── README.US.md
├── ipfire-ddns-cloudflare.patch
└── src/patches/ddns-014-dns-provider-support.patch
```

## Installation

Copy this whole folder to the IPFire host, then run as `root`:

```sh
chmod +x install.sh uninstall.sh
./install.sh
```

The installer will:

- back up the current `providers.py` and `system.py`
- apply `src/patches/ddns-014-dns-provider-support.patch`
- run Python syntax checks
- verify the new providers are listed by `/usr/bin/ddns`

The installer discovers the active Python `ddns` package automatically. On Core Update 206, the path is:

```text
/usr/lib/python3.10/site-packages/ddns
```

To override automatic discovery:

```sh
DDNS_DIR=/path/to/ddns ./install.sh
```

## Uninstallation

Run as `root`:

```sh
./uninstall.sh
```

The uninstaller restores the latest `*.bak-cloudflare-*` backups. If backups are missing, it tries to reverse the patch.

## IPFire Web UI Usage

Go to:

```text
Services -> Dynamic DNS
```

### Cloudflare

Select:

```text
cloudflare.com
```

Fields:

- Hostname: full DNS name, for example `test.example.com`
- Token: Cloudflare API token

The token should have DNS edit permission for the zone.

### Alibaba Cloud DNS

Select:

```text
alidns.aliyuncs.com
```

Fields:

- Hostname: full DNS name, for example `test.example.com`
- Username: Alibaba Cloud `AccessKeyId`
- Password: Alibaba Cloud `AccessKeySecret`

The RAM user should have permission to query, add, and update DNS records.

### Tencent Cloud DNSPod

Select:

```text
dnspod.tencentcloudapi.com
```

Fields:

- Hostname: full DNS name, for example `test.example.com`
- Username: Tencent Cloud `SecretId`
- Password: Tencent Cloud `SecretKey`

The CAM user should have permission to query, create, and modify DNSPod records.

## Notes

- Cloudflare uses token authentication in the IPFire UI.
- Alibaba Cloud DNS and Tencent Cloud DNSPod use username/password fields.
- The providers update `A` and `AAAA` records.
- Existing DNS record TTL and line settings are preserved when possible.
- If a DNS record does not exist, the provider API creates the corresponding `A` or `AAAA` record. Verify the hostname carefully before forcing an update.
- Existing records are not deleted automatically. In particular, an existing `AAAA` record will not be removed just because the IPFire host currently has no usable IPv6 address.
- If the IPFire page still shows a hostname in red after a successful update, check local DNS cache. The record may already be correct in public DNS while the firewall's resolver still has an old negative cache entry.

## Verification

After installing:

```sh
/usr/bin/ddns list-providers | grep -E 'cloudflare.com|alidns.aliyuncs.com|dnspod.tencentcloudapi.com'
/usr/bin/ddns list-token-providers | grep cloudflare.com
```

Trigger an update manually:

```sh
/usr/local/bin/ddnsctrl update-all
```

Check logs:

```sh
grep -i 'Dynamic DNS update' /var/log/messages | tail
```

Suggested test cases before submitting or deploying widely:

- provider registration with `ddns -d list-providers`
- public IP detection with `ddns -d guess-ip-addresses`
- forced command-line update with `ddns -d update-all --force`
- public DNS result through `1.1.1.1` and `8.8.8.8`
- provider API response for the changed record
- repeated normal update when the record is already current
- invalid credentials
- missing DNS record
- IPv4-only, IPv6-only, and dual-stack records
- clean install and uninstall

## Source Patch Submission

To submit the changes to the IPFire source tree, refer to:

```text
ipfire-ddns-cloudflare.patch
```

The main patch file is:

```text
src/patches/ddns-014-dns-provider-support.patch
```

## Disclaimer

This is an unofficial community-maintained project with no affiliation to the IPFire team. Users are responsible for assessing and accepting the risks of use.
