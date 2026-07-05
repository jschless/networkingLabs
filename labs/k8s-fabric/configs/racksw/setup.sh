#!/bin/bash
# racksw — plain L2 bridge for the rack segment (10.1.0.0/24).
# Ports: eth1=tor, eth2=k3s1, eth3=k3s2. No IP of its own; pure L2 so the
# ToR and both k3s nodes are one broadcast domain (flannel host-gw and the
# MetalLB↔ToR BGP sessions all ride this segment).

for i in 1 2 3; do
    for _ in $(seq 1 30); do
        ip link show "eth$i" >/dev/null 2>&1 && break
        sleep 1
    done
done

ip link add br0 type bridge 2>/dev/null || true
ip link set br0 up
for i in 1 2 3; do
    ip link set "eth$i" master br0
    ip link set "eth$i" up
done

echo "[racksw] bridging eth1-eth3 (rack segment 10.1.0.0/24)"
