#!/bin/sh
# tailscale uninstall script
set -eu

print_step() {
    echo
    echo "==> $1"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: please run this script as root." >&2
    exit 1
fi

print_step "Preparing Tailscale removal"
echo "This will remove Tailscale binaries, Web UI, startup links, runtime files, and configuration files."
printf "Continue? (y/N): "
read -r confirm
case "$confirm" in
    [Yy]) ;;
    *)
    echo "Operation cancelled."
    exit 0
    ;;
esac

print_step "Stopping Tailscale service"
    /etc/init.d/tailscale stop >/dev/null 2>&1 || true

print_step "Removing startup link"
rm -f /etc/rc.d/rc3.d/S99tailscale

print_step "Removing firewall rules"
while iptables -C FORWARD -i tailscale0 -j ACCEPT 2>/dev/null; do
    iptables -D FORWARD -i tailscale0 -j ACCEPT || break
done
while iptables -C FORWARD -o tailscale0 -j ACCEPT 2>/dev/null; do
    iptables -D FORWARD -o tailscale0 -j ACCEPT || break
done

print_step "Removing program files"
rm -f /etc/init.d/tailscale
rm -f /usr/local/bin/tailscale
rm -f /usr/sbin/tailscaled
rm -f /srv/web/ipfire/cgi-bin/tailscale.cgi
rm -f /var/ipfire/menu.d/83-tailscale.menu

print_step "Removing runtime files"
rm -rf /var/run/tailscale
rm -f /var/log/tailscale.log
rm -f /etc/sudoers.d/tailscale

print_step "Removing configuration files"
rm -rf /var/ipfire/tailscale

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Tailscale removal complete."
