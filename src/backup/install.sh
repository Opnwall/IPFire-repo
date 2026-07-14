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

print_step "Preparing to install Firewall Backup"
echo "This will install the Firewall Backup Web UI page, menu entry, language files, and backup directory."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
	echo "Operation cancelled."
	exit 0
fi

print_step "Checking source files"
[[ -d src ]] || die "Missing directory src"
[[ -f src/srv/web/ipfire/cgi-bin/firewall_backup.cgi ]] || die "Missing file src/srv/web/ipfire/cgi-bin/firewall_backup.cgi"
[[ -f src/var/ipfire/menu.d/EX-firewall_backup.menu ]] || die "Missing file src/var/ipfire/menu.d/EX-firewall_backup.menu"
[[ -f src/var/ipfire/addon-lang/firewall_backup.de.pl ]] || die "Missing file src/var/ipfire/addon-lang/firewall_backup.de.pl"
[[ -f src/var/ipfire/addon-lang/firewall_backup.en.pl ]] || die "Missing file src/var/ipfire/addon-lang/firewall_backup.en.pl"
[[ -f src/var/ipfire/addon-lang/firewall_backup.es.pl ]] || die "Missing file src/var/ipfire/addon-lang/firewall_backup.es.pl"
[[ -f src/var/ipfire/addon-lang/firewall_backup.tw.pl ]] || die "Missing file src/var/ipfire/addon-lang/firewall_backup.tw.pl"
[[ -f src/var/ipfire/addon-lang/firewall_backup.zh.pl ]] || die "Missing file src/var/ipfire/addon-lang/firewall_backup.zh.pl"

print_step "Copying files"
for dir in srv var; do
	cp -R -f "src/$dir/." "/$dir/"
done

print_step "Setting file permissions"
chown root:root \
	/srv/web/ipfire/cgi-bin/firewall_backup.cgi \
	/var/ipfire/addon-lang/firewall_backup.de.pl \
	/var/ipfire/addon-lang/firewall_backup.en.pl \
	/var/ipfire/addon-lang/firewall_backup.es.pl \
	/var/ipfire/addon-lang/firewall_backup.tw.pl \
	/var/ipfire/addon-lang/firewall_backup.zh.pl \
	/var/ipfire/menu.d/EX-firewall_backup.menu 2>/dev/null || true

chmod 755 /srv/web/ipfire/cgi-bin/firewall_backup.cgi
chmod 644 \
	/var/ipfire/addon-lang/firewall_backup.de.pl \
	/var/ipfire/addon-lang/firewall_backup.en.pl \
	/var/ipfire/addon-lang/firewall_backup.es.pl \
	/var/ipfire/addon-lang/firewall_backup.tw.pl \
	/var/ipfire/addon-lang/firewall_backup.zh.pl \
	/var/ipfire/menu.d/EX-firewall_backup.menu

install -d -m 755 -o "$WEB_USER" -g "$WEB_GROUP" /var/ipfire/firewall_backup
touch /var/ipfire/firewall_backup/.last_run
chown "$WEB_USER:$WEB_GROUP" /var/ipfire/firewall_backup /var/ipfire/firewall_backup/.last_run
chmod 755 /var/ipfire/firewall_backup
chmod 664 /var/ipfire/firewall_backup/.last_run

print_step "Updating language cache"
/usr/local/bin/update-lang-cache >/dev/null 2>&1 || true

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Firewall Backup installation completed."
echo "Open the IPFire Web UI and go to Services > Firewall Backup."
