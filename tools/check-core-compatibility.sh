#!/bin/bash
# Non-installing source checks; run on the target IPFire host.
set -uo pipefail
base=$(cd "$(dirname "$0")/.." && pwd)
fail=0
printf 'HOST|%s|%s|%s\n' "$(hostname)" "$(cat /opt/pakfire/db/core/mine)" "$(uname -m)"
while IFS= read -r -d '' file; do
    relative=${file#"$base/"}
    check=()
    case "$file" in
        */sudoers.d/*) check=(visudo -cf "$file");;
        *.cgi|*.pl) check=(perl -c "$file");;
        *.sh|*.menu) check=();;
    esac
    if [[ ${#check[@]} == 0 ]]; then
        LC_ALL=C grep -Iq '^#!' "$file" || continue
        first=$(head -n 1 "$file")
        case "$first" in
            '#!'*bash*|'#!'*'/sh'*) check=(bash -n "$file");;
            '#!'*perl*) check=(perl -c "$file");;
            *) continue;;
        esac
    fi
    output=$("${check[@]}" 2>&1)
    if [[ $? == 0 ]]; then
        printf 'PASS|%s\n' "$relative"
    else
        printf 'FAIL|%s|%s\n' "$relative" "$output"
        fail=$((fail+1))
    fi
done < <(find "$base/src" -type f ! -name '.DS_Store' ! -name '._*' -print0)
printf 'FAILED_CHECKS|%s\n' "$fail"
[[ $fail == 0 ]]
