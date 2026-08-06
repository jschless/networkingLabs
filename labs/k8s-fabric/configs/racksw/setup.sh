#!/usr/bin/env bash
# racksw — plain L2 bridge for the rack segment (10.1.0.0/24).
# Ports: eth1=tor, eth2=k3s1, eth3=k3s2. No IP of its own; pure L2 so the
# ToR and both k3s nodes are one broadcast domain (flannel host-gw and the
# MetalLB↔ToR BGP sessions all ride this segment).

set -euo pipefail

for interface in eth1 eth2 eth3; do
    ready=false
    for _attempt in {1..60}; do
        if ip link show "$interface" >/dev/null 2>&1; then
            ready=true
            break
        fi
        sleep 1
    done
    if [[ "$ready" != true ]]; then
        echo "[racksw] $interface did not appear within 60 seconds" >&2
        ip -brief link >&2 || true
        exit 1
    fi
done

ip link add br0 type bridge 2>/dev/null || true
ip link set br0 up
for interface in eth1 eth2 eth3; do
    ip link set "$interface" master br0
    ip link set "$interface" up
done

echo "[racksw] bridging eth1-eth3 (rack segment 10.1.0.0/24)"
