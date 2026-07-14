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

print_step "Preparing to install ZeroTier"
echo "This will install zerotier-one, zerotier-cli, the Web UI page, the menu entry, and reload the Web service."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

print_step "Checking source files"
[[ -d src ]] || die "Missing directory src"
[[ -f src/etc/rc.d/init.d/zerotier ]] || die "Missing file src/etc/rc.d/init.d/zerotier"
[[ -f src/srv/web/ipfire/cgi-bin/zerotier.cgi ]] || die "Missing file src/srv/web/ipfire/cgi-bin/zerotier.cgi"
[[ -f src/usr/sbin/zerotier-one ]] || die "Missing file src/usr/sbin/zerotier-one"
[[ -f src/usr/local/bin/zerotier-cli ]] || die "Missing file src/usr/local/bin/zerotier-cli"
[[ -f src/etc/sudoers.d/zerotier ]] || die "Missing file src/etc/sudoers.d/zerotier"

print_step "Stopping old service"
/etc/rc.d/init.d/zerotier stop >/dev/null 2>&1 || true

print_step "Copying files"
tmp_settings=""
tmp_state=""
if [[ -f /var/ipfire/zerotier/settings ]]; then
    tmp_settings="$(mktemp /tmp/zerotier-settings.backup.XXXXXX)"
    cp -p /var/ipfire/zerotier/settings "$tmp_settings"
fi
if [[ -f /var/ipfire/zerotier/state ]]; then
    tmp_state="$(mktemp /tmp/zerotier-state.backup.XXXXXX)"
    cp -p /var/ipfire/zerotier/state "$tmp_state"
fi

for dir in etc srv usr var; do
    cp -R -f "src/$dir/." "/$dir/"
done

if [[ -n "$tmp_settings" && -f "$tmp_settings" ]]; then
    install -m 600 "$tmp_settings" /var/ipfire/zerotier/settings
    rm -f "$tmp_settings"
fi
if [[ -n "$tmp_state" && -f "$tmp_state" ]]; then
    install -m 600 "$tmp_state" /var/ipfire/zerotier/state
    rm -f "$tmp_state"
fi

print_step "Setting file permissions"
chown root:root /etc/rc.d/init.d/zerotier /etc/sudoers.d/zerotier /usr/sbin/zerotier-one /usr/local/bin/zerotier-cli /srv/web/ipfire/cgi-bin/zerotier.cgi 2>/dev/null || true
chmod 755 /etc/rc.d/init.d/zerotier /usr/sbin/zerotier-one /usr/local/bin/zerotier-cli /srv/web/ipfire/cgi-bin/zerotier.cgi 2>/dev/null || true
chmod 440 /etc/sudoers.d/zerotier
chmod 644 /var/ipfire/menu.d/83-zerotier.menu 2>/dev/null || true
chown nobody:nobody /var/ipfire/menu.d/83-zerotier.menu 2>/dev/null || true

install -d -m 700 /var/lib/zerotier-one
install -d -m 755 /var/ipfire/zerotier
[[ -f /var/ipfire/zerotier/settings ]] || touch /var/ipfire/zerotier/settings
[[ -f /var/ipfire/zerotier/state ]] || touch /var/ipfire/zerotier/state
chown -R root:root /var/ipfire/zerotier
chmod 700 /var/ipfire/zerotier
chmod 600 /var/ipfire/zerotier/settings /var/ipfire/zerotier/state

touch /var/log/zerotier.log
chown root:root /var/log/zerotier.log
chmod 600 /var/log/zerotier.log

print_step "Configuring startup"
ln -sf /etc/rc.d/init.d/zerotier /etc/rc.d/rc3.d/S99zerotier

print_step "Configuring sudo permissions"
visudo -cf /etc/sudoers.d/zerotier >/dev/null || die "sudoers validation failed"

print_step "Adding forwarding rules"
iptables -C FORWARD -i zt+ -j ACCEPT 2>/dev/null || iptables -A FORWARD -i zt+ -j ACCEPT
iptables -C FORWARD -o zt+ -j ACCEPT 2>/dev/null || iptables -A FORWARD -o zt+ -j ACCEPT
grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 >/dev/null

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "ZeroTier installation completed."
echo "Open the IPFire Web UI and go to Services > ZeroTier VPN."
