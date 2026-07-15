#!/bin/bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Error: Please run this script as root." >&2; exit 1; }
echo "This will remove Speedtest and all saved test data."
read -r -p "Continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Operation cancelled."; exit 0; }

rm -f \
    /usr/local/bin/ipfire-speedtest \
    /usr/local/sbin/ipfire-speedtestctl \
    /srv/web/ipfire/cgi-bin/speedtest.cgi \
    /etc/sudoers.d/speedtest \
    /var/ipfire/menu.d/EX-speedtest.menu \
    /var/ipfire/addon-lang/speedtest.en.pl \
    /var/ipfire/addon-lang/speedtest.zh.pl \
    /var/ipfire/addon-lang/speedtest.tw.pl
rm -rf /var/ipfire/speedtest
/usr/local/bin/update-lang-cache >/dev/null 2>&1 || true
/etc/init.d/apache reload >/dev/null 2>&1 || true
echo "Speedtest uninstall completed."
