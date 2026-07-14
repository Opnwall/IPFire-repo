#!/bin/sh
set -eu

BASE_URL="${OPNWALL_BASE_URL:-https://opnwall.github.io/IPFire-repo}"

[ "$(id -u)" -eq 0 ] || {
    echo "error: this installer must be run as root" >&2
    exit 1
}

fetch_file() {
    if command -v curl >/dev/null 2>&1; then
        curl --retry 3 --retry-delay 2 --connect-timeout 20 -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 --timeout=20 -O "$2" "$1"
    else
        echo "error: curl or wget is required" >&2
        exit 1
    fi
}

tmp="$(mktemp /tmp/opnwall.XXXXXX)"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
fetch_file "$BASE_URL/opnwall" "$tmp"
grep -q '^BASE_URL=' "$tmp" || {
    echo "error: invalid Opnwall manager download" >&2
    exit 1
}
install -m 0755 "$tmp" /usr/local/bin/opnwall
ln -sfn /usr/local/bin/opnwall /usr/bin/opnwall
mkdir -p /opt/opnwall/db/installed /opt/opnwall/cache
/usr/local/bin/opnwall update
echo "Opnwall IPFire community repository installed."
echo "Run: opnwall list"
