#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SRC_DIR="$BASE_DIR/src"

print_step() {
    echo
    echo "==> $1"
}

remove_installed_payload_file() {
    source_path="$1"
    relative_path="${source_path#"$SRC_DIR"/}"
    rm -f "/$relative_path"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root." >&2
    exit 1
fi

print_step "Preparing to uninstall AdGuard Home"
echo "This will remove AdGuard Home service files, Web UI files, menu entry, runtime files, and configuration."
printf "Continue? (y/N): "
read -r confirm
case "$confirm" in
    [Yy]) ;;
    *) echo "Operation cancelled."; exit 0 ;;
esac

print_step "Stopping AdGuard Home service"
/etc/rc.d/init.d/adguardhome stop >/dev/null 2>&1 || true

print_step "Removing startup links"
rm -f /etc/rc.d/rc3.d/S98adguardhome
rm -f /etc/rc.d/rc0.d/K02adguardhome
rm -f /etc/rc.d/rc6.d/K02adguardhome

print_step "Removing installed files"
remove_installed_payload_file "$SRC_DIR/etc/rc.d/init.d/adguardhome"
remove_installed_payload_file "$SRC_DIR/srv/web/ipfire/cgi-bin/adguardhome.cgi"
remove_installed_payload_file "$SRC_DIR/var/ipfire/menu.d/82-adguardhome.menu"
remove_installed_payload_file "$SRC_DIR/var/ipfire/adguardhome/settings"
rm -f /etc/sudoers.d/adguardhome
rm -rf /opt/adguardhome

print_step "Removing runtime and configuration"
rm -f /var/run/adguardhome.pid
rm -f /var/log/adguardhome.log
rm -rf /var/ipfire/adguardhome
rm -rf /var/lib/adguardhome

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "AdGuard Home uninstallation completed."
