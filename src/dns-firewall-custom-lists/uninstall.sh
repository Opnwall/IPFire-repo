#!/bin/bash
# Remove the DNS Firewall custom-list extension and restore official files.

set -Eeuo pipefail

readonly PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ORIGINAL_DIR="/var/ipfire/dns/custom-lists-original"
readonly CONFIG="/var/ipfire/dns/custom_dnsbl.json"
readonly SETTINGS="/var/ipfire/dns/dnsbl"
readonly ZONE_DIR="/var/lib/knot-resolver/zones"
readonly BACKUP_DIR="/root/dns-firewall-custom-lists-uninstall-$(date +%Y%m%d-%H%M%S)"

if [[ ${EUID} -ne 0 ]]; then
	echo "This uninstaller must be run as root." >&2
	exit 1
fi

if [[ ! -s "${ORIGINAL_DIR}/dnsbl.cgi" || ! -s "${ORIGINAL_DIR}/update-rpzs" ]]; then
	echo "Original IPFire files are missing from ${ORIGINAL_DIR}; refusing an incomplete uninstall." >&2
	exit 1
fi

perl -c "${ORIGINAL_DIR}/dnsbl.cgi" >/dev/null
bash -n "${ORIGINAL_DIR}/update-rpzs"
perl -c "${PACKAGE_DIR}/uninstall-lang-entries.pl" >/dev/null

mkdir -p "${BACKUP_DIR}/zones"
[[ ! -e "${CONFIG}" ]] || cp -a "${CONFIG}" "${BACKUP_DIR}/"
[[ ! -e "${SETTINGS}" ]] || cp -a "${SETTINGS}" "${BACKUP_DIR}/"
cp -a /srv/web/ipfire/cgi-bin/dnsbl.cgi /usr/local/bin/update-rpzs "${BACKUP_DIR}/"

if [[ -s "${CONFIG}" ]]; then
	while IFS= read -r zone; do
		[[ "${zone}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,252}$ ]] || continue
		[[ ! -e "${ZONE_DIR}/${zone}.zone" ]] || cp -a "${ZONE_DIR}/${zone}.zone" "${BACKUP_DIR}/zones/"
		if [[ -f "${SETTINGS}" ]]; then
			awk -F, -v wanted="${zone}" '$1 != wanted' "${SETTINGS}" > "${SETTINGS}.new"
			mv "${SETTINGS}.new" "${SETTINGS}"
		fi
		rm -f "${ZONE_DIR}/${zone}.zone" "${ZONE_DIR}/.${zone}.last-attempt" "${ZONE_DIR}/.${zone}.etag"
	done <<< "$(jq -r '.[] | select(.custom == true) | .zone' "${CONFIG}")"
fi

rm -f "${CONFIG}" /usr/local/bin/update-custom-rpzs /etc/fcron.minutely/update-custom-rpzs /var/ipfire/dns/rpz-update.lock

install -m 0755 "${ORIGINAL_DIR}/dnsbl.cgi" /srv/web/ipfire/cgi-bin/dnsbl.cgi
install -m 0755 "${ORIGINAL_DIR}/update-rpzs" /usr/local/bin/update-rpzs

perl "${PACKAGE_DIR}/uninstall-lang-entries.pl" /var/ipfire/langs/en.pl
perl "${PACKAGE_DIR}/uninstall-lang-entries.pl" /var/ipfire/langs/zh.pl
/usr/local/bin/update-lang-cache
/usr/local/bin/dnsctrl reload

echo "Uninstallation completed."
echo "Custom-list data backup: ${BACKUP_DIR}"
