#!/bin/bash
# sing-box uninstall script
set -euo pipefail

print_step() {
    echo
    echo "==> $1"
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run this script as root." >&2
    exit 1
fi

print_step "Preparing to uninstall sing-box"
echo "This will remove sing-box binaries, the Web UI page, startup entry, runtime files, and configuration files."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

print_step "Stopping sing-box service"
/etc/init.d/sing-box stop >/dev/null 2>&1 || true

print_step "Removing startup entry"
rm -f /etc/rc.d/rc3.d/S99sing-box

print_step "Removing program files"
rm -f /etc/init.d/sing-box
rm -f /usr/local/bin/sing-box
rm -f /srv/web/ipfire/cgi-bin/sing-box.cgi
rm -f /var/ipfire/menu.d/81-singbox.menu
rm -f /etc/sudoers.d/sing-box

print_step "Removing runtime files"
rm -rf /var/run/sing-box
rm -f /var/log/sing-box.log

print_step "Removing configuration files"
rm -rf /usr/local/etc/sing-box

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "sing-box uninstall completed."
