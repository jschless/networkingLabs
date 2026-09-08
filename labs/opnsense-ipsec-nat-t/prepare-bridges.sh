#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
created=()
rollback() {
    local bridge
    for bridge in "${created[@]}"; do
        ip link set "$bridge" down 2>/dev/null || true
        ip link del "$bridge" type bridge 2>/dev/null || true
    done
}
trap rollback ERR
trap 'rollback; exit 130' INT
trap 'rollback; exit 143' TERM
for bridge in br-public br-private-wan br-hq-lan br-branch-lan; do
    if ! ip link show "$bridge" >/dev/null 2>&1; then
        ip link add name "$bridge" type bridge
        created+=("$bridge")
    fi
    ip link set "$bridge" up
done
trap - ERR INT TERM
