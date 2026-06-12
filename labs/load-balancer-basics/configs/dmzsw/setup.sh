#!/bin/bash
# dmzsw — plain L2 bridge for the DMZ segment (172.16.0.0/24)
# Ports: eth1=edge, eth2=edge2, eth3=lb, eth4=web1, eth5=web2

for i in 1 2 3 4 5; do
    for _ in $(seq 1 30); do
        ip link show "eth$i" >/dev/null 2>&1 && break
        sleep 1
    done
done

ip link add br0 type bridge 2>/dev/null || true
ip link set br0 up
for i in 1 2 3 4 5; do
    ip link set "eth$i" master br0
    ip link set "eth$i" up
done

echo "[dmzsw] bridging eth1-eth5 (DMZ segment)"
