#!/bin/bash
# Mihomo uninstall script
set -euo pipefail

print_step() {
    echo
    echo "==> $1"
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run this script as root." >&2
    exit 1
fi

print_step "Preparing to uninstall Mihomo"
echo "This will remove Mihomo binaries, the Web UI page, startup entry, runtime files, and configuration files."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

print_step "Stopping Mihomo service"
/etc/init.d/mihomo stop >/dev/null 2>&1 || true

print_step "Removing startup entry"
rm -f /etc/rc.d/rc3.d/S99mihomo

print_step "Removing program files"
rm -f /etc/init.d/mihomo
rm -f /usr/local/bin/mihomo
rm -f /srv/web/ipfire/cgi-bin/mihomo.cgi
rm -f /var/ipfire/menu.d/82-mihomo.menu

print_step "Removing runtime files"
rm -rf /var/run/mihomo
rm -f /var/log/mihomo.log
rm -f /etc/sudoers.d/mihomo

print_step "Removing configuration files"
rm -rf /usr/local/etc/mihomo

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Mihomo uninstall completed."
