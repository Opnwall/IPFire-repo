#!/bin/sh
###############################################################################
# Remove DNS provider support installed by install.sh.
###############################################################################

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PATCH_FILE="${SCRIPT_DIR}/src/patches/ddns-014-dns-provider-support.patch"
DDNS_DIR="${DDNS_DIR:-/usr/lib/python3.10/site-packages/ddns}"
DDNS_BIN="${DDNS_BIN:-/usr/bin/ddns}"
PROVIDERS="${DDNS_DIR}/providers.py"
SYSTEM="${DDNS_DIR}/system.py"
REQUIRED_PROVIDERS="cloudflare.com alidns.aliyuncs.com dnspod.tencentcloudapi.com"

if [ "$(id -u)" != "0" ]; then
	echo "This uninstaller must be run as root." >&2
	exit 1
fi

if [ ! -f "${PROVIDERS}" ] || [ ! -f "${SYSTEM}" ]; then
	echo "Cannot find ddns Python files in ${DDNS_DIR}" >&2
	exit 1
fi

latest_backup() {
	# shellcheck disable=SC2012
	ls -1t "$1".bak-cloudflare-* 2>/dev/null | head -n 1
}

providers_backup=$(latest_backup "${PROVIDERS}" || true)
system_backup=$(latest_backup "${SYSTEM}" || true)

if [ -n "${providers_backup}" ] && [ -n "${system_backup}" ]; then
	cp -a "${providers_backup}" "${PROVIDERS}"
	cp -a "${system_backup}" "${SYSTEM}"
	echo "Restored latest backups:"
	echo "  ${providers_backup}"
	echo "  ${system_backup}"
else
	if [ ! -f "${PATCH_FILE}" ]; then
		echo "No backups found and patch file is missing: ${PATCH_FILE}" >&2
		exit 1
	fi

	tmpdir=$(mktemp -d /tmp/ipfire-ddns-cloudflare.XXXXXX)
	cleanup() {
		rm -rf "${tmpdir}"
	}
	trap cleanup EXIT

	mkdir -p "${tmpdir}/src/ddns"
	cp -p "${PROVIDERS}" "${tmpdir}/src/ddns/providers.py"
	cp -p "${SYSTEM}" "${tmpdir}/src/ddns/system.py"

	(
		cd "${tmpdir}"
		patch -R -Np1 -i "${PATCH_FILE}"
	)

	install -m 0644 "${tmpdir}/src/ddns/providers.py" "${PROVIDERS}"
	install -m 0644 "${tmpdir}/src/ddns/system.py" "${SYSTEM}"
	echo "Removed Cloudflare support by reversing the patch."
fi

python3 -m py_compile "${PROVIDERS}" "${SYSTEM}"

for provider in ${REQUIRED_PROVIDERS}; do
	if "${DDNS_BIN}" list-providers 2>/dev/null | grep -qx "${provider}"; then
		echo "${provider} is still registered after uninstall." >&2
		exit 1
	fi
done

echo "DNS provider support uninstalled."
