#!/bin/sh
set -eu

# Plain-text configuration: never source a repository URL as shell code.
CONFIG_FILE="/opt/ipfrepo/repository.url"
DEFAULT_BASE_URL="https://opnwall.github.io/IPFire-repo"
BASE_URL="${IPFREPO_BASE_URL:-}"
if [ -z "$BASE_URL" ] && [ -f "$CONFIG_FILE" ]; then
    BASE_URL="$(cat "$CONFIG_FILE")"
fi
BASE_URL="${BASE_URL:-$DEFAULT_BASE_URL}"
BASE_URL="${BASE_URL%/}"
case "$BASE_URL" in
    http://?*|https://?*) ;;
    *) echo "error: repository URL must use http:// or https://" >&2; exit 1 ;;
esac
case "$BASE_URL" in
    *[[:space:]]*|*\?*|*\#*) echo "error: repository URL must not contain whitespace, a query or a fragment" >&2; exit 1 ;;
esac

[ "$(id -u)" -eq 0 ] || {
    echo "error: this installer must be run as root" >&2
    exit 1
}

check_platform() {
    [ "$(uname -m)" = "x86_64" ] || {
        echo "error: only x86_64 is supported" >&2
        exit 1
    }
    [ -r /opt/pakfire/db/core/mine ] || {
        echo "error: IPFire Core version file is missing" >&2
        exit 1
    }
    core_version="$(cat /opt/pakfire/db/core/mine)"
    [ "$core_version" = "206" ] || {
        echo "error: IPFire Core 206 is required (detected: $core_version)" >&2
        exit 1
    }
}

check_platform

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
config_tmp="$(mktemp /opt/ipfrepo/repository.url.XXXXXX)"
chmod 644 "$config_tmp"
printf '%s\n' "$BASE_URL" > "$config_tmp"
mv -f "$config_tmp" "$CONFIG_FILE"
IPFREPO_BASE_URL="$BASE_URL" /usr/local/bin/ipfrepo update
echo "IPFire community repository installed."
echo "Run: ipfrepo list"
