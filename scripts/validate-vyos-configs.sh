#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mapfile -t configs < <(find "$REPO_ROOT/labs" -path '*/clab-*' -prune -o -name config.boot -type f -print | sort)

if [[ ${#configs[@]} -eq 0 ]]; then
    echo "No VyOS config.boot files found."
    exit 0
fi

status=0

for cfg in "${configs[@]}"; do
    if grep -q '^// Warning: Do not remove the following line\.$' "$cfg"; then
        echo "FAIL $cfg contains deprecated warning footer line"
        status=1
    fi

    last_nonempty="$(awk 'NF { line=$0 } END { print line }' "$cfg")"
    if [[ ! "$last_nonempty" =~ ^//[[:space:]]vyos-config-version:\  ]]; then
        echo "FAIL $cfg is missing a final vyos-config-version footer line"
        status=1
    fi
done

if [[ $status -eq 0 ]]; then
    echo "All VyOS config.boot files passed footer validation."
fi

exit "$status"
