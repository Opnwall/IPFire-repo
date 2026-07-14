#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this uninstaller as root."
	exit 1
fi

/etc/rc.d/init.d/lucky stop >/dev/null 2>&1 || true

for conf in /etc/httpd/conf/vhosts.d/ipfire-interface.conf /etc/httpd/conf/vhosts.d/ipfire-interface-ssl.conf; do
	if [ -f "${conf}.lucky.bak" ]; then
		mv -f "${conf}.lucky.bak" "$conf"
	elif [ -f "$conf" ]; then
		sed -i "s# https://\\*:16601##g" "$conf"
		sed -i "s#; frame-src 'self' https://\\*:16601##g" "$conf"
	fi
done
apachectl -k graceful >/dev/null 2>&1 || /etc/rc.d/init.d/apache restart >/dev/null 2>&1 || true

rm -f \
	/etc/rc.d/init.d/lucky \
	/etc/rc.d/rc3.d/S98lucky \
	/etc/rc.d/rc0.d/K02lucky \
	/etc/rc.d/rc6.d/K02lucky \
	/etc/sysconfig/lucky \
	/srv/web/ipfire/cgi-bin/lucky.cgi \
	/var/ipfire/menu.d/EX-lucky.menu \
	/var/log/lucky.log \
	/run/lucky.pid

rm -rf /opt/lucky

echo "Lucky for IPFire has been uninstalled. Configuration data remains in /var/ipfire/lucky/conf."
