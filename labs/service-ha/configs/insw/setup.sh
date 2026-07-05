#!/bin/bash
# insw — plain L2 bridge for the INSIDE segment (10.10.20.0/24).
# Ports: eth1=backend, eth2=fw1, eth3=fw2.
for i in 1 2 3; do
    for _ in $(seq 1 30); do
        ip link show "eth$i" >/dev/null 2>&1 && break
        sleep 1
    done
done
ip link add br0 type bridge 2>/dev/null || true
ip link set br0 up
for i in 1 2 3; do ip link set "eth$i" master br0; ip link set "eth$i" up; done
echo "[insw] bridging eth1-eth3 (INSIDE 10.10.20.0/24)"
