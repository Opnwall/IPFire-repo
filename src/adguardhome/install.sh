#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ADGUARDHOME_ARCH="${ADGUARDHOME_ARCH:-}"
BUNDLED_BINARY="$BASE_DIR/src/opt/adguardhome/AdGuardHome"
DOWNLOAD_TMPDIR=""

print_step() {
    echo
    echo "==> $1"
}

die() {
    echo "Error: $1" >&2
    exit 1
}

cleanup() {
    if [ -n "${DOWNLOAD_TMPDIR:-}" ] && [ -d "$DOWNLOAD_TMPDIR" ]; then
        rm -rf "$DOWNLOAD_TMPDIR"
    fi
}
trap cleanup EXIT

detect_arch() {
    machine="$(uname -m 2>/dev/null || true)"
    case "$machine" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7*|armhf) echo "armv7" ;;
        armv6*) echo "armv6" ;;
        armv5*) echo "armv5" ;;
        i386|i486|i586|i686) echo "386" ;;
        *) die "Unsupported architecture: ${machine:-unknown}. Set ADGUARDHOME_ARCH manually." ;;
    esac
}

assert_elf() {
    file="$1"
    [ -s "$file" ] || die "Binary is empty: $file"
    if [ "$(od -An -tx1 -N4 "$file" | tr -d ' \n')" != "7f454c46" ]; then
        die "Binary is not a Linux ELF executable: $file"
    fi
}

fetch_url() {
    url="$1"
    output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl --retry 3 --retry-delay 5 --connect-timeout 30 -fL "$url" -o "$output"
        return
    fi
    if command -v wget >/dev/null 2>&1; then
        wget --tries=3 --timeout=30 -O "$output" "$url"
        return
    fi
    die "curl or wget is required"
}

download_adguardhome() {
    arch="$1"

    case "$arch" in
        amd64|arm64|armv7|armv6|armv5|386) ;;
        *) die "Unsupported AdGuard Home release architecture: $arch" ;;
    esac

    command -v tar >/dev/null 2>&1 || die "tar is required"

    DOWNLOAD_TMPDIR="$(mktemp -d /tmp/adguardhome.XXXXXX)"
    release_json="$DOWNLOAD_TMPDIR/release.json"

    echo "Resolving latest AdGuard Home release"
    fetch_url "https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest" "$release_json"

    asset_url="$(grep -Eo 'https://[^"]+/AdGuardHome_linux_'"$arch"'\.tar\.gz' "$release_json" | head -n 1 || true)"
    [ -n "$asset_url" ] || die "Could not find AdGuardHome_linux_$arch.tar.gz in the latest release"

    echo "Downloading $asset_url"
    fetch_url "$asset_url" "$DOWNLOAD_TMPDIR/AdGuardHome.tar.gz"

    tar -xzf "$DOWNLOAD_TMPDIR/AdGuardHome.tar.gz" -C "$DOWNLOAD_TMPDIR"
    bin_path="$(find "$DOWNLOAD_TMPDIR" -type f -path '*/AdGuardHome' | head -n 1)"
    [ -n "$bin_path" ] || die "AdGuardHome binary not found in downloaded archive"

    install -d -m 755 /opt/adguardhome
    install -m 755 "$bin_path" /opt/adguardhome/AdGuardHome
    assert_elf /opt/adguardhome/AdGuardHome
}

if [ "$(id -u)" -ne 0 ]; then
    die "Please run this script as root."
fi

cd "$BASE_DIR"

if [ -z "$ADGUARDHOME_ARCH" ]; then
    ADGUARDHOME_ARCH="$(detect_arch)"
fi

print_step "Preparing AdGuard Home installation"
echo "This will install AdGuard Home, the IPFire Web UI page, the menu entry, and the init script."
echo "AdGuard Home architecture: $ADGUARDHOME_ARCH"
printf "Continue? (y/N): "
read -r confirm
case "$confirm" in
    [Yy]) ;;
    *) echo "Operation cancelled."; exit 0 ;;
esac

print_step "Checking source files"
[ -d "$BASE_DIR/src" ] || die "Missing directory: src"
[ -f "$BASE_DIR/src/etc/rc.d/init.d/adguardhome" ] || die "Missing file: src/etc/rc.d/init.d/adguardhome"
[ -f "$BASE_DIR/src/srv/web/ipfire/cgi-bin/adguardhome.cgi" ] || die "Missing file: src/srv/web/ipfire/cgi-bin/adguardhome.cgi"
[ -f "$BASE_DIR/src/var/ipfire/adguardhome/settings" ] || die "Missing file: src/var/ipfire/adguardhome/settings"
[ -f "$BASE_DIR/src/etc/sudoers.d/adguardhome" ] || die "Missing file: src/etc/sudoers.d/adguardhome"

print_step "Stopping old service"
/etc/rc.d/init.d/adguardhome stop >/dev/null 2>&1 || true

print_step "Installing AdGuard Home binary"
if [ -f "$BUNDLED_BINARY" ]; then
    echo "Using bundled AdGuard Home binary: src/opt/adguardhome/AdGuardHome"
    install -d -m 755 /opt/adguardhome
    install -m 755 "$BUNDLED_BINARY" /opt/adguardhome/AdGuardHome
    assert_elf /opt/adguardhome/AdGuardHome
else
    echo "Bundled AdGuard Home binary not found; downloading release for $ADGUARDHOME_ARCH."
    download_adguardhome "$ADGUARDHOME_ARCH"
fi

print_step "Copying files"
tmp_settings=""
tmp_config=""
if [ -f /var/ipfire/adguardhome/settings ]; then
    tmp_settings="$(mktemp /tmp/adguardhome-settings.backup.XXXXXX)"
    cp -p /var/ipfire/adguardhome/settings "$tmp_settings"
fi
if [ -f /var/ipfire/adguardhome/AdGuardHome.yaml ]; then
    tmp_config="$(mktemp /tmp/adguardhome-config.backup.XXXXXX)"
    cp -p /var/ipfire/adguardhome/AdGuardHome.yaml "$tmp_config"
fi

for dir in etc srv var; do
    cp -R -f "$BASE_DIR/src/$dir/." "/$dir/"
done

if [ -n "$tmp_settings" ] && [ -f "$tmp_settings" ]; then
    install -m 600 "$tmp_settings" /var/ipfire/adguardhome/settings
    rm -f "$tmp_settings"
fi
if [ -n "$tmp_config" ] && [ -f "$tmp_config" ]; then
    install -m 600 "$tmp_config" /var/ipfire/adguardhome/AdGuardHome.yaml
    rm -f "$tmp_config"
fi

print_step "Setting permissions"
install -d -m 755 /var/ipfire/adguardhome /var/lib/adguardhome
touch /var/ipfire/adguardhome/state
touch /var/log/adguardhome.log
chown root:root /opt/adguardhome/AdGuardHome /etc/rc.d/init.d/adguardhome /etc/sudoers.d/adguardhome /srv/web/ipfire/cgi-bin/adguardhome.cgi 2>/dev/null || true
chmod 755 /opt/adguardhome/AdGuardHome /etc/rc.d/init.d/adguardhome /srv/web/ipfire/cgi-bin/adguardhome.cgi
chmod 440 /etc/sudoers.d/adguardhome
chmod 644 /var/ipfire/menu.d/82-adguardhome.menu
chmod 600 /var/ipfire/adguardhome/settings /var/ipfire/adguardhome/state /var/log/adguardhome.log
[ ! -f /var/ipfire/adguardhome/AdGuardHome.yaml ] || chmod 600 /var/ipfire/adguardhome/AdGuardHome.yaml

print_step "Configuring startup"
ln -sf ../init.d/adguardhome /etc/rc.d/rc3.d/S98adguardhome
ln -sf ../init.d/adguardhome /etc/rc.d/rc0.d/K02adguardhome
ln -sf ../init.d/adguardhome /etc/rc.d/rc6.d/K02adguardhome

print_step "Configuring sudo permissions"
install -d -m 755 /etc/sudoers.d
visudo -cf /etc/sudoers.d/adguardhome >/dev/null || die "sudoers validation failed"

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "AdGuard Home installation completed."
echo "Start it from Services > AdGuard Home, then open http://<ipfire-host>:3000/ for the first-run wizard."
