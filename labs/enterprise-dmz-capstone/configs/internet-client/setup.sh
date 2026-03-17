#!/bin/bash
# internet-client — attacker / external client on the internet
#
# IP:    203.0.113.2/30  (eth1, facing isp)
# GW:    203.0.113.1     (isp)
#
# This node simulates an external attacker or a legitimate internet user.
# From here you can:
#   - Test allowed traffic:  nc -zv 203.0.114.2 80     (HTTP to fw-outside WAN)
#   - Test blocked traffic:  nc -zv 10.0.0.2 22         (should never reach LAN)
#   - Watch nftables logs:   run `nft monitor` on fw-outside in another shell

ip link set eth1 up
ip addr add 203.0.113.2/30 dev eth1 2>/dev/null || true

# Default route via ISP
ip route del default 2>/dev/null || true
ip route add default via 203.0.113.1 2>/dev/null || true

echo "[internet-client] Ready — IP 203.0.113.2, gateway 203.0.113.1"
