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

print_step "Preparing to uninstall Syncthing"
echo "This will remove Syncthing service files, Web UI files, menu entry, runtime files, and configuration."
printf "Continue? (y/N): "
read -r confirm
case "$confirm" in
    [Yy]) ;;
    *) echo "Operation cancelled."; exit 0 ;;
esac

print_step "Stopping Syncthing service"
/etc/rc.d/init.d/syncthing stop >/dev/null 2>&1 || true

print_step "Removing startup links"
rm -f /etc/rc.d/rc3.d/S99syncthing
rm -f /etc/rc.d/rc0.d/K01syncthing
rm -f /etc/rc.d/rc6.d/K01syncthing

print_step "Removing installed files"
remove_installed_payload_file "$SRC_DIR/etc/rc.d/init.d/syncthing"
remove_installed_payload_file "$SRC_DIR/usr/local/bin/syncthing"
remove_installed_payload_file "$SRC_DIR/srv/web/ipfire/cgi-bin/syncthing.cgi"
remove_installed_payload_file "$SRC_DIR/var/ipfire/menu.d/84-syncthing.menu"
rm -f /etc/sudoers.d/syncthing

print_step "Removing runtime and configuration"
rm -f /var/run/syncthing.pid
rm -f /var/log/syncthing.log
rm -rf /var/ipfire/syncthing
rm -rf /var/lib/syncthing

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Syncthing uninstallation completed."
