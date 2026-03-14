#!/bin/bash
# authenticator/setup.sh
# Sets up the Linux bridge with VLAN filtering, nftables pre-auth blocking,
# and launches hostapd on each supplicant port.

set -e

init_preauth_filter() {
    nft add table bridge nac 2>/dev/null || true
    nft 'add set bridge nac blocked_ifaces { type ifname; }' 2>/dev/null || true
    nft 'add chain bridge nac forward { type filter hook forward priority 0; policy accept; }' 2>/dev/null || true
    nft add rule bridge nac forward iifname @blocked_ifaces ether type != 0x888e drop 2>/dev/null || true
}

block_interface() {
    nft add element bridge nac blocked_ifaces "{ \"$1\" }" 2>/dev/null || true
}

# ── RADIUS link ──────────────────────────────────────────────────────────────
ip link set eth5 up
ip addr add 192.168.100.1/24 dev eth5 2>/dev/null || true

# ── Server links (direct L2 to each server, no bridge needed here) ───────────
ip link set eth6 up
ip link set eth7 up
ip link set eth8 up

# ── Create bridge with VLAN filtering ────────────────────────────────────────
ip link add br0 type bridge 2>/dev/null || true
ip link set br0 type bridge vlan_filtering 1
ip link set br0 up

# Remove the default VLAN 1 from the bridge itself
bridge vlan del dev br0 vid 1 self 2>/dev/null || true

# ── Add server ports (eth6=VLAN10, eth7=VLAN20, eth8=VLAN30) ─────────────────
for eth_vlan in "eth6:10" "eth7:20" "eth8:30"; do
    eth="${eth_vlan%%:*}"
    vlan="${eth_vlan##*:}"
    ip link set "$eth" master br0
    bridge vlan del dev "$eth" vid 1 2>/dev/null || true
    bridge vlan add dev "$eth" vid "$vlan" pvid untagged master
done

# ── Add supplicant ports to VLAN 99 (quarantine) ────────────────────────────
for eth in eth1 eth2 eth3 eth4; do
    ip link set "$eth" up
    ip link set "$eth" master br0
    bridge vlan del dev "$eth" vid 1 2>/dev/null || true
    bridge vlan add dev "$eth" vid 99 pvid untagged master
done

# ── nftables: block all non-EAPOL frames from supplicant ports (pre-auth) ─────
# EAPOL frames (0x888e) are NOT forwarded by Linux bridges (reserved 01:80:c2:00:00:03
# MAC). hostapd receives them via raw socket even with bridge enslavement.
# Only non-EAPOL data frames are in the FORWARD chain and need blocking.
init_preauth_filter
for eth in eth1 eth2 eth3 eth4; do
    block_interface "$eth"
done

# ── Enable IP forwarding (needed for RADIUS UDP routing via eth5) ─────────────
echo 1 > /proc/sys/net/ipv4/ip_forward

# ── Make scripts executable ──────────────────────────────────────────────────
chmod +x /etc/hostapd/vlan-action.sh
chmod +x /etc/hostapd/mab-eth3.sh

# ── Start hostapd on each supplicant port ─────────────────────────────────────
mkdir -p /var/run/hostapd
for eth in eth1 eth2 eth3 eth4; do
    hostapd -B -P /var/run/hostapd-$eth.pid /etc/hostapd/hostapd-$eth.conf
    echo "[authenticator] hostapd started on $eth"
done

# ── Start hostapd_cli action handlers (one per port) ─────────────────────────
for eth in eth1 eth2 eth3 eth4; do
    nohup hostapd_cli -i "$eth" -a /etc/hostapd/vlan-action.sh \
        > /var/log/hostapd-$eth.log 2>&1 &
    echo "[authenticator] hostapd_cli action handler started for $eth (PID $!)"
done

# ── MAB background handler for eth3 ─────────────────────────────────────────
# hostapd's radius_mac_auth_bypass is unavailable in this build; we replicate
# the behaviour manually: capture the source MAC on eth3 and authenticate via RADIUS.
nohup bash /etc/hostapd/mab-eth3.sh > /var/log/mab-eth3.log 2>&1 &
echo "[authenticator] MAB handler started for eth3 (PID $!)"

echo "[authenticator] Setup complete. Bridge br0 active with VLAN filtering."
echo "[authenticator] Supplicant ports eth1-eth4 in VLAN 99 (quarantine) pending auth."
