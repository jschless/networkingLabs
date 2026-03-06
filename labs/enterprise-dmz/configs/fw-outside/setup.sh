#!/bin/bash
# fw-outside — perimeter firewall (screened subnet, outer boundary)
#
# Interfaces:
#   eth1  WAN        203.0.114.2/30  (facing isp)
#   eth2  DMZ-web    172.16.0.1/30   (facing web-server 172.16.0.2)
#   eth3  DMZ-mail   172.16.0.5/30   (facing mail-server 172.16.0.6)
#   eth4  DMZ-inner  172.16.1.1/30   (facing fw-inside 172.16.1.2)
#
# Policy (forward chain — default DROP):
#   ALLOW  established/related                     (stateful return traffic)
#   ALLOW  internet → web-server  TCP 80,443       (public web access)
#   ALLOW  internet → mail-server TCP 25           (public mail access)
#   ALLOW  fw-inside (LAN) → internet (outbound — SNAT applied at postrouting)
#   LOG+DROP everything else
#
#   SNAT:  masquerade all outbound through eth1 (WAN IP)

# ── Interface setup ────────────────────────────────────────────────────────
ip link set eth1 up
ip addr add 203.0.114.2/30 dev eth1 2>/dev/null || true    # WAN
ip link set eth2 up
ip addr add 172.16.0.1/30  dev eth2 2>/dev/null || true    # DMZ-web
ip link set eth3 up
ip addr add 172.16.0.5/30  dev eth3 2>/dev/null || true    # DMZ-mail
ip link set eth4 up
ip addr add 172.16.1.1/30  dev eth4 2>/dev/null || true    # DMZ-inner

# ── Routing ────────────────────────────────────────────────────────────────
ip route del default 2>/dev/null || true
ip route add default via 203.0.114.1 2>/dev/null || true

# Explicit route for internet-client subnet (symmetrical routing)
ip route add 203.0.113.0/30 via 203.0.114.1 2>/dev/null || true

# Route to internal LAN via fw-inside
ip route add 10.0.0.0/24 via 172.16.1.2 2>/dev/null || true

# ── IP forwarding ──────────────────────────────────────────────────────────
echo 1 > /proc/sys/net/ipv4/ip_forward

# ── nftables ruleset (written atomically from file) ────────────────────────
cat > /tmp/nft-fw-outside.conf << 'NFTEOF'
flush ruleset

table inet fw_outside {

    chain input {
        type filter hook input priority 0;
        policy accept;
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        # Stateful: permit return/related traffic in both directions
        ct state established,related accept

        # internet → web-server on HTTP/HTTPS
        iif "eth1" oif "eth2" ip daddr 172.16.0.2 tcp dport { 80, 443 } ct state new accept

        # internet → mail-server on SMTP
        iif "eth1" oif "eth3" ip daddr 172.16.0.6 tcp dport 25 ct state new accept

        # fw-inside / LAN outbound → internet (SNAT applied in postrouting)
        iif "eth4" oif "eth1" accept

        # Log and drop everything else
        log prefix "[fw-out DROP] " drop
    }

    chain output {
        type filter hook output priority 0;
        policy accept;
    }

    chain postrouting {
        type nat hook postrouting priority 100;

        # Masquerade all outbound traffic through the WAN interface
        oif "eth1" masquerade
    }
}
NFTEOF

nft -f /tmp/nft-fw-outside.conf

echo "[fw-outside] Perimeter firewall ready"
echo "  WAN:       203.0.114.2/30  (eth1)"
echo "  DMZ-web:   172.16.0.1/30   (eth2)  → web-server  172.16.0.2"
echo "  DMZ-mail:  172.16.0.5/30   (eth3)  → mail-server 172.16.0.6"
echo "  DMZ-inner: 172.16.1.1/30   (eth4)  → fw-inside   172.16.1.2"
echo ""
echo "  Policy: internet→web:80,443 ALLOW | internet→mail:25 ALLOW"
echo "          LAN outbound ALLOW | SNAT via eth1 | everything else DROP+LOG"
echo ""
echo "  View rules:  nft list ruleset"
echo "  Watch logs:  dmesg -w | grep fw-out"
