#!/bin/sh
# client — the "user" that reaches Kubernetes LoadBalancer services by
# their VIP, routed through the ToR.
set -eu

deadline=$(( $(date +%s) + 60 ))
while ! ip link show eth1 >/dev/null 2>&1; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "[client] eth1 did not appear within 60 seconds" >&2
        ip -brief link >&2 || true
        exit 1
    fi
    sleep 1
done

ip link set eth1 up
ip addr replace 172.16.9.10/24 dev eth1
# replace, not add: containerlab already installed a mgmt default route;
# reach the rack + service VIPs via the ToR.
ip route replace 10.1.0.0/24 via 172.16.9.1
ip route replace 198.51.100.0/24 via 172.16.9.1
echo "[client] 172.16.9.10/24, rack + service VIPs via tor 172.16.9.1"
