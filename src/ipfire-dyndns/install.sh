#!/bin/sh
###############################################################################
# Install Cloudflare, Alibaba Cloud DNS, and Tencent Cloud DNSPod support
# for IPFire's ddns package.
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
	echo "This installer must be run as root." >&2
	exit 1
fi

if [ ! -f "${PATCH_FILE}" ]; then
	echo "Patch file not found: ${PATCH_FILE}" >&2
	exit 1
fi

if [ ! -f "${PROVIDERS}" ] || [ ! -f "${SYSTEM}" ]; then
	echo "Cannot find ddns Python files in ${DDNS_DIR}" >&2
	exit 1
fi

missing_provider=0
for provider in ${REQUIRED_PROVIDERS}; do
	if ! "${DDNS_BIN}" list-providers 2>/dev/null | grep -qx "${provider}"; then
		missing_provider=1
		break
	fi
done

if [ "${missing_provider}" = "0" ]; then
	if grep -q 'timestamp = int(datetime.datetime.utcnow().timestamp())' "${PROVIDERS}"; then
		timestamp=$(date +%Y%m%d%H%M%S)
		cp -a "${PROVIDERS}" "${PROVIDERS}.bak-cloudflare-${timestamp}"

		python3 - "${PROVIDERS}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
old = """\t\ttimestamp = int(datetime.datetime.utcnow().timestamp())
\t\tdate = datetime.datetime.utcfromtimestamp(timestamp).strftime("%Y-%m-%d")"""
new = """\t\tnow = datetime.datetime.now(datetime.timezone.utc)
\t\ttimestamp = int(now.timestamp())
\t\tdate = now.strftime("%Y-%m-%d")"""

if old not in text:
	raise SystemExit("DNSPod timestamp code was not found")

path.write_text(text.replace(old, new, 1))
PY
		python3 -m py_compile "${PROVIDERS}"

		echo "DNSPod timestamp handling upgraded."
		echo "Backup:"
		echo "  ${PROVIDERS}.bak-cloudflare-${timestamp}"
		exit 0
	fi

	echo "DNS provider support is already installed."
	exit 0
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
	patch -Np1 -i "${PATCH_FILE}"
)

python3 -m py_compile \
	"${tmpdir}/src/ddns/providers.py" \
	"${tmpdir}/src/ddns/system.py"

timestamp=$(date +%Y%m%d%H%M%S)
cp -a "${PROVIDERS}" "${PROVIDERS}.bak-cloudflare-${timestamp}"
cp -a "${SYSTEM}" "${SYSTEM}.bak-cloudflare-${timestamp}"

install -m 0644 "${tmpdir}/src/ddns/providers.py" "${PROVIDERS}"
install -m 0644 "${tmpdir}/src/ddns/system.py" "${SYSTEM}"

python3 -m py_compile "${PROVIDERS}" "${SYSTEM}"

for provider in ${REQUIRED_PROVIDERS}; do
	if ! "${DDNS_BIN}" list-providers | grep -qx "${provider}"; then
		echo "${provider} was not registered after installation." >&2
		exit 1
	fi
done

if ! "${DDNS_BIN}" list-token-providers | grep -qx "cloudflare.com"; then
	echo "cloudflare.com was not registered as a token provider." >&2
	exit 1
fi

echo "DNS provider support installed."
echo "Backups:"
echo "  ${PROVIDERS}.bak-cloudflare-${timestamp}"
echo "  ${SYSTEM}.bak-cloudflare-${timestamp}"
