#!/bin/bash
# fw-inside — internal firewall (inner boundary of screened subnet)
#
# Interfaces:
#   eth1  DMZ-inner  172.16.1.2/30   (facing fw-outside)
#   eth2  LAN-db     10.0.0.1/30     (facing db-server 10.0.0.2)
#   eth3  LAN-ws     10.0.0.5/30     (facing workstation 10.0.0.6)
#
# Policy (forward chain — default DROP):
#   ALLOW  established/related                           (stateful)
#   ALLOW  workstation (10.0.0.6) → internet via eth1   (outbound, SNAT at fw-outside)
#   ALLOW  workstation → web-server  (172.16.0.2) any   (DMZ management)
#   ALLOW  workstation → mail-server (172.16.0.6) any   (DMZ management)
#   ALLOW  web-server (172.16.0.2) → db-server TCP 3306 (app→DB only)
#   LOG+DROP everything else (DMZ→LAN pivots, internet→LAN, etc.)

# ── Interface setup ────────────────────────────────────────────────────────
ip link set eth1 up
ip addr add 172.16.1.2/30 dev eth1 2>/dev/null || true    # DMZ-inner
ip link set eth2 up
ip addr add 10.0.0.1/30   dev eth2 2>/dev/null || true    # LAN-db
ip link set eth3 up
ip addr add 10.0.0.5/30   dev eth3 2>/dev/null || true    # LAN-ws

# ── Routing ────────────────────────────────────────────────────────────────
# Default route via fw-outside (internet + DMZ are all reachable this way)
ip route del default 2>/dev/null || true
ip route add default via 172.16.1.1 2>/dev/null || true

# Explicit routes to DMZ subnets via fw-outside
ip route add 172.16.0.0/30 via 172.16.1.1 2>/dev/null || true    # DMZ-web
ip route add 172.16.0.4/30 via 172.16.1.1 2>/dev/null || true    # DMZ-mail

# ── IP forwarding ──────────────────────────────────────────────────────────
echo 1 > /proc/sys/net/ipv4/ip_forward

# ── nftables ruleset (written atomically from file) ────────────────────────
cat > /tmp/nft-fw-inside.conf << 'NFTEOF'
flush ruleset

table inet fw_inside {

    chain input {
        type filter hook input priority 0;
        policy accept;
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        # Stateful: permit established/related in both directions
        ct state established,related accept

        # Workstation → internet (all ports — SNAT applied at fw-outside)
        iif "eth3" oif "eth1" ip saddr 10.0.0.6 accept

        # Workstation → web-server (DMZ management access)
        iif "eth3" oif "eth1" ip saddr 10.0.0.6 ip daddr 172.16.0.2 accept

        # Workstation → mail-server (DMZ management access)
        iif "eth3" oif "eth1" ip saddr 10.0.0.6 ip daddr 172.16.0.6 accept

        # web-server → db-server on TCP 3306 only (application accesses DB)
        iif "eth1" oif "eth2" ip saddr 172.16.0.2 ip daddr 10.0.0.2 tcp dport 3306 ct state new accept

        # Defense in depth: log and drop everything else
        # This catches: DMZ server pivot attempts, internet→LAN if fw-outside fails,
        # mail-server→LAN, db-server→workstation lateral movement, etc.
        log prefix "[fw-in DROP] " drop
    }

    chain output {
        type filter hook output priority 0;
        policy accept;
    }
}
NFTEOF

nft -f /tmp/nft-fw-inside.conf

echo "[fw-inside] Internal firewall ready"
echo "  DMZ-inner: 172.16.1.2/30  (eth1)"
echo "  LAN-db:    10.0.0.1/30    (eth2)  → db-server   10.0.0.2"
echo "  LAN-ws:    10.0.0.5/30    (eth3)  → workstation 10.0.0.6"
echo ""
echo "  Policy: workstation→internet ALLOW | workstation→DMZ ALLOW"
echo "          web-server→db:3306 ALLOW   | all else DROP+LOG"
echo ""
echo "  View rules:  nft list ruleset"
echo "  Watch logs:  dmesg -w | grep fw-in"
