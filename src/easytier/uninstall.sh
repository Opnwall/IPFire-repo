#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]] || exit 1
[[ -f /var/ipfire/easytier/.plugin-owned ]] || { echo 'No plugin-owned installation'; exit 1; }
echo 'Uninstall EasyTier? A root-only configuration backup will be retained. (y/N)'
read -r answer; [[ $answer == y || $answer == Y ]] || exit 0
/usr/local/sbin/easytierctrl stop
/usr/local/sbin/easytierctrl hook-remove
backup=$(mktemp -d /root/easytier-uninstall.XXXXXX)
cp -a /var/ipfire/easytier "$backup/config"
if [[ -L /etc/rc.d/rc3.d/S95easytier && $(readlink /etc/rc.d/rc3.d/S95easytier) == /etc/rc.d/init.d/easytier ]]; then
    rm /etc/rc.d/rc3.d/S95easytier
fi
rm -f /usr/local/bin/easytier-core /usr/local/bin/easytier-cli /usr/local/sbin/easytierctrl
rm -f /etc/rc.d/init.d/easytier /etc/sudoers.d/easytier /srv/web/ipfire/cgi-bin/easytier.cgi /var/ipfire/menu.d/83-easytier.menu
rm -rf /var/ipfire/easytier /run/easytier
/etc/init.d/apache reload
echo "Removed plugin; private configuration backup: $backup"
