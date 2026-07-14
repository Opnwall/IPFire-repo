#!/bin/sh
set -eu

BASE_URL="${IPFREPO_BASE_URL:-https://opnwall.github.io/IPFire-repo}"

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

tmp="$(mktemp /tmp/ipfrepo.XXXXXX)"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
fetch_file "$BASE_URL/ipfrepo" "$tmp"
grep -q '^BASE_URL=' "$tmp" || {
    echo "error: invalid ipfrepo manager download" >&2
    exit 1
}
if [ -d /opt/opnwall ]; then
    if [ -e /opt/ipfrepo ]; then
        cp -a /opt/opnwall/. /opt/ipfrepo/
        rm -rf /opt/opnwall
    else
        mv /opt/opnwall /opt/ipfrepo
    fi
fi
rm -f /usr/local/bin/opnwall /usr/bin/opnwall
install -m 0755 "$tmp" /usr/local/bin/ipfrepo
ln -sfn /usr/local/bin/ipfrepo /usr/bin/ipfrepo
mkdir -p /opt/ipfrepo/db/installed /opt/ipfrepo/cache
/usr/local/bin/ipfrepo update
echo "IPFire community repository installed."
echo "Run: ipfrepo list"
