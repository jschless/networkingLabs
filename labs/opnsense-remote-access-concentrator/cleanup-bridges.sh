#!/usr/bin/env bash
set -uo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
status=0
for bridge in br-corp br-remote-wan; do
    ip link show "$bridge" >/dev/null 2>&1 || continue
    if [[ -n "$(ip -o link show master "$bridge" 2>/dev/null)" ]]; then
        echo "ERROR: $bridge still has attached interfaces" >&2
        status=1
        continue
    fi
    ip link set "$bridge" down || status=1
    ip link del "$bridge" type bridge || status=1
done
(( status == 0 )) || {
    echo "ERROR: stop the lab roles before removing their exact bridges" >&2
    exit "$status"
}
