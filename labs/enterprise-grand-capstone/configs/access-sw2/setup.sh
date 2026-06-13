#!/bin/bash
# access-sw2 — Linux access switch (grand capstone), open guest switch.
#
#   eth1  uplink TRUNK to cc2   (tagged VLANs 10,20,30,99)
#   eth2  guest-pc              (static access VLAN 30, no 802.1X)
#   br0.99  management SVI      192.168.99.12/24
set -e

ip link add br0 type bridge 2>/dev/null || true
ip link set br0 type bridge vlan_filtering 1
ip link set br0 up
bridge vlan del dev br0 vid 1 self 2>/dev/null || true

# Uplink trunk (eth1 -> cc2): tagged 10,20,30,99
ip link set eth1 up
ip link set eth1 master br0
bridge vlan del dev eth1 vid 1 2>/dev/null || true
for v in 10 20 30 99; do bridge vlan add dev eth1 vid "$v" tagged; done

# Management SVI on VLAN 99
bridge vlan add dev br0 vid 99 self
ip link add link br0 name br0.99 type vlan id 99 2>/dev/null || true
ip link set br0.99 up
ip addr add 192.168.99.12/24 dev br0.99 2>/dev/null || true
ip route add 10.100.0.0/16 via 192.168.99.1 2>/dev/null || true

# Guest access port eth2 — static VLAN 30
ip link set eth2 up
ip link set eth2 master br0
bridge vlan del dev eth2 vid 1 2>/dev/null || true
bridge vlan add dev eth2 vid 30 pvid untagged master

echo 1 > /proc/sys/net/ipv4/ip_forward
echo "[access-sw2] ready — trunk eth1, guest VLAN30 eth2, mgmt 192.168.99.12"
