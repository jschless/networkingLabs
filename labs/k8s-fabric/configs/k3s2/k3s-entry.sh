#!/bin/sh
# k3s2 entrypoint — the agent (worker). Same eth1-first ordering as k3s1,
# then joins the server at 10.1.0.11 with the shared token. k3s retries the
# join until the server is up, so node boot order doesn't matter.
set -eu

deadline=$(( $(date +%s) + 90 ))
while ! ip link show eth1 >/dev/null 2>&1; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "[k3s2] eth1 did not appear within 90 seconds" >&2
        ip -brief link >&2 || true
        exit 1
    fi
    sleep 1
done
ip addr add 10.1.0.12/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add 172.16.9.0/24 via 10.1.0.1 2>/dev/null || true

exec /bin/k3s agent \
    --server https://10.1.0.11:6443 \
    --token labtoken1234567890 \
    --node-ip 10.1.0.12 \
    --flannel-iface eth1
