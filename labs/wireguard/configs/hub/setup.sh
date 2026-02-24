#!/bin/bash
# hub — WireGuard VPN server
# Configures WAN interface and creates /etc/wireguard directory.
# User configures /etc/wireguard/wg0.conf and runs: wg-quick up wg0

ip addr add 10.0.0.1/24 dev eth1 2>/dev/null || true
ip link set eth1 up
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

echo "hub ready."
echo "  WAN: 10.0.0.1/24 on eth1"
echo ""
echo "Steps to configure WireGuard:"
echo "  1. wg genkey | tee /etc/wireguard/hub.key | wg pubkey > /etc/wireguard/hub.pub"
echo "  2. Create /etc/wireguard/wg0.conf"
echo "  3. wg-quick up wg0"
