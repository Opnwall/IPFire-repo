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

WEB_USER="nobody"
if ! WEB_GROUP="$(id -gn "$WEB_USER" 2>/dev/null)"; then
    die "Web service user $WEB_USER was not found."
fi

print_step "Preparing to install Mihomo"
echo "This will install Mihomo, the Web UI page, the menu entry, and reload the Web service."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

print_step "Checking source files"
[[ -d src ]] || die "Missing directory src"
[[ -f src/etc/rc.d/init.d/mihomo ]] || die "Missing file src/etc/rc.d/init.d/mihomo"
[[ -f src/usr/local/bin/mihomo ]] || die "Missing file src/usr/local/bin/mihomo"
[[ -f src/usr/local/etc/mihomo/config.yaml ]] || die "Missing file src/usr/local/etc/mihomo/config.yaml"
[[ -f src/srv/web/ipfire/cgi-bin/mihomo.cgi ]] || die "Missing file src/srv/web/ipfire/cgi-bin/mihomo.cgi"
[[ -f src/var/ipfire/menu.d/82-mihomo.menu ]] || die "Missing file src/var/ipfire/menu.d/82-mihomo.menu"
[[ -f src/etc/sudoers.d/mihomo ]] || die "Missing file src/etc/sudoers.d/mihomo"

print_step "Stopping old service"
/etc/rc.d/init.d/mihomo stop >/dev/null 2>&1 || true

print_step "Copying files"
tmp_config=""
if [[ -f /usr/local/etc/mihomo/config.yaml ]]; then
    tmp_config="$(mktemp /tmp/mihomo-config.backup.XXXXXX)"
    cp -p /usr/local/etc/mihomo/config.yaml "$tmp_config"
fi

for dir in etc srv usr var; do
    cp -R -f "src/$dir/." "/$dir/"
done

if [[ -n "$tmp_config" && -f "$tmp_config" ]]; then
    install -m 660 "$tmp_config" /usr/local/etc/mihomo/config.yaml
    rm -f "$tmp_config"
fi

print_step "Setting file permissions"
chown root:root /etc/rc.d/init.d/mihomo /etc/sudoers.d/mihomo /usr/local/bin/mihomo /srv/web/ipfire/cgi-bin/mihomo.cgi 2>/dev/null || true
chmod 755 /etc/rc.d/init.d/mihomo
chmod +x /usr/local/bin/mihomo
chmod +x /srv/web/ipfire/cgi-bin/mihomo.cgi
chmod 440 /etc/sudoers.d/mihomo
chmod 644 /var/ipfire/menu.d/82-mihomo.menu 2>/dev/null || true
chown nobody:nobody /var/ipfire/menu.d/82-mihomo.menu 2>/dev/null || true
if [[ -d /usr/local/etc/mihomo/ui ]]; then
    chmod -R a+rX /usr/local/etc/mihomo/ui
fi
if grep -Eq '^secret:[[:space:]]*(change-me|mihomo-change-me)$' /usr/local/etc/mihomo/config.yaml; then
    mihomo_secret="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    sed -i "s/^secret:.*/secret: ${mihomo_secret}/" /usr/local/etc/mihomo/config.yaml
fi
touch /usr/local/etc/mihomo/config.yaml.bak
chown "$WEB_USER:$WEB_GROUP" /usr/local/etc/mihomo/config.yaml /usr/local/etc/mihomo/config.yaml.bak
chmod 660 /usr/local/etc/mihomo/config.yaml /usr/local/etc/mihomo/config.yaml.bak

install -d -m 755 /var/run/mihomo
touch /var/log/mihomo.log
chmod 644 /var/log/mihomo.log

print_step "Configuring startup"
ln -sf /etc/rc.d/init.d/mihomo /etc/rc.d/rc3.d/S99mihomo

print_step "Configuring sudo permissions"
if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers.d/mihomo >/dev/null
fi

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Mihomo installation completed."
echo "Open the IPFire Web UI and go to Services > Mihomo."
