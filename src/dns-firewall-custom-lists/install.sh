#!/bin/bash
# Install the DNS Firewall custom-list community plugin on IPFire 2.29 Core 203.

set -Eeuo pipefail

readonly PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly BACKUP_DIR="/root/dns-firewall-custom-lists-backup-$(date +%Y%m%d-%H%M%S)"
readonly LOCK_FILE="/var/ipfire/dns/rpz-update.lock"
readonly ORIGINAL_DIR="/var/ipfire/dns/custom-lists-original"

if [[ ${EUID} -ne 0 ]]; then
	echo "This installer must be run as root." >&2
	exit 1
fi

for command in jq curl flock perl; do
	command -v "${command}" >/dev/null || {
		echo "Required command is missing: ${command}" >&2
		exit 1
	}
done

if [[ ! -f /srv/web/ipfire/cgi-bin/dnsbl.cgi || ! -f /usr/local/bin/update-rpzs ]]; then
	echo "This system does not appear to contain the IPFire DNS Firewall files." >&2
	exit 1
fi

core="$(cat /opt/pakfire/db/core/mine 2>/dev/null || true)"
if [[ "${core}" != "203" ]]; then
	echo "Unsupported IPFire Core Update: ${core:-unknown}. This package was tested on Core 203." >&2
	exit 1
fi

echo
echo "==> Preparing to install DNS Firewall Custom Lists"
echo "This will extend the built-in DNS Firewall and preserve the official files for removal."
read -r -p "Continue? (y/N): " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
	echo "Operation cancelled."
	exit 0
fi

perl -c "${PACKAGE_DIR}/src/srv/web/ipfire/cgi-bin/dnsbl.cgi" >/dev/null
bash -n "${PACKAGE_DIR}/src/usr/local/bin/update-rpzs"
perl -c "${PACKAGE_DIR}/install-lang-entries.pl" >/dev/null
perl -c "${PACKAGE_DIR}/uninstall-lang-entries.pl" >/dev/null

# Preserve the pre-extension CGI and official updater once. Upgrades must never
# overwrite this baseline, because uninstall.sh uses it for restoration.
if [[ ! -s "${ORIGINAL_DIR}/dnsbl.cgi" || ! -s "${ORIGINAL_DIR}/update-rpzs" ]]; then
	mkdir -p "${ORIGINAL_DIR}"
	oldest_backup="$(find /root -maxdepth 1 -type d -name 'dns-firewall-custom-lists-backup-*' | LC_ALL=C sort | head -n 1)"
	if [[ -n "${oldest_backup}" && -s "${oldest_backup}/cgi/dnsbl.cgi" && -s "${oldest_backup}/bin/update-rpzs" ]]; then
		cp -a "${oldest_backup}/cgi/dnsbl.cgi" "${ORIGINAL_DIR}/dnsbl.cgi"
		cp -a "${oldest_backup}/bin/update-rpzs" "${ORIGINAL_DIR}/update-rpzs"
	else
		cp -a /srv/web/ipfire/cgi-bin/dnsbl.cgi "${ORIGINAL_DIR}/dnsbl.cgi"
		cp -a /usr/local/bin/update-rpzs "${ORIGINAL_DIR}/update-rpzs"
	fi
	chmod 0755 "${ORIGINAL_DIR}/dnsbl.cgi" "${ORIGINAL_DIR}/update-rpzs"
fi

mkdir -p "${BACKUP_DIR}/cgi" "${BACKUP_DIR}/bin" "${BACKUP_DIR}/lang" "${BACKUP_DIR}/fcron" "${BACKUP_DIR}/dns"
cp -a /srv/web/ipfire/cgi-bin/dnsbl.cgi "${BACKUP_DIR}/cgi/"
cp -a /usr/local/bin/update-rpzs "${BACKUP_DIR}/bin/"
[[ ! -e /usr/local/bin/update-custom-rpzs ]] || cp -a /usr/local/bin/update-custom-rpzs "${BACKUP_DIR}/bin/"
cp -a /var/ipfire/langs/en.pl /var/ipfire/langs/zh.pl "${BACKUP_DIR}/lang/"
[[ ! -e /etc/fcron.minutely/update-custom-rpzs ]] || cp -a /etc/fcron.minutely/update-custom-rpzs "${BACKUP_DIR}/fcron/"
[[ ! -e /var/ipfire/dns/custom_dnsbl.json ]] || cp -a /var/ipfire/dns/custom_dnsbl.json "${BACKUP_DIR}/dns/"

install -m 0755 "${PACKAGE_DIR}/src/srv/web/ipfire/cgi-bin/dnsbl.cgi" /srv/web/ipfire/cgi-bin/dnsbl.cgi
install -m 0755 "${PACKAGE_DIR}/src/usr/local/bin/update-rpzs" /usr/local/bin/update-rpzs

# Custom HTTPS feeds now use the official update-rpzs entrypoint. Remove the
# legacy standalone updater and its minutely scheduler after backing them up.
rm -f /usr/local/bin/update-custom-rpzs /etc/fcron.minutely/update-custom-rpzs

perl "${PACKAGE_DIR}/install-lang-entries.pl" /var/ipfire/langs/en.pl "${PACKAGE_DIR}/lang/en.pl"
perl "${PACKAGE_DIR}/install-lang-entries.pl" /var/ipfire/langs/zh.pl "${PACKAGE_DIR}/lang/zh.pl"
/usr/local/bin/update-lang-cache

if [[ ! -s /var/ipfire/dns/custom_dnsbl.json ]]; then
	printf '[]\n' > /var/ipfire/dns/custom_dnsbl.json
fi
jq 'map(del(.update_interval))' /var/ipfire/dns/custom_dnsbl.json > /var/ipfire/dns/custom_dnsbl.json.new
mv /var/ipfire/dns/custom_dnsbl.json.new /var/ipfire/dns/custom_dnsbl.json
chmod 0644 /var/ipfire/dns/custom_dnsbl.json

while IFS= read -r zone; do
	[[ "${zone}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,252}$ ]] || continue
	rm -f "/var/lib/knot-resolver/zones/.${zone}.last-attempt"
done <<< "$(jq -r '.[] | select(.custom == true) | .zone' /var/ipfire/dns/custom_dnsbl.json)"

touch "${LOCK_FILE}"
chown root:nobody "${LOCK_FILE}"
chmod 0660 "${LOCK_FILE}"

perl -c /srv/web/ipfire/cgi-bin/dnsbl.cgi >/dev/null
bash -n /usr/local/bin/update-rpzs
/usr/local/bin/dnsctrl reload

echo "Installation completed."
echo "Backup: ${BACKUP_DIR}"
echo "Open: https://<ipfire-address>:444/cgi-bin/dnsbl.cgi"
