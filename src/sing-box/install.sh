#!/bin/bash
set -euo pipefail

print_step() {
    echo
    echo "==> $1"
}

die() {
    echo "Error: $1" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    die "Please run this script as root."
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

print_step "Preparing to install sing-box"
echo "This will install sing-box, the Web UI page, the menu entry, and reload the Web service."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

print_step "Checking source files"
[[ -d src ]] || die "Missing directory src"
[[ -f src/etc/rc.d/init.d/sing-box ]] || die "Missing file src/etc/rc.d/init.d/sing-box"
[[ -f src/usr/local/bin/sing-box ]] || die "Missing file src/usr/local/bin/sing-box"
[[ -f src/usr/local/etc/sing-box/config.json ]] || die "Missing file src/usr/local/etc/sing-box/config.json"
[[ -f src/srv/web/ipfire/cgi-bin/sing-box.cgi ]] || die "Missing file src/srv/web/ipfire/cgi-bin/sing-box.cgi"
[[ -f src/var/ipfire/menu.d/81-singbox.menu ]] || die "Missing file src/var/ipfire/menu.d/81-singbox.menu"
[[ -f src/etc/sudoers.d/sing-box ]] || die "Missing file src/etc/sudoers.d/sing-box"

print_step "Stopping old service"
/etc/rc.d/init.d/sing-box stop >/dev/null 2>&1 || true

print_step "Copying files"
tmp_config=""
if [[ -f /usr/local/etc/sing-box/config.json ]]; then
    tmp_config="$(mktemp /tmp/sing-box-config.backup.XXXXXX)"
    cp -p /usr/local/etc/sing-box/config.json "$tmp_config"
fi

for dir in etc srv usr var; do
    cp -R -f "src/$dir/." "/$dir/"
done

if [[ -n "$tmp_config" && -f "$tmp_config" ]]; then
    install -m 660 "$tmp_config" /usr/local/etc/sing-box/config.json
    rm -f "$tmp_config"
fi

print_step "Setting file permissions"
chown root:root /etc/rc.d/init.d/sing-box /etc/sudoers.d/sing-box /usr/local/bin/sing-box /srv/web/ipfire/cgi-bin/sing-box.cgi 2>/dev/null || true
chmod 755 /etc/rc.d/init.d/sing-box
chmod +x /usr/local/bin/sing-box
chmod +x /srv/web/ipfire/cgi-bin/sing-box.cgi
chmod 440 /etc/sudoers.d/sing-box
chmod 644 /var/ipfire/menu.d/81-singbox.menu 2>/dev/null || true
chown nobody:nobody /var/ipfire/menu.d/81-singbox.menu 2>/dev/null || true
if grep -q '"secret": "change-this-secret"' /usr/local/etc/sing-box/config.json; then
    singbox_secret="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    sed -i "s/\"secret\": \"change-this-secret\"/\"secret\": \"${singbox_secret}\"/" /usr/local/etc/sing-box/config.json
fi
chown root:nobody /usr/local/etc/sing-box/config.json
chmod 660 /usr/local/etc/sing-box/config.json

install -d -m 755 /var/run/sing-box
touch /var/log/sing-box.log
chown root:nobody /var/log/sing-box.log
chmod 664 /var/log/sing-box.log

print_step "Configuring startup"
ln -sf /etc/rc.d/init.d/sing-box /etc/rc.d/rc3.d/S99sing-box

print_step "Configuring sudo permissions"
visudo -cf /etc/sudoers.d/sing-box >/dev/null

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "sing-box installation completed."
echo "Open the IPFire Web UI and go to Services > Sing-Box."
