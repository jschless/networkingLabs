#!/bin/bash
# outsw — plain L2 bridge for the OUTSIDE segment (203.0.113.0/29)
# Ports: eth1=client, eth2=edge, eth3=edge2

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

echo "[outsw] bridging eth1-eth3 (OUTSIDE segment)"
