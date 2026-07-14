#!/bin/bash
# ZeroTier uninstall script
set -euo pipefail

print_step() {
    echo
    echo "==> $1"
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run this script as root." >&2
    exit 1
fi

print_step "Preparing to uninstall ZeroTier"
echo "This will remove ZeroTier binaries, the Web UI page, startup entry, runtime files, and configuration files."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

print_step "Stopping ZeroTier service"
/etc/init.d/zerotier stop >/dev/null 2>&1 || true

print_step "Removing startup entry"
rm -f /etc/rc.d/rc3.d/S99zerotier

print_step "Removing program files"
rm -f /etc/init.d/zerotier
rm -f /usr/local/bin/zerotier-cli
rm -f /usr/sbin/zerotier-one
rm -f /srv/web/ipfire/cgi-bin/zerotier.cgi
rm -f /var/ipfire/menu.d/83-zerotier.menu

print_step "Removing runtime files"
rm -rf /var/lib/zerotier-one
rm -f /var/log/zerotier.log
rm -f /etc/sudoers.d/zerotier

print_step "Cleaning network rules"
iptables -D FORWARD -i zt+ -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o zt+ -j ACCEPT 2>/dev/null || true
sed -i '/^net\.ipv4\.ip_forward=1$/d' /etc/sysctl.conf 2>/dev/null || true

print_step "Removing configuration files"
rm -rf /var/ipfire/zerotier

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "ZeroTier uninstall completed."
