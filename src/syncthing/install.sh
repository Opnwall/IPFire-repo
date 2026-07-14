#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SYNCTHING_ARCH="${SYNCTHING_ARCH:-}"
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
        armv5*|armv6*) echo "arm" ;;
        armv7*|armhf|arm) echo "arm-v7" ;;
        i386|i486|i586|i686) echo "386" ;;
        *) die "Unsupported architecture: ${machine:-unknown}. Set SYNCTHING_ARCH manually." ;;
    esac
}

assert_elf() {
    file="$1"
    [ -s "$file" ] || die "Binary is empty: $file"
    if [ "$(od -An -tx1 -N4 "$file" | tr -d ' \n')" != "7f454c46" ]; then
        die "Binary is not a Linux ELF executable: $file"
    fi
}

download_syncthing() {
    arch="$1"

    case "$arch" in
        amd64|arm64|arm|arm-v7|386) ;;
        *) die "Unsupported Syncthing release architecture: $arch" ;;
    esac

    command -v curl >/dev/null 2>&1 || die "curl is required"
    command -v tar >/dev/null 2>&1 || die "tar is required"

    DOWNLOAD_TMPDIR="$(mktemp -d /tmp/syncthing.XXXXXX)"
    api_url="https://api.github.com/repos/syncthing/syncthing/releases/latest"
    release_json="$DOWNLOAD_TMPDIR/release.json"

    echo "Resolving latest Syncthing release"
    curl --retry 3 --retry-delay 5 --connect-timeout 30 -fL "$api_url" -o "$release_json"

    asset_url="$(grep -Eo 'https://[^"]+syncthing-linux-'"$arch"'-v[^"]+\.tar\.gz' "$release_json" | head -n 1 || true)"
    [ -n "$asset_url" ] || die "Could not find a Syncthing linux-$arch tarball in the latest release"

    echo "Downloading $asset_url"
    curl --retry 3 --retry-delay 5 --connect-timeout 30 -fL "$asset_url" -o "$DOWNLOAD_TMPDIR/syncthing.tar.gz"

    tar -xzf "$DOWNLOAD_TMPDIR/syncthing.tar.gz" -C "$DOWNLOAD_TMPDIR"
    bin_path="$(find "$DOWNLOAD_TMPDIR" -type f -path '*/syncthing' | head -n 1)"
    [ -n "$bin_path" ] || die "Syncthing binary not found in downloaded archive"

    install -m 755 "$bin_path" /usr/local/bin/syncthing
    assert_elf /usr/local/bin/syncthing
}

if [ "$(id -u)" -ne 0 ]; then
    die "Please run this script as root."
fi

cd "$BASE_DIR"

if [ -z "$SYNCTHING_ARCH" ]; then
    SYNCTHING_ARCH="$(detect_arch)"
fi

print_step "Preparing Syncthing installation"
echo "This will install Syncthing, the IPFire Web UI page, the menu entry, and the init script."
echo "Syncthing architecture: $SYNCTHING_ARCH"
printf "Continue? (y/N): "
read -r confirm
case "$confirm" in
    [Yy]) ;;
    *) echo "Operation cancelled."; exit 0 ;;
esac

print_step "Checking source files"
[ -d "$BASE_DIR/src" ] || die "Missing directory: src"
[ -f "$BASE_DIR/src/etc/rc.d/init.d/syncthing" ] || die "Missing file: src/etc/rc.d/init.d/syncthing"
[ -f "$BASE_DIR/src/srv/web/ipfire/cgi-bin/syncthing.cgi" ] || die "Missing file: src/srv/web/ipfire/cgi-bin/syncthing.cgi"
[ -f "$BASE_DIR/src/etc/sudoers.d/syncthing" ] || die "Missing file: src/etc/sudoers.d/syncthing"

print_step "Stopping old service"
/etc/rc.d/init.d/syncthing stop >/dev/null 2>&1 || true

print_step "Installing Syncthing binary"
install -d -m 755 /usr/local/bin
if [ -f "$BASE_DIR/src/usr/local/bin/syncthing" ]; then
    echo "Using bundled Syncthing binary: src/usr/local/bin/syncthing"
    install -m 755 "$BASE_DIR/src/usr/local/bin/syncthing" /usr/local/bin/syncthing
    assert_elf /usr/local/bin/syncthing
else
    download_syncthing "$SYNCTHING_ARCH"
fi

print_step "Copying files"
tmp_settings=""
if [ -f /var/ipfire/syncthing/settings ]; then
    tmp_settings="$(mktemp /tmp/syncthing-settings.backup.XXXXXX)"
    cp -p /var/ipfire/syncthing/settings "$tmp_settings"
fi

for dir in etc srv usr var; do
    cp -R -f "$BASE_DIR/src/$dir/." "/$dir/"
done

if [ -n "$tmp_settings" ] && [ -f "$tmp_settings" ]; then
    install -m 600 "$tmp_settings" /var/ipfire/syncthing/settings
    rm -f "$tmp_settings"
fi
sed -i '/^EXTRA_ARGS=/d' /var/ipfire/syncthing/settings 2>/dev/null || true

print_step "Creating runtime user"
if ! getent group syncthing >/dev/null 2>&1; then
    groupadd -r syncthing 2>/dev/null || groupadd syncthing
fi
if ! id syncthing >/dev/null 2>&1; then
    useradd -r -g syncthing -d /var/lib/syncthing -s /sbin/nologin syncthing 2>/dev/null || \
        useradd -g syncthing -d /var/lib/syncthing -s /bin/false syncthing
fi

print_step "Setting permissions"
install -d -m 700 -o syncthing -g syncthing /var/lib/syncthing
install -d -m 755 /var/ipfire/syncthing
touch /var/ipfire/syncthing/state
chown syncthing:syncthing /var/lib/syncthing 2>/dev/null || true
chmod 755 /etc/rc.d/init.d/syncthing /usr/local/bin/syncthing /srv/web/ipfire/cgi-bin/syncthing.cgi
chown root:root /etc/sudoers.d/syncthing 2>/dev/null || true
chmod 440 /etc/sudoers.d/syncthing
chmod 644 /var/ipfire/menu.d/84-syncthing.menu
chmod 600 /var/ipfire/syncthing/settings /var/ipfire/syncthing/state

print_step "Configuring startup"
ln -sf ../init.d/syncthing /etc/rc.d/rc3.d/S99syncthing
ln -sf ../init.d/syncthing /etc/rc.d/rc0.d/K01syncthing
ln -sf ../init.d/syncthing /etc/rc.d/rc6.d/K01syncthing

print_step "Configuring sudo permissions"
install -d -m 755 /etc/sudoers.d
visudo -cf /etc/sudoers.d/syncthing >/dev/null || die "sudoers validation failed"

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Syncthing installation completed."
echo "Open the IPFire Web UI and go to Services > Syncthing."
