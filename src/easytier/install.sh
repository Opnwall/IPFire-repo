#!/bin/bash
set -euo pipefail
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[[ $(id -u) == 0 && $(uname -m) == x86_64 ]] || { echo 'Requires root on x86_64'; exit 1; }
[[ $(cat /opt/pakfire/db/core/mine) == 204 ]] || { echo 'Validated for Core 204 only'; exit 1; }
for file in easytier-core easytier-cli; do
    [[ $(od -An -tx1 -N4 "$base/src/usr/local/bin/$file" | tr -d ' \n') == 7f454c46 ]] || exit 1
done
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$base/src/usr/local/sbin/easytierctrl"
visudo -cf "$base/src/etc/sudoers.d/easytier"
echo 'Install EasyTier? Service will not start automatically. (y/N)'
read -r answer; [[ $answer == y || $answer == Y ]] || exit 0
if [[ -e /var/ipfire/easytier && ! -f /var/ipfire/easytier/.plugin-owned ]]; then
    echo 'Unmanaged EasyTier directory exists; refusing overwrite'; exit 1
fi
if [[ ! -f /var/ipfire/easytier/.plugin-owned ]]; then
    for target in /usr/local/bin/easytier-core /usr/local/bin/easytier-cli /usr/local/sbin/easytierctrl /etc/rc.d/init.d/easytier /etc/sudoers.d/easytier /srv/web/ipfire/cgi-bin/easytier.cgi /var/ipfire/menu.d/83-easytier.menu; do
        [[ ! -e $target && ! -L $target ]] || { echo "Existing unmanaged file: $target"; exit 1; }
    done
fi
if [[ -x /usr/local/sbin/easytierctrl ]]; then /usr/local/sbin/easytierctrl stop; fi
install -d -m750 -o root -g nobody /var/ipfire/easytier
install -d -m700 /run/easytier
for file in easytier-core easytier-cli; do install -m755 "$base/src/usr/local/bin/$file" "/usr/local/bin/$file"; done
install -m755 "$base/src/usr/local/sbin/easytierctrl" /usr/local/sbin/easytierctrl
install -m755 "$base/src/etc/rc.d/init.d/easytier" /etc/rc.d/init.d/easytier
install -m755 "$base/src/srv/web/ipfire/cgi-bin/easytier.cgi" /srv/web/ipfire/cgi-bin/easytier.cgi
install -m644 "$base/src/var/ipfire/menu.d/83-easytier.menu" /var/ipfire/menu.d/83-easytier.menu
install -m440 "$base/src/etc/sudoers.d/easytier" /etc/sudoers.d/easytier
if [[ ! -e /var/ipfire/easytier/csrf.key ]]; then
    umask 027; openssl rand -hex 32 > /var/ipfire/easytier/csrf.key
fi
chown root:nobody /var/ipfire/easytier/csrf.key
chmod 640 /var/ipfire/easytier/csrf.key
touch /var/ipfire/easytier/.plugin-owned
/usr/local/sbin/easytierctrl hook-install
/etc/init.d/apache reload
echo 'Installed: Services > EasyTier. Configure network name, password and peers, then start.'
