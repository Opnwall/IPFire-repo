#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this uninstaller as root."
	exit 1
fi

/etc/rc.d/init.d/ttyd stop >/dev/null 2>&1 || true

for conf in /etc/httpd/conf/vhosts.d/ipfire-interface.conf /etc/httpd/conf/vhosts.d/ipfire-interface-ssl.conf; do
	if [ -f "${conf}.ttyd.bak" ]; then
		mv -f "${conf}.ttyd.bak" "$conf"
	elif [ -f "$conf" ]; then
		sed -i "s#; frame-src 'self' https://\\*:7681##g" "$conf"
	fi
done
apachectl -k graceful >/dev/null 2>&1 || /etc/rc.d/init.d/apache restart >/dev/null 2>&1 || true

if [ -f /opt/pakfire/db/installed/meta-ttyd ] && grep -q '^X-ttyd-for-ipfire-local: yes$' /opt/pakfire/db/installed/meta-ttyd; then
	rm -f /opt/pakfire/db/installed/meta-ttyd
elif [ -f /opt/pakfire/db/installed/meta-ttyd.services-local ] && [ -f /opt/pakfire/db/installed/meta-ttyd ]; then
	if grep -qx 'Services: ttyd' /opt/pakfire/db/installed/meta-ttyd.services-local; then
		sed -i '/^Services: ttyd$/d' /opt/pakfire/db/installed/meta-ttyd
	fi
fi
rm -f /opt/pakfire/db/installed/meta-ttyd.services-local
if [ -f /opt/pakfire/db/lists/packages_list.db.ttyd-local ] && [ -f /opt/pakfire/db/lists/packages_list.db ]; then
	if grep -qx 'ttyd;1.7.7;1;' /opt/pakfire/db/lists/packages_list.db.ttyd-local; then
		sed -i '/^ttyd;1\.7\.7;1;$/d' /opt/pakfire/db/lists/packages_list.db
	fi
	rm -f /opt/pakfire/db/lists/packages_list.db.ttyd-local
fi

rm -f \
	/etc/rc.d/init.d/ttyd \
	/etc/rc.d/rc3.d/S99ttyd \
	/etc/rc.d/rc3.d/off/S99ttyd \
	/etc/rc.d/rc0.d/K01ttyd \
	/etc/rc.d/rc6.d/K01ttyd \
	/etc/sysconfig/ttyd \
	/srv/web/ipfire/cgi-bin/ttyd.cgi \
	/var/ipfire/menu.d/EX-ttyd.menu \
	/etc/sudoers.d/ttyd \
	/var/log/ttyd.log \
	/run/ttyd.pid

rm -rf /opt/ttyd
rm -f /opt/pakfire/db/rootfiles/ttyd

echo "ttyd for IPFire has been uninstalled."
