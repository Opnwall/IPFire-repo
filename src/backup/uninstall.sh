#!/bin/bash
set -euo pipefail

print_step() {
	echo
	echo "==> $1"
}

if [[ $EUID -ne 0 ]]; then
	echo "Error: Please run this script as root." >&2
	exit 1
fi

print_step "Preparing to uninstall Firewall Backup"
echo "This will remove the Firewall Backup Web UI page, menu entry, language files, and backup data."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
	echo "Operation cancelled."
	exit 0
fi

print_step "Removing Web UI files"
rm -f \
	/srv/web/ipfire/cgi-bin/firewall_backup.cgi \
	/var/ipfire/menu.d/EX-firewall_backup.menu

print_step "Removing language files"
rm -f \
	/var/ipfire/addon-lang/firewall_backup.de.pl \
	/var/ipfire/addon-lang/firewall_backup.en.pl \
	/var/ipfire/addon-lang/firewall_backup.es.pl \
	/var/ipfire/addon-lang/firewall_backup.tw.pl \
	/var/ipfire/addon-lang/firewall_backup.zh.pl

print_step "Removing backup data"
rm -rf /var/ipfire/firewall_backup

print_step "Updating language cache"
/usr/local/bin/update-lang-cache >/dev/null 2>&1 || true

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Firewall Backup uninstall completed."
