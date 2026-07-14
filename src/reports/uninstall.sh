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

print_step "Preparing to uninstall Reports"
echo "This will remove Reports scheduled tasks, Web UI page, menu entry, language files, and report data."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
	echo "Operation cancelled."
	exit 0
fi

print_step "Removing scheduled tasks"
rm -f \
	/etc/fcron.hourly/scheduler_hourly \
	/etc/fcron.daily/scheduler_daily \
	/etc/fcron.weekly/scheduler_weekly \
	/etc/fcron.monthly/scheduler_monthly

print_step "Removing Web UI files"
rm -f \
	/srv/web/ipfire/cgi-bin/reports.cgi \
	/var/ipfire/menu.d/EX-reports.menu

print_step "Removing language files"
rm -f \
	/var/ipfire/addon-lang/reports.de.pl \
	/var/ipfire/addon-lang/reports.en.pl \
	/var/ipfire/addon-lang/reports.es.pl \
	/var/ipfire/addon-lang/reports.fr.pl \
	/var/ipfire/addon-lang/reports.it.pl \
	/var/ipfire/addon-lang/reports.tw.pl \
	/var/ipfire/addon-lang/reports.zh.pl

print_step "Removing report files"
rm -rf /var/ipfire/reports

print_step "Updating language cache"
/usr/local/bin/update-lang-cache >/dev/null 2>&1 || true

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Reports uninstall completed."
