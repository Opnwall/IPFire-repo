#!/bin/sh
set -eu

NAME="${NAME:-ttyd}"

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log() {
	printf '%b%s%b\n' "$1" "$2" "$RESET"
}

patch_webui_csp() {
	for conf in /etc/httpd/conf/vhosts.d/ipfire-interface.conf /etc/httpd/conf/vhosts.d/ipfire-interface-ssl.conf; do
		[ -f "$conf" ] || continue
		grep -q "Content-Security-Policy" "$conf" || continue
		grep -q "frame-src 'self' https://\\*:7681" "$conf" && continue

		cp -p "$conf" "${conf}.ttyd.bak" 2>/dev/null || true
		sed -i "s#img-src 'self' data:#img-src 'self' data:; frame-src 'self' https://*:7681#g" "$conf"
	done

	apachectl -k graceful >/dev/null 2>&1 || /etc/rc.d/init.d/apache restart >/dev/null 2>&1 || true
}

write_pakfire_metadata() {
	meta_file="/opt/pakfire/db/installed/meta-ttyd"

	if [ -f "$meta_file" ]; then
		if ! grep -q '^Services:' "$meta_file"; then
			printf '%s\n' 'Services: ttyd' >> "$meta_file"
			printf '%s\n' 'Services: ttyd' > /opt/pakfire/db/installed/meta-ttyd.services-local
		fi
		return 0
	fi

	mkdir -p /opt/pakfire/db/installed
	cat > "$meta_file" <<'EOF'
Name: ttyd
ProgVersion: 1.7.7
Release: 1
Size: 0
Dependencies:
Services: ttyd
Summary: Browser terminal service for IPFire
X-ttyd-for-ipfire-local: yes
EOF
}

write_pakfire_package_list_entry() {
	list_file="/opt/pakfire/db/lists/packages_list.db"
	marker_file="/opt/pakfire/db/lists/packages_list.db.ttyd-local"

	mkdir -p /opt/pakfire/db/lists
	touch "$list_file"

	if ! grep -q '^ttyd;' "$list_file"; then
		printf '%s\n' 'ttyd;1.7.7;1;' >> "$list_file"
		printf '%s\n' 'ttyd;1.7.7;1;' > "$marker_file"
	fi
}

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this installer as root."
	exit 1
fi

log "$GREEN" "====== ttyd for IPFire installer ======"

log "$YELLOW" "Stopping old service..."
/etc/rc.d/init.d/ttyd stop >/dev/null 2>&1 || true

if [ ! -d src ]; then
	echo "Missing src directory. Run this installer from the ttyd for IPFire project directory."
	exit 1
fi
[ -f src/etc/sudoers.d/ttyd ] || {
	echo "Missing file: src/etc/sudoers.d/ttyd"
	exit 1
}

log "$YELLOW" "Copying project files..."
for dir in etc opt srv var; do
	cp -R -f "src/$dir/." "/$dir/"
done

log "$YELLOW" "Setting permissions..."
chown root:root /etc/rc.d/init.d/ttyd /etc/sudoers.d/ttyd /etc/sysconfig/ttyd /srv/web/ipfire/cgi-bin/ttyd.cgi 2>/dev/null || true
chown -R root:root /opt/ttyd 2>/dev/null || true
chmod 0755 /etc/rc.d/init.d/ttyd 2>/dev/null || true
chmod 0755 /srv/web/ipfire/cgi-bin/ttyd.cgi 2>/dev/null || true
chmod 0440 /etc/sudoers.d/ttyd 2>/dev/null || true
chmod 0644 /etc/sysconfig/ttyd 2>/dev/null || true
chmod 0644 /var/ipfire/menu.d/EX-ttyd.menu 2>/dev/null || true
chown nobody:nobody /var/ipfire/menu.d/EX-ttyd.menu 2>/dev/null || true
chmod 0755 /opt/ttyd/bin/ttyd 2>/dev/null || true

log "$YELLOW" "Registering service controls..."
mkdir -p /etc/rc.d/rc3.d/off
rm -f /etc/rc.d/rc3.d/S99ttyd /etc/rc.d/rc3.d/off/S99ttyd
ln -sf /etc/rc.d/init.d/ttyd /etc/rc.d/rc3.d/off/S99ttyd
ln -sf /etc/rc.d/init.d/ttyd /etc/rc.d/rc0.d/K01ttyd
ln -sf /etc/rc.d/init.d/ttyd /etc/rc.d/rc6.d/K01ttyd
write_pakfire_metadata
write_pakfire_package_list_entry

log "$YELLOW" "Configuring WebUI service control permissions..."
install -d -m 755 /etc/sudoers.d
visudo -cf /etc/sudoers.d/ttyd >/dev/null || {
	rm -f /etc/sudoers.d/ttyd
	log "$RED" "sudoers validation failed."
	exit 1
}

log "$YELLOW" "Allowing ttyd iframe in IPFire WebUI CSP..."
patch_webui_csp

if ! command -v /opt/ttyd/bin/ttyd >/dev/null 2>&1 && \
   ! command -v /usr/bin/ttyd >/dev/null 2>&1 && \
   ! command -v /usr/local/bin/ttyd >/dev/null 2>&1; then
	log "$YELLOW" "ttyd binary is not bundled. Place ttyd at /opt/ttyd/bin/ttyd or install it separately before starting the service."
fi

log "$GREEN" "Installation complete. ttyd is installed but not running and is disabled at boot by default."
log "$GREEN" "Refresh the IPFire WebUI and open Services > ttyd or Status > Services to start it when needed."
