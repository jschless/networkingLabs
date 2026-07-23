#!/usr/bin/env bash
set -euo pipefail

ip link set eth7 up
ip addr add 192.168.99.1/24 dev eth7 2>/dev/null || true

ip link add br-policy type bridge 2>/dev/null || true
ip link set br-policy type bridge vlan_filtering 1
ip link set br-policy up
bridge vlan del dev br-policy vid 1 self 2>/dev/null || true

# Client roles: corp/quarantine begin on VLAN 99 until EAP succeeds. Guest is a
# deliberately non-802.11 fallback endpoint on VLAN 120, not a claimed WLAN.
for spec in eth1:99 eth2:120 eth3:99 eth4:110 eth5:120 eth6:130; do
    iface=${spec%%:*}; vlan=${spec##*:}
    ip link set "$iface" up
    ip link set "$iface" master br-policy
    bridge vlan del dev "$iface" vid 1 2>/dev/null || true
    bridge vlan add dev "$iface" vid "$vlan" pvid untagged master
done

nft add table bridge wireless_auth 2>/dev/null || true
nft 'add set bridge wireless_auth blocked { type ifname; }' 2>/dev/null || true
nft 'add chain bridge wireless_auth forward { type filter hook forward priority 0; policy accept; }' 2>/dev/null || true
nft add rule bridge wireless_auth forward iifname @blocked ether type != 0x888e drop 2>/dev/null || true
nft add element bridge wireless_auth blocked '{ "eth1", "eth3" }' 2>/dev/null || true

chmod +x /etc/hostapd/vlan-action.sh
hostapd -B -P /run/hostapd-corp.pid /etc/hostapd/hostapd-corp.conf
hostapd -B -P /run/hostapd-quarantine.pid /etc/hostapd/hostapd-quarantine.conf
nohup hostapd_cli -i eth1 -a /etc/hostapd/vlan-action.sh >/var/log/hostapd-corp.log 2>&1 &
nohup hostapd_cli -i eth3 -a /etc/hostapd/vlan-action.sh >/var/log/hostapd-quarantine.log 2>&1 &
nohup python3 /opt/wlan-manager.py >/var/log/wlan-manager.log 2>&1 &
echo "authenticator ready: wired EAPOL and policy inventory only; no virtual radio"
