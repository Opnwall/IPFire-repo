#!/bin/sh
set -eu

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log() {
	printf '%b%s%b\n' "$1" "$2" "$RESET"
}

cleanup_old_webui_csp() {
	for conf in /etc/httpd/conf/vhosts.d/ipfire-interface.conf /etc/httpd/conf/vhosts.d/ipfire-interface-ssl.conf; do
		[ -f "$conf" ] || continue
		sed -i "s# https://\\*:16601##g" "$conf"
		sed -i "s#; frame-src 'self' https://\\*:16601##g" "$conf"
		rm -f "${conf}.lucky.bak"
	done

	apachectl -k graceful >/dev/null 2>&1 || /etc/rc.d/init.d/apache restart >/dev/null 2>&1 || true
}

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this installer as root."
	exit 1
fi

log "$GREEN" "====== Lucky for IPFire installer ======"

log "$YELLOW" "Stopping old service..."
/etc/rc.d/init.d/lucky stop >/dev/null 2>&1 || true

if [ ! -d src ]; then
	echo "Missing src directory. Run this installer from the lucky for IPFire project directory."
	exit 1
fi

log "$YELLOW" "Copying project files..."
for dir in etc opt srv var; do
	cp -R -f "src/$dir/." "/$dir/"
done

log "$YELLOW" "Setting permissions..."
chown root:root /etc/rc.d/init.d/lucky /etc/sysconfig/lucky /srv/web/ipfire/cgi-bin/lucky.cgi 2>/dev/null || true
chown -R root:root /opt/lucky /var/ipfire/lucky 2>/dev/null || true
chmod 0755 /etc/rc.d/init.d/lucky 2>/dev/null || true
chmod 0755 /srv/web/ipfire/cgi-bin/lucky.cgi 2>/dev/null || true
chmod 0755 /opt/lucky/bin/lucky 2>/dev/null || true
chmod 0644 /etc/sysconfig/lucky 2>/dev/null || true
chmod 0644 /var/ipfire/menu.d/EX-lucky.menu 2>/dev/null || true
chown nobody:nobody /var/ipfire/menu.d/EX-lucky.menu 2>/dev/null || true
mkdir -p /var/ipfire/lucky/conf

log "$YELLOW" "Registering service autostart..."
ln -sf ../init.d/lucky /etc/rc.d/rc3.d/S98lucky
ln -sf ../init.d/lucky /etc/rc.d/rc0.d/K02lucky
ln -sf ../init.d/lucky /etc/rc.d/rc6.d/K02lucky

log "$YELLOW" "Cleaning old Lucky iframe CSP rule..."
cleanup_old_webui_csp

if [ -x /opt/lucky/bin/lucky ]; then
	/opt/lucky/bin/lucky -v >/opt/lucky/VERSION 2>/dev/null || echo "v2.27.2" >/opt/lucky/VERSION
else
	log "$RED" "Lucky binary is missing at /opt/lucky/bin/lucky."
fi

log "$YELLOW" "Starting service..."
if /etc/rc.d/init.d/lucky start; then
	log "$GREEN" "Installation complete. Refresh the IPFire WebUI and open Services > Lucky."
else
	log "$RED" "Installation finished, but Lucky did not start. Check /var/log/lucky.log."
fi
