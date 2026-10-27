#!/bin/bash
# Download official stable x86_64 assets and verify release asset digests.
# Does not install to a live firewall or publish repository packages.
set -euo pipefail
base=$(cd "$(dirname "$0")/.." && pwd)
downloads="$base/work/core204/downloads"
mkdir -p "$downloads"
fetch() {
    local repo=$1 pattern=$2 key=$3
    gh api "repos/$repo/releases/latest" > "$downloads/$key.release.json"
    local asset url name expected actual
    asset=$(jq -c --arg pattern "$pattern" '[.assets[] | select(.name | test($pattern))] | if length == 1 then .[0] else error("ambiguous or missing asset") end' "$downloads/$key.release.json")
    url=$(printf '%s' "$asset" | jq -r .browser_download_url)
    name=$(printf '%s' "$asset" | jq -r .name)
    expected=$(printf '%s' "$asset" | jq -r '.digest // ""' | sed 's/^sha256://')
    aria2c -c -x 4 -s 4 --show-console-readout=false --summary-interval=0 --console-log-level=error --dir="$downloads" --out="$name" "$url" > "$downloads/$key.download.log" 2>&1
    actual=$(shasum -a 256 "$downloads/$name" | awk '{print $1}')
    if [[ -z "$expected" ]]; then
        [[ "$key" == ttyd ]] || { echo "Missing upstream digest: $key"; return 1; }
        curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/SHA256SUMS" -o "$downloads/ttyd.SHA256SUMS"
        expected=$(awk '$2 ~ /ttyd.x86_64$/ {print $1}' "$downloads/ttyd.SHA256SUMS")
    fi
    [[ "$actual" == "$expected" ]] || { echo "SHA256 mismatch: $key"; return 1; }
    printf '%s\t%s\t%s\t%s\n' "$key" "$(jq -r .tag_name "$downloads/$key.release.json")" "$actual" "$url" > "$downloads/$key.verified.tsv"
    printf 'VERIFIED|%s|%s\n' "$key" "$(jq -r .tag_name "$downloads/$key.release.json")"
}
fetch MetaCubeX/mihomo '^mihomo-linux-amd64-v1-v[0-9.]+\.gz$' mihomo &
p1=$!
fetch SagerNet/sing-box '^sing-box-[0-9.]+-linux-amd64-glibc\.tar\.gz$' sing-box &
p2=$!
fetch AdguardTeam/AdGuardHome '^AdGuardHome_linux_amd64\.tar\.gz$' adguardhome &
p3=$!
fetch gdy666/lucky '^lucky_[0-9.]+_Linux_x86_64\.tar\.gz$' lucky &
p4=$!
fetch syncthing/syncthing '^syncthing-linux-amd64-v[0-9.]+\.tar\.gz$' syncthing &
p5=$!
fetch showwin/speedtest-go '^speedtest-go_[0-9.]+_Linux_x86_64\.tar\.gz$' speedtest &
p6=$!
fetch tsl0922/ttyd '^ttyd\.x86_64$' ttyd &
p7=$!
fetch_tailscale() {
    curl -fsSL 'https://pkgs.tailscale.com/stable/?mode=json' -o "$downloads/tailscale.release.json"
    local name expected actual
    name=$(jq -r '.Tarballs.amd64' "$downloads/tailscale.release.json")
    [[ "$name" =~ ^tailscale_[0-9.]+_amd64\.tgz$ ]]
    curl -fsSL "https://pkgs.tailscale.com/stable/$name.sha256" -o "$downloads/tailscale.sha256"
    expected=$(awk '{print $1}' "$downloads/tailscale.sha256")
    aria2c -c -x 4 -s 4 --show-console-readout=false --summary-interval=0 --console-log-level=error --dir="$downloads" --out="$name" "https://pkgs.tailscale.com/stable/$name" > "$downloads/tailscale.download.log" 2>&1
    actual=$(shasum -a 256 "$downloads/$name" | awk '{print $1}')
    [[ "$actual" == "$expected" ]]
    printf 'tailscale\t%s\t%s\t%s\n' "$(jq -r .TarballsVersion "$downloads/tailscale.release.json")" "$actual" "https://pkgs.tailscale.com/stable/$name" > "$downloads/tailscale.verified.tsv"
}
fetch_tailscale &
p8=$!
failed=0
for pid in "$p1" "$p2" "$p3" "$p4" "$p5" "$p6" "$p7" "$p8"; do wait "$pid" || failed=1; done
[[ $failed == 0 ]]
