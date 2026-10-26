#!/bin/bash
# Restore a selected pre-install snapshot. Restores captive DATA as well as code.
set -euo pipefail
[[ $EUID == 0 ]] || exit 1
backup=${1:-$(cat /var/ipfire/captive-enhanced/last-backup)}
[[ $backup == /var/backups/captive-enhanced/* && -f $backup/original.tar.gz ]] || { echo 'Invalid backup' >&2; exit 1; }
# Take a recovery copy of current data before restoring the previous state.
tar -czpf "$backup/before-restore-$(date +%Y%m%d-%H%M%S)-$$.tar.gz" -C / var/ipfire/captive
# Stop serving writers while the transaction lock and code are replaced.
apachectl -k stop
# Wait until the old parent has released its PID file before starting again.
for ((attempt=0; attempt<100; attempt++)); do
    [[ ! -s /var/run/httpd.pid ]] && break
    sleep 0.1
done
[[ ! -s /var/run/httpd.pid ]] || { echo 'Apache has not stopped; restoration cancelled' >&2; exit 1; }
trap 'apachectl -k start || true' ERR
while IFS= read -r file; do rm -f "/$file"; done < "$backup/absent"
tar -xzpf "$backup/original.tar.gz" -C /
# Drop runtime files that did not exist at snapshot time.
for name in .transaction .attempts; do
    grep -Fxq "var/ipfire/captive/$name" "$backup/present" || rm -f "/var/ipfire/captive/$name"
done
apachectl -t
apachectl -k start
/usr/local/bin/captivectrl
trap - ERR
printf 'Restored snapshot: %s\n' "$backup"
