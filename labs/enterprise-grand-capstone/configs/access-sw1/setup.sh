#!/bin/bash
# access-sw1 — Linux access switch + 802.1X authenticator (grand capstone).
#
#   eth1  uplink TRUNK to cc1   (tagged VLANs 10,20,30,99)
#   eth2  corp-pc               (802.1X; quarantine VLAN 99 -> VLAN 10 on auth)
#   eth3  voip-phone            (static access VLAN 20)
#   br0.99  management SVI      192.168.99.11/24  (RADIUS source toward radius1)
set -e

# ---- VLAN-filtering bridge ----
ip link add br0 type bridge 2>/dev/null || true
ip link set br0 type bridge vlan_filtering 1
ip link set br0 up
bridge vlan del dev br0 vid 1 self 2>/dev/null || true

# ---- Uplink trunk (eth1 -> cc1): tagged 10,20,30,99 ----
ip link set eth1 up
ip link set eth1 master br0
bridge vlan del dev eth1 vid 1 2>/dev/null || true
for v in 10 20 30 99; do bridge vlan add dev eth1 vid "$v" tagged; done

# ---- Management SVI on VLAN 99 (so the switch can source RADIUS) ----
bridge vlan add dev br0 vid 99 self
ip link add link br0 name br0.99 type vlan id 99 2>/dev/null || true
ip link set br0.99 up
ip addr add 192.168.99.11/24 dev br0.99 2>/dev/null || true
# Reach the lab-corp services (radius1 10.100.20.10) via the campus VRRP gateway.
# Keep the clab mgmt default route intact — only the services range is steered here.
ip route add 10.100.0.0/16 via 192.168.99.1 2>/dev/null || true

# ---- Access port eth2 (corp, 802.1X) — quarantine until authenticated ----
ip link set eth2 up
ip link set eth2 master br0
bridge vlan del dev eth2 vid 1 2>/dev/null || true
bridge vlan add dev eth2 vid 99 pvid untagged master

# ---- Access port eth3 (voice) — static VLAN 20 ----
ip link set eth3 up
ip link set eth3 master br0
bridge vlan del dev eth3 vid 1 2>/dev/null || true
bridge vlan add dev eth3 vid 20 pvid untagged master

# ---- Pre-auth filter: drop non-EAPOL from eth2 until authenticated ----
nft add table bridge nac 2>/dev/null || true
nft 'add set bridge nac blocked_ifaces { type ifname; }' 2>/dev/null || true
nft 'add chain bridge nac forward { type filter hook forward priority 0; policy accept; }' 2>/dev/null || true
nft add rule bridge nac forward iifname @blocked_ifaces ether type != 0x888e drop 2>/dev/null || true
nft add element bridge nac blocked_ifaces '{ "eth2" }' 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

# ---- hostapd 802.1X on eth2 + VLAN action handler ----
mkdir -p /var/run/hostapd
chmod +x /etc/hostapd/vlan-action.sh
hostapd -B -P /var/run/hostapd-eth2.pid /etc/hostapd/hostapd-corp.conf
nohup hostapd_cli -i eth2 -a /etc/hostapd/vlan-action.sh > /var/log/hostapd-eth2.log 2>&1 &

echo "[access-sw1] ready — trunk eth1, corp 802.1X eth2, voice eth3, mgmt 192.168.99.11"
