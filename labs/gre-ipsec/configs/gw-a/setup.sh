#!/bin/bash
# gw-a — Site A gateway
#
# Pre-configured by this script:
#   - LAN A interface: 192.168.1.1/24 on eth1
#   - WAN interface:   203.0.113.1/30 on eth2
#   - Default WAN route via internet node (203.0.113.2)
#   - GRE tunnel tun0: local 203.0.113.1 remote 203.0.113.6, addr 172.16.0.1/30
#   - Route to LAN B (192.168.2.0/24) via GRE tunnel endpoint 172.16.0.2
#
# You configure:
#   - /etc/ipsec.conf    (defines the IPsec transport mode connection)
#   - /etc/ipsec.secrets (pre-shared key)
#   - Run: ipsec start

set -e

# LAN A interface
ip addr add 192.168.1.1/24 dev eth1 2>/dev/null || true
ip link set eth1 up

# WAN interface
ip addr add 203.0.113.1/30 dev eth2 2>/dev/null || true
ip link set eth2 up

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true

# Remove management default route; add specific route to gw-b's WAN subnet
ip route del default dev eth0 2>/dev/null || true
ip route add 203.0.113.4/30 via 203.0.113.2 2>/dev/null || true

# GRE tunnel: transport between gw-a (203.0.113.1) and gw-b (203.0.113.6)
ip tunnel add tun0 mode gre local 203.0.113.1 remote 203.0.113.6 ttl 255 2>/dev/null || true
ip addr add 172.16.0.1/30 dev tun0 2>/dev/null || true
ip link set tun0 up 2>/dev/null || true

# Route to LAN B over the GRE tunnel
ip route add 192.168.2.0/24 via 172.16.0.2 2>/dev/null || true

echo "gw-a setup complete"
echo "  LAN A:  192.168.1.1/24 (eth1)"
echo "  WAN:    203.0.113.1/30 (eth2)"
echo "  GRE:    172.16.0.1/30  (tun0 <-> gw-b 172.16.0.2)"
echo ""
echo "To encrypt GRE traffic with IPsec:"
echo "  1. Edit /etc/ipsec.conf and /etc/ipsec.secrets"
echo "  2. Run: ipsec start"
echo "  3. Check: ipsec statusall"
