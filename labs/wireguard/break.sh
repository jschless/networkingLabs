#!/usr/bin/env bash
set -euo pipefail

hub="clab-wireguard-hub"
spoke="clab-wireguard-gw-a"

abort() {
    echo "Scenario injection failed; deploy and complete the working build first." >&2
    exit 1
}

docker inspect "$hub" "$spoke" >/dev/null 2>&1 || abort
spoke_key="$(docker exec "$spoke" wg show wg0 public-key 2>/dev/null)"
[[ "$spoke_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] || abort

docker exec "$hub" wg set wg0 peer "$spoke_key" allowed-ips 192.168.100.99/32 \
    >/dev/null 2>&1 || abort

# Generate authenticated traffic so control-plane liveness is still observable.
docker exec "$spoke" ping -c 1 -W 2 192.168.100.1 >/dev/null 2>&1 || true
sleep 1

mapping="$(docker exec "$hub" wg show wg0 allowed-ips 2>/dev/null | awk -v key="$spoke_key" '$1 == key {print $2}')"
latest="$(docker exec "$hub" wg show wg0 latest-handshakes 2>/dev/null | awk -v key="$spoke_key" '$1 == key {print $2}')"
now="$(date +%s)"

[[ "$mapping" == "192.168.100.99/32" ]] || abort
docker exec "$spoke" ping -c 1 -W 2 10.0.0.1 >/dev/null 2>&1 || abort
[[ "$latest" =~ ^[0-9]+$ && "$latest" -gt 0 && $((now - latest)) -le 180 ]] || abort

echo "Scenario injected. Begin with the observed state."
