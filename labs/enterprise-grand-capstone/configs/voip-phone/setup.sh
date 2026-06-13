#!/bin/bash
# voip-phone — IP phone on access-sw1 eth3 (static access VLAN 20, voice).
# No 802.1X (the port is a static voice port). Gets its address from the real
# Kea server via DHCP relay on the core. See README: `dhclient eth1`.
set -e
ip link set eth1 up
# Drop the ContainerLab mgmt default so DHCP installs the campus default route.
ip route del default via 172.20.20.1 dev eth0 2>/dev/null || true
echo "[voip-phone] link up on VLAN 20 (voice). Next: dhclient eth1"
