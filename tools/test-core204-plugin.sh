#!/bin/bash
# Explicitly installing lifecycle check. Use only on a backed-up test host.
set -euo pipefail
run=/root/core204-plugin-validation-20261027
plugin=${1:?plugin required}
case "$plugin" in backup|reports|lang|speedtest|mihomo|sing-box|zerotier|lucky|ttyd|adguardhome|syncthing|tailscale) ;; *) echo 'Plugin needs a dedicated test'; exit 2;; esac
base="$run/source/src/$plugin"
log="$run/logs/$plugin"
mkdir -p "$log"
cd "$base"
health() {
    apachectl -t
    dig +time=3 +tries=1 @127.0.0.1 www.ipfire.org A | grep -q 'status: NOERROR'
    test "$(cat /opt/pakfire/db/core/mine)" = 204
}
render() {
    while IFS= read -r file; do
        relative=${file#"$base/src/"}
        target="/$relative"
        perl -c "$target"
        output="$log/$(basename "$target").html"
        timeout 30 su -s /bin/bash nobody -c "env REQUEST_METHOD=GET QUERY_STRING='' REMOTE_ADDR=127.0.0.1 REMOTE_USER=admin SERVER_NAME=ipfire.test SERVER_PORT=444 HTTPS=on SCRIPT_NAME=/cgi-bin/$(basename "$target") perl '$target'" > "$output" 2>"$output.stderr"
        grep -qi 'Content-type:.*text/html' "$output"
        if grep -Eqi 'Software error:|Internal Server Error|Can.t locate .* in @INC' "$output"; then return 1; fi
    done < <(find "$base/src/srv/web/ipfire/cgi-bin" -maxdepth 1 -name '*.cgi')
}
health > "$log/health.before" 2>&1
printf 'y\n' | bash "$base/install.sh" > "$log/install.log" 2>&1
render > "$log/render.log" 2>&1
health > "$log/health.installed" 2>&1
printf 'y\n' | bash "$base/uninstall.sh" > "$log/uninstall.log" 2>&1
while IFS= read -r file; do
    relative=${file#"$base/src/"}
    case "$relative" in */settings|*/state) continue;; esac
    [[ ! -e "/$relative" ]] || { echo "Residual: /$relative"; exit 1; }
done < <(find "$base/src" -type f)
health > "$log/health.uninstalled" 2>&1
printf 'y\n' | bash "$base/install.sh" > "$log/reinstall.log" 2>&1
render > "$log/rerender.log" 2>&1
health > "$log/health.final" 2>&1
echo "LIFECYCLE_PASS|$plugin"
