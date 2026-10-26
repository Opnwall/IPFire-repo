#!/bin/bash
# IPFire captive enhancement installer. GPL-3.0-or-later.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root' >&2; exit 1; }
base=$(cd "$(dirname "$0")" && pwd)
grep -q 'IPFire 2.29' /etc/system-release || { echo 'Requires IPFire 2.29' >&2; exit 1; }
[[ -x /usr/local/bin/captivectrl && -f /etc/httpd/conf/vhosts.d/captive.conf ]] || exit 1
[[ -s "$base/src/usr/share/fonts/captive-enhanced/CaptiveSansCJK-Regular.ttf" ]] || { echo 'Missing Unicode coupon font' >&2; exit 1; }
apachectl -t
for module in CGI HTML::Template PDF::API2 File::LibMagic JSON::PP Digest::SHA; do perl -M"$module" -e 1; done
while IFS= read -r file; do perl -c "$file"; done < <(find "$base/src" -type f \( -name '*.cgi' -o -name 'captive-lib.pl' -o -name 'captive-pdf.pl' -o -name 'captive-enhanced.*.pl' -o -name 'captive-terminology.*.pl' -o -name 'captive-cleanup' \))
backup=/var/backups/captive-enhanced/$(date +%Y%m%d-%H%M%S)-$$
install -d -m 700 "$backup"
# Back up each overwritten file, all live captive state, and Apache config.
(cd "$base/src" && find . -type f -print | sed 's#^./##') > "$backup/managed"
printf '%s\n' etc/httpd/conf/vhosts.d/captive-trial-management.conf var/ipfire/captive/.state.lock var/ipfire/captive/.csrf-key var/ipfire/captive/settings var/ipfire/captive/terms.txt var/ipfire/captive/terms2.txt var/ipfire/captive/coupons var/ipfire/captive/clients >> "$backup/managed"
for language in br en es fr it pt; do
    printf 'var/ipfire/addon-lang/captive.%s.pl\n' "$language" >> "$backup/managed"
done
# Cache regeneration is part of installation, so include existing caches in rollback.
find /var/ipfire/langs -maxdepth 1 -type f -name 'cache-lang.pl.*' -print | sed 's#^/##' >> "$backup/managed"
: > "$backup/present"; : > "$backup/absent"
while IFS= read -r file; do
    if [[ -e /$file ]]; then echo "$file" >> "$backup/present"; else echo "$file" >> "$backup/absent"; fi
done < "$backup/managed"
if [[ -d /var/ipfire/captive ]]; then (cd / && find var/ipfire/captive -print) >> "$backup/present"; fi
sort -u "$backup/present" -o "$backup/present"
tar -czpf "$backup/original.tar.gz" -C / -T "$backup/present"
cp "$base/uninstall.sh" "$backup/restore.sh"
printf '%s\n' "$backup" > "$backup/location"
restore_on_error() { echo "Install failed; restoring $backup" >&2; bash "$backup/restore.sh" "$backup" 9>&-; }
trap restore_on_error ERR
install -d -o nobody -g nobody -m 750 /var/ipfire/captive
# Hold the same stable lock across upgrades. Apache must not inherit this FD.
exec 9<>/var/ipfire/captive/.state.lock
flock -x 9
# Install CGI code root-owned; only state is writable by the Web service.
while IFS= read -r relative; do
    [[ -f "$base/src/$relative" ]] || continue
    install -d -m 755 "$(dirname "/$relative")"
    mode=644
    [[ $relative == *.cgi || $relative == usr/bin/captive-cleanup || $relative == usr/bin/captive-enable-zones ]] && mode=755
    install -o root -g root -m "$mode" "$base/src/$relative" "/$relative"
done < "$backup/managed"
for file in settings clients coupons terms.txt terms2.txt .state.lock; do
    [[ -e /var/ipfire/captive/$file ]] || touch "/var/ipfire/captive/$file"
    chown nobody:nobody "/var/ipfire/captive/$file"
    chmod 640 "/var/ipfire/captive/$file"
done
# RED is never a Captive Portal zone. Enable each supported internal zone only
# when that interface exists on this appliance; this also handles BLUE systems.
/usr/bin/captive-enable-zones /var/ipfire/captive/settings /var/ipfire/ethernet/settings
if [[ ! -s /var/ipfire/captive/.csrf-key ]]; then
    umask 077
    perl -e 'open(my $f,"<:raw","/dev/urandom") or die; read($f,my $s,32)==32 or die; print unpack("H*",$s)' > /var/ipfire/captive/.csrf-key
fi
chown root:nobody /var/ipfire/captive/.csrf-key
chmod 640 /var/ipfire/captive/.csrf-key
# The upstream dictionaries are key=value text, not executable IPFire addon Perl.
# Remove only recognizable legacy text files, after backing them up above.
for language in br en es fr it pt; do
    legacy="/var/ipfire/addon-lang/captive.$language.pl"
    if [[ -f $legacy ]] && grep -Eq '^[[:space:]]*title=' "$legacy"; then rm -f "$legacy"; fi
done
# Migrate the original IPFire terms file only when enhanced terms are empty.
if [[ ! -s /var/ipfire/captive/terms.txt && -s /var/ipfire/captive/agb.txt ]]; then
    cat /var/ipfire/captive/agb.txt > /var/ipfire/captive/terms.txt
fi
# Merge the former second terms field once. The backup above retains both
# original files, and truncating terms2.txt makes this migration idempotent.
if [[ -s /var/ipfire/captive/terms2.txt ]]; then
    [[ ! -s /var/ipfire/captive/terms.txt ]] || printf '\n\n' >> /var/ipfire/captive/terms.txt
    cat /var/ipfire/captive/terms2.txt >> /var/ipfire/captive/terms.txt
    : > /var/ipfire/captive/terms2.txt
fi
cat > /etc/httpd/conf/vhosts.d/captive-trial-management.conf <<'EOF'
# Independent coupon UI is restricted exactly like the IPFire admin CGI.
<Directory /srv/web/ipfire/html/CaptivePortal>
    Options ExecCGI
    AllowOverride None
    DirectoryIndex index.cgi
    AuthName "IPFire - Restricted"
    AuthType Basic
    AuthUserFile /var/ipfire/auth/users
    <RequireAll>
        Require user admin
        Require ssl
    </RequireAll>
    # Only this read-only endpoint is anonymous; all management stays restricted.
    <Files "export.cgi">
        AuthMerging Off
        AuthType None
        Require ssl
    </Files>
</Directory>
EOF
# Proper Perl addon translations participate in the standard IPFire language cache.
/usr/local/bin/update-lang-cache
apachectl -t
apachectl -k graceful 9>&-
/usr/local/bin/captivectrl
install -d -m 700 /var/ipfire/captive-enhanced
printf '%s\n' "$backup" > /var/ipfire/captive-enhanced/last-backup
trap - ERR
printf 'Installed. Existing GREEN/BLUE zones enabled; other settings preserved. Backup: %s\n' "$backup"
