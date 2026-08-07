#!/usr/bin/env bash
set -euo pipefail

prefix=clab-debug-vxlan-evpn
device="$prefix-vtep2"

[[ "$(docker inspect --format '{{.State.Running}}' "$device" 2>/dev/null)" == true ]] \
  || { echo "ERROR: debug-vxlan-evpn is not deployed" >&2; exit 1; }

docker exec -i "$device" Cli -p 15 >/dev/null <<'EOS'
enable
configure
interface Vxlan1
   vxlan source-interface Loopback0
no interface Loopback100
end
EOS

docker exec "$prefix-host1" ip neigh flush all >/dev/null 2>&1 || true
docker exec "$prefix-host2" ip neigh flush all >/dev/null 2>&1 || true

for _attempt in $(seq 1 45); do
  source_config=$(docker exec "$device" Cli -p 15 -c enable \
    -c 'show running-config interfaces Vxlan1' 2>/dev/null || true)
  evpn_summary=$(docker exec "$device" Cli -p 15 -c enable \
    -c 'show bgp evpn summary' 2>/dev/null || true)
  if grep -q 'vxlan source-interface Loopback0' <<<"$source_config" \
      && grep -qE '^[[:space:]]*10\.0\.0\.100[[:space:]].*Estab' <<<"$evpn_summary" \
      && docker exec "$prefix-host1" ping -c 2 -W 1 172.16.0.2 >/dev/null 2>&1 \
      && docker exec "$prefix-host2" ping -c 2 -W 1 172.16.0.1 >/dev/null 2>&1; then
    echo "Repair applied. Verify the control-plane identity, tunnel state, and bidirectional traffic."
    exit 0
  fi
  sleep 1
done

echo "ERROR: repair did not reach its bounded forwarding postcondition" >&2
exit 1
