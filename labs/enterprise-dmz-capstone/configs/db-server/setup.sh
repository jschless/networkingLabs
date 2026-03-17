#!/bin/bash
# db-server — internal LAN host simulating a database server
#
# IP:    10.0.0.2/30  (eth1, LAN-db segment)
# GW:    10.0.0.1     (fw-inside)
#
# Simulates a database server on the internal LAN, reachable only from
# web-server on TCP 3306 (enforced by fw-inside policy).
# All other inbound connections are blocked by fw-inside.

set -e

ip link set eth1 up
ip addr add 10.0.0.2/30 dev eth1

# Default route via fw-inside
ip route del default 2>/dev/null || true
ip route add default via 10.0.0.1

# ── Stub database listener on port 3306 ───────────────────────────────────
# Simulates a MySQL/MariaDB server. Returns a greeting banner.
cat > /tmp/serve-db.sh << 'DBEOF'
#!/bin/bash
BANNER="Welcome to db-server stub (MySQL port 3306) — internal LAN only\n"
while true; do
    printf "$BANNER" | nc -l -p 3306 -q 1 2>/dev/null || true
done
DBEOF
chmod +x /tmp/serve-db.sh
nohup bash /tmp/serve-db.sh > /tmp/db.log 2>&1 &

echo "[db-server] Ready"
echo "  IP:       10.0.0.2/30"
echo "  Gateway:  10.0.0.1 (fw-inside)"
echo "  DB stub:  listening on port 3306 (nc stub)"
echo "  Access:   only from web-server (172.16.0.2) — enforced by fw-inside"
