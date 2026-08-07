#!/bin/sh
# k3s1 entrypoint — runs as the container's PID 1.
#
# containerlab wires data links AFTER the entrypoint starts, so we wait for
# eth1 to appear, address it on the rack subnet, then exec k3s with that IP
# as --node-ip. That ordering matters: MetalLB advertises the node's
# InternalIP as the BGP next-hop, so the node IP must be the rack-facing
# address, not the mgmt (eth0) address containerlab assigns.
set -eu

deadline=$(( $(date +%s) + 90 ))
while ! ip link show eth1 >/dev/null 2>&1; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "[k3s1] eth1 did not appear within 90 seconds" >&2
        ip -brief link >&2 || true
        exit 1
    fi
    sleep 1
done
ip addr add 10.1.0.11/24 dev eth1 2>/dev/null || true
ip link set eth1 up
# return path for LoadBalancer traffic (client subnet lives behind the ToR)
ip route add 172.16.9.0/24 via 10.1.0.1 2>/dev/null || true

# klipper (servicelb) + traefik + metrics-server disabled: MetalLB owns
# LoadBalancer, and the rest is RAM this lab doesn't need. host-gw flannel
# over the rack segment (both nodes are L2-adjacent there).
exec /bin/k3s server \
    --token labtoken1234567890 \
    --node-ip 10.1.0.11 \
    --advertise-address 10.1.0.11 \
    --tls-san 10.1.0.11 \
    --flannel-iface eth1 \
    --flannel-backend host-gw \
    --disable traefik \
    --disable servicelb \
    --disable metrics-server \
    --disable-network-policy
