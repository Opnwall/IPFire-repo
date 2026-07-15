#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSET="$BASE_DIR/src/usr/local/bin/speedtest-go_1.7.10_Linux_x86_64.tar.gz"
TMPDIR=""
die(){ echo "Error: $*" >&2; exit 1; }
cleanup(){ [[ -z "$TMPDIR" || ! -d "$TMPDIR" ]] || rm -rf "$TMPDIR"; }
trap cleanup EXIT

[[ $EUID -eq 0 ]] || die "Please run this script as root."
echo "This will install Speedtest, its Web UI page, menu entry, and helper command."
read -r -p "Continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Operation cancelled."; exit 0; }

for file in \
    "$ASSET" \
    "$BASE_DIR/src/usr/local/sbin/ipfire-speedtestctl" \
    "$BASE_DIR/src/srv/web/ipfire/cgi-bin/speedtest.cgi" \
    "$BASE_DIR/src/etc/sudoers.d/speedtest" \
    "$BASE_DIR/src/var/ipfire/menu.d/EX-speedtest.menu"; do
    [[ -f "$file" ]] || die "Missing required file: ${file#$BASE_DIR/}"
done

echo "==> Installing bundled speedtest-go engine"
TMPDIR="$(mktemp -d /tmp/ipfire-speedtest.XXXXXX)"
tar -xzf "$ASSET" -C "$TMPDIR"
ENGINE="$(find "$TMPDIR" -type f -name speedtest-go | head -1)"
[[ -n "$ENGINE" ]] || die "speedtest-go was not found in the bundled archive"
[[ "$(od -An -tx1 -N4 "$ENGINE" | tr -d ' \n')" == 7f454c46 ]] || die "Bundled engine is not an ELF executable"
install -d -m 755 /usr/local/bin /usr/local/sbin /etc/sudoers.d
install -m 755 "$ENGINE" /usr/local/bin/ipfire-speedtest
install -m 755 "$BASE_DIR/src/usr/local/sbin/ipfire-speedtestctl" /usr/local/sbin/ipfire-speedtestctl

echo "==> Installing Web UI and menu"
for dir in etc srv var; do cp -R -f "$BASE_DIR/src/$dir/." "/$dir/"; done
install -d -m 755 -o root -g root /var/ipfire/speedtest
chown root:root \
    /usr/local/bin/ipfire-speedtest /usr/local/sbin/ipfire-speedtestctl \
    /srv/web/ipfire/cgi-bin/speedtest.cgi /etc/sudoers.d/speedtest \
    /var/ipfire/menu.d/EX-speedtest.menu /var/ipfire/addon-lang/speedtest.*.pl
chmod 755 /usr/local/bin/ipfire-speedtest /usr/local/sbin/ipfire-speedtestctl /srv/web/ipfire/cgi-bin/speedtest.cgi
chmod 440 /etc/sudoers.d/speedtest
chmod 644 /var/ipfire/menu.d/EX-speedtest.menu /var/ipfire/addon-lang/speedtest.*.pl
visudo -cf /etc/sudoers.d/speedtest >/dev/null || die "sudoers validation failed"

echo "==> Updating IPFire Web UI"
/usr/local/bin/update-lang-cache >/dev/null 2>&1 || true
/etc/init.d/apache reload >/dev/null 2>&1 || true
echo "Speedtest installation completed. Open Services > Speedtest."
