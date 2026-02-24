#!/bin/bash
# gw-a — Site A WireGuard gateway
# Configures WAN interface and creates /etc/wireguard directory.
# User configures /etc/wireguard/wg0.conf and runs: wg-quick up wg0

ip addr add 10.0.0.10/24 dev eth1 2>/dev/null || true
ip link set eth1 up
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

echo "gw-a ready."
echo "  WAN: 10.0.0.10/24 on eth1"
echo "  Hub WAN: 10.0.0.1"
echo ""
echo "Steps to configure WireGuard:"
echo "  1. wg genkey | tee /etc/wireguard/gwa.key | wg pubkey > /etc/wireguard/gwa.pub"
echo "  2. Create /etc/wireguard/wg0.conf"
echo "  3. wg-quick up wg0"
