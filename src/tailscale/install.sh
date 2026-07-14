#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TAILSCALE_ARCH="${TAILSCALE_ARCH:-}"
if [ -z "$TAILSCALE_ARCH" ] && [ "$#" -gt 0 ]; then
    TAILSCALE_ARCH="$1"
fi
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

assert_elf() {
    file="$1"
    name="$2"

    [ -s "$file" ] || die "$name is empty: $file"

    if [ "$(od -An -tx1 -N4 "$file" | tr -d ' \n')" != "7f454c46" ]; then
        die "$name is not a Linux ELF binary. Download the static build from https://pkgs.tailscale.com/stable/#static and replace $file."
    fi
}

detect_tailscale_arch() {
    machine="$(uname -m 2>/dev/null || true)"
    case "$machine" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv5*|armv6*|armv7*|armhf|arm)
            echo "arm"
            ;;
        i386|i486|i586|i686)
            echo "386"
            ;;
        *)
            die "Unsupported platform architecture: ${machine:-unknown}. Set TAILSCALE_ARCH to amd64, arm64, arm, or 386."
            ;;
    esac
}

download_tailscale_binaries() {
    url="https://pkgs.tailscale.com/stable/tailscale_latest_${TAILSCALE_ARCH}.tgz"

    case "$TAILSCALE_ARCH" in
        amd64|arm|arm64|386) ;;
        *) die "Unsupported architecture: $TAILSCALE_ARCH. Supported values: amd64, arm, arm64, 386" ;;
    esac

    command -v curl >/dev/null 2>&1 || die "curl is required"
    command -v tar >/dev/null 2>&1 || die "tar is required"

    DOWNLOAD_TMPDIR="$(mktemp -d /tmp/tailscale-static.XXXXXX)"

    echo "Downloading Tailscale static package: $url"
    curl --retry 3 --retry-delay 5 --connect-timeout 30 -fL "$url" -o "$DOWNLOAD_TMPDIR/tailscale.tgz"

    echo "Extracting Tailscale static package"
    tar -xzf "$DOWNLOAD_TMPDIR/tailscale.tgz" -C "$DOWNLOAD_TMPDIR"

    pkg_dir="$(find "$DOWNLOAD_TMPDIR" -maxdepth 1 -type d -name 'tailscale_*' | head -n 1)"
    [ -n "$pkg_dir" ] || die "Could not find extracted Tailscale directory"
    [ -x "$pkg_dir/tailscale" ] || die "tailscale is missing from the static package"
    [ -x "$pkg_dir/tailscaled" ] || die "tailscaled is missing from the static package"

    install -m 755 "$pkg_dir/tailscale" /usr/local/bin/tailscale
    install -m 755 "$pkg_dir/tailscaled" /usr/sbin/tailscaled

    assert_elf /usr/local/bin/tailscale "tailscale"
    assert_elf /usr/sbin/tailscaled "tailscaled"
}

if [ "$(id -u)" -ne 0 ]; then
    die "Please run this script as root."
fi

cd "$BASE_DIR"

if [ -z "$TAILSCALE_ARCH" ]; then
    TAILSCALE_ARCH="$(detect_tailscale_arch)"
fi

print_step "Preparing Tailscale installation"
echo "This will install tailscale, tailscaled, the Web UI, the menu entry, and reload the Web service."
echo "Tailscale static binary architecture: $TAILSCALE_ARCH"
printf "Continue? (y/N): "
read -r confirm
case "$confirm" in
    [Yy]) ;;
    *)
    echo "Operation cancelled."
    exit 0
    ;;
esac

print_step "Checking source files"
[ -d "$BASE_DIR/src" ] || die "Missing directory: $BASE_DIR/src"
[ -f "$BASE_DIR/src/etc/rc.d/init.d/tailscale" ] || die "Missing file: src/etc/rc.d/init.d/tailscale"
[ -f "$BASE_DIR/src/srv/web/ipfire/cgi-bin/tailscale.cgi" ] || die "Missing file: src/srv/web/ipfire/cgi-bin/tailscale.cgi"
[ -f "$BASE_DIR/src/etc/sudoers.d/tailscale" ] || die "Missing file: src/etc/sudoers.d/tailscale"

print_step "Stopping old service"
/etc/rc.d/init.d/tailscale stop >/dev/null 2>&1 || true

print_step "Downloading Tailscale binaries"
install -d -m 755 /usr/local/bin
install -d -m 755 /usr/sbin
download_tailscale_binaries

print_step "Copying files"
tmp_settings=""
if [ -f /var/ipfire/tailscale/settings ]; then
    tmp_settings="$(mktemp /tmp/tailscale-settings.backup.XXXXXX)"
    cp -p /var/ipfire/tailscale/settings "$tmp_settings"
fi

for dir in etc srv var; do
    cp -R -f "$BASE_DIR/src/$dir/." "/$dir/"
done

if [ -n "$tmp_settings" ] && [ -f "$tmp_settings" ]; then
    install -m 644 "$tmp_settings" /var/ipfire/tailscale/settings
    rm -f "$tmp_settings"
fi

print_step "Setting permissions"
chmod 755 /etc/rc.d/init.d/tailscale /usr/local/bin/tailscale /usr/sbin/tailscaled /srv/web/ipfire/cgi-bin/tailscale.cgi 2>/dev/null || true
chown root:root /etc/sudoers.d/tailscale 2>/dev/null || true
chmod 440 /etc/sudoers.d/tailscale
chmod 644 /var/ipfire/menu.d/83-tailscale.menu /var/ipfire/tailscale/settings 2>/dev/null || true
chmod 755 /var/ipfire/tailscale 2>/dev/null || true
[ -f /var/ipfire/tailscale/state ] || touch /var/ipfire/tailscale/state
chmod 644 /var/ipfire/tailscale/state

touch /var/log/tailscale.log
chmod 644 /var/log/tailscale.log
install -d -m 755 /var/run/tailscale
install -d -m 755 /etc/sudoers.d

print_step "Configuring startup"
ln -sf /etc/rc.d/init.d/tailscale /etc/rc.d/rc3.d/S99tailscale

print_step "Configuring sudo permissions"
visudo -cf /etc/sudoers.d/tailscale >/dev/null || die "sudoers validation failed"

print_step "Adding forwarding rules"
iptables -C FORWARD -i tailscale0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i tailscale0 -j ACCEPT
iptables -C FORWARD -o tailscale0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -o tailscale0 -j ACCEPT
grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 >/dev/null

print_step "Reloading Web service"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "Tailscale installation complete."
echo "Go to the Web UI (Services > Tailscale), save the settings, and join the network."
