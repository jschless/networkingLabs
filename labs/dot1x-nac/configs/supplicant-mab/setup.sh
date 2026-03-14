#!/bin/bash
# supplicant-mab/setup.sh — MAB supplicant (no 802.1X, IoT device, VLAN 30)
#
# No wpa_supplicant needed. The authenticator's hostapd detects no EAP response
# after auth_fail_timeout (10s) and sends an Access-Request to RADIUS using
# this node's MAC address as both User-Name and User-Password (MAB).
# FreeRADIUS matches the DEFAULT entry → Accept + VLAN 30.

set -e

ip link set eth1 up
ip addr add 10.30.30.11/24 dev eth1 2>/dev/null || true

echo "[supplicant-mab] IP 10.30.30.11/24 configured on eth1"
echo "[supplicant-mab] MAC: $(cat /sys/class/net/eth1/address)"
echo "[supplicant-mab] No wpa_supplicant — sending ARP to trigger MAB detection"

# Give authenticator time to complete setup, then send an ARP frame.
# The authenticator's mab-eth3.sh sees this frame via tcpdump raw socket
# (captured before the bridge's nftables filter), extracts our MAC,
# authenticates us with RADIUS, and moves eth3 to VLAN 30.
sleep 6
ping -c 2 -W 2 10.30.30.1 2>/dev/null || true  # sends ARP + ICMP (ARP is enough)
