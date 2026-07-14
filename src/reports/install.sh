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

print_step "Preparing to install Reports"
echo "This will install Reports, scheduled tasks, language files, and the Web UI menu entry."
read -r -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
	echo "Operation cancelled."
	exit 0
fi

print_step "Checking source files"
[[ -d src ]] || die "Missing directory src"
[[ -f src/etc/fcron.hourly/scheduler_hourly ]] || die "Missing file src/etc/fcron.hourly/scheduler_hourly"
[[ -f src/etc/fcron.daily/scheduler_daily ]] || die "Missing file src/etc/fcron.daily/scheduler_daily"
[[ -f src/etc/fcron.weekly/scheduler_weekly ]] || die "Missing file src/etc/fcron.weekly/scheduler_weekly"
[[ -f src/etc/fcron.monthly/scheduler_monthly ]] || die "Missing file src/etc/fcron.monthly/scheduler_monthly"
[[ -f src/srv/web/ipfire/cgi-bin/reports.cgi ]] || die "Missing file src/srv/web/ipfire/cgi-bin/reports.cgi"
[[ -f src/var/ipfire/menu.d/EX-reports.menu ]] || die "Missing file src/var/ipfire/menu.d/EX-reports.menu"
[[ -f src/var/ipfire/reports/settings ]] || die "Missing file src/var/ipfire/reports/settings"
[[ -f src/var/ipfire/addon-lang/reports.zh.pl ]] || die "Missing file src/var/ipfire/addon-lang/reports.zh.pl"
[[ -f src/var/ipfire/addon-lang/reports.tw.pl ]] || die "Missing file src/var/ipfire/addon-lang/reports.tw.pl"

print_step "Copying files"
tmp_settings=""
if [[ -f /var/ipfire/reports/settings ]]; then
	tmp_settings="$(mktemp /tmp/reports-settings.backup.XXXXXX)"
	cp -p /var/ipfire/reports/settings "$tmp_settings"
fi

for dir in etc srv var; do
	cp -R -f "src/$dir/." "/$dir/"
done

if [[ -n "$tmp_settings" && -f "$tmp_settings" ]]; then
	install -m 660 "$tmp_settings" /var/ipfire/reports/settings
	rm -f "$tmp_settings"
fi

print_step "Setting file permissions"
chown root:root \
	/etc/fcron.hourly/scheduler_hourly \
	/etc/fcron.daily/scheduler_daily \
	/etc/fcron.weekly/scheduler_weekly \
	/etc/fcron.monthly/scheduler_monthly \
	/srv/web/ipfire/cgi-bin/reports.cgi \
	/var/ipfire/addon-lang/reports.de.pl \
	/var/ipfire/addon-lang/reports.en.pl \
	/var/ipfire/addon-lang/reports.es.pl \
	/var/ipfire/addon-lang/reports.fr.pl \
	/var/ipfire/addon-lang/reports.it.pl \
	/var/ipfire/addon-lang/reports.tw.pl \
	/var/ipfire/addon-lang/reports.zh.pl \
	/var/ipfire/menu.d/EX-reports.menu \
	/var/ipfire/reports/*.sh \
	/var/ipfire/reports/report-lib.sh 2>/dev/null || true

chmod 755 \
	/var/ipfire/reports/fw-report.sh \
	/var/ipfire/reports/ids-report.sh \
	/var/ipfire/reports/url-report.sh \
	/var/ipfire/reports/dnsfw-report.sh \
	/var/ipfire/reports/send_mail.sh \
	/etc/fcron.hourly/scheduler_hourly \
	/etc/fcron.daily/scheduler_daily \
	/etc/fcron.weekly/scheduler_weekly \
	/etc/fcron.monthly/scheduler_monthly \
	/srv/web/ipfire/cgi-bin/reports.cgi

chmod 644 \
	/var/ipfire/reports/report-lib.sh \
	/var/ipfire/addon-lang/reports.de.pl \
	/var/ipfire/addon-lang/reports.en.pl \
	/var/ipfire/addon-lang/reports.es.pl \
	/var/ipfire/addon-lang/reports.fr.pl \
	/var/ipfire/addon-lang/reports.it.pl \
	/var/ipfire/addon-lang/reports.tw.pl \
	/var/ipfire/addon-lang/reports.zh.pl \
	/var/ipfire/menu.d/EX-reports.menu

install -d -m 755 -o "$WEB_USER" -g "$WEB_GROUP" /var/ipfire/reports /var/ipfire/reports/reports
touch \
	/var/ipfire/reports/reports/fw-report.html \
	/var/ipfire/reports/reports/ids-report.html \
	/var/ipfire/reports/reports/url-report.html \
	/var/ipfire/reports/reports/dnsfw-report.html

chown "$WEB_USER:$WEB_GROUP" \
	/var/ipfire/reports \
	/var/ipfire/reports/reports \
	/var/ipfire/reports/settings \
	/var/ipfire/reports/reports/fw-report.html \
	/var/ipfire/reports/reports/ids-report.html \
	/var/ipfire/reports/reports/url-report.html \
	/var/ipfire/reports/reports/dnsfw-report.html

chmod 755 /var/ipfire/reports /var/ipfire/reports/reports
chmod 660 /var/ipfire/reports/settings
chmod 664 /var/ipfire/reports/reports/*.html

print_step "Updating language cache"
/usr/local/bin/update-lang-cache >/dev/null 2>&1 || true

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Reports installation completed."
echo "Open the IPFire Web UI and go to Services > Reports."
