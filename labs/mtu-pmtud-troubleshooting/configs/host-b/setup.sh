#!/usr/bin/env bash
set -euo pipefail

ip link set dev eth1 up mtu 1500
ip -4 addr flush dev eth1
ip addr add 192.168.2.10/24 dev eth1
ip route replace default via 192.168.2.1 dev eth1

if ! pgrep -f '^python3 /services.py --http$' >/dev/null; then
  python3 /services.py --http >/tmp/services.log 2>&1 &
fi

echo "[host-b] Endpoint services are ready."
