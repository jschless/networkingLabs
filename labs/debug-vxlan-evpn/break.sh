#!/usr/bin/env bash
set -euo pipefail

prefix=clab-debug-vxlan-evpn
device="$prefix-vtep2"

[[ "$(docker inspect --format '{{.State.Running}}' "$device" 2>/dev/null)" == true ]] \
  || { echo "ERROR: debug-vxlan-evpn is not deployed" >&2; exit 1; }

docker exec -i "$device" Cli -p 15 >/dev/null <<'EOS'
enable
configure
interface Loopback100
   ip address 10.0.0.22/32
interface Vxlan1
   vxlan source-interface Loopback100
end
EOS

docker exec "$prefix-host1" ip neigh flush all >/dev/null 2>&1 || true
docker exec "$prefix-host2" ip neigh flush all >/dev/null 2>&1 || true

for _attempt in $(seq 1 30); do
  source_config=$(docker exec "$device" Cli -p 15 -c enable \
    -c 'show running-config interfaces Vxlan1' 2>/dev/null || true)
  evpn_summary=$(docker exec "$device" Cli -p 15 -c enable \
    -c 'show bgp evpn summary' 2>/dev/null || true)
  if grep -q 'vxlan source-interface Loopback100' <<<"$source_config" \
      && grep -qE '^[[:space:]]*10\.0\.0\.100[[:space:]].*Estab' <<<"$evpn_summary"; then
    echo "Scenario armed. Reproduce the endpoint symptom and preserve the starting evidence."
    exit 0
  fi
  sleep 1
done

echo "ERROR: scenario did not reach its bounded control-plane postcondition" >&2
exit 1
