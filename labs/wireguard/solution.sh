#!/usr/bin/env bash
set -euo pipefail

hub="clab-wireguard-hub"
gw_a="clab-wireguard-gw-a"
gw_b="clab-wireguard-gw-b"

abort() {
    echo "Repair validation failed; inspect the deployed lab state." >&2
    exit 1
}

docker inspect "$hub" "$gw_a" "$gw_b" >/dev/null 2>&1 || abort
gw_a_key="$(docker exec "$gw_a" wg show wg0 public-key 2>/dev/null)"
[[ "$gw_a_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] || abort

docker exec "$hub" wg set wg0 peer "$gw_a_key" allowed-ips 192.168.100.10/32 \
    >/dev/null 2>&1 || abort

mapping="$(docker exec "$hub" wg show wg0 allowed-ips 2>/dev/null | awk -v key="$gw_a_key" '$1 == key {print $2}')"
[[ "$mapping" == "192.168.100.10/32" ]] || abort

docker exec "$gw_a" ping -c 3 -W 2 192.168.100.1 >/dev/null 2>&1 || abort
docker exec "$hub" ping -c 3 -W 2 192.168.100.10 >/dev/null 2>&1 || abort
docker exec "$gw_a" ping -c 3 -W 2 192.168.100.20 >/dev/null 2>&1 || abort

echo "Repair applied and validated."
