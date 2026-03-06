#!/bin/bash
# web-server — DMZ host serving HTTP on port 80
#
# IP:    172.16.0.2/30  (eth1, DMZ-web segment)
# GW:    172.16.0.1     (fw-outside)
#
# Simulates a public-facing web server in the DMZ.
# A minimal HTTP responder listens on port 80 using netcat.
# The db-server (10.0.0.2:3306) is reachable via fw-inside (allowed by policy).

ip link set eth1 up
ip addr add 172.16.0.2/30 dev eth1 2>/dev/null || true

# Default route via fw-outside
ip route del default 2>/dev/null || true
ip route add default via 172.16.0.1 2>/dev/null || true

# ── Minimal HTTP server on port 80 ────────────────────────────────────────
# Serves a single response then loops. Uses only tools available in frr-lab:local.
# Response is HTTP/1.1 200 OK with a short body identifying this server.
cat > /tmp/serve-http.sh << 'HTTPEOF'
#!/bin/bash
RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 42\r\nConnection: close\r\n\r\nHello from web-server in the DMZ zone!\n"
while true; do
    printf "$RESPONSE" | nc -l -p 80 -q 1 2>/dev/null || true
done
HTTPEOF
chmod +x /tmp/serve-http.sh
nohup bash /tmp/serve-http.sh > /tmp/http.log 2>&1 &

echo "[web-server] Ready"
echo "  IP:       172.16.0.2/30"
echo "  Gateway:  172.16.0.1 (fw-outside)"
echo "  HTTP:     listening on port 80 (nc loop)"
echo "  DB:       connect to 10.0.0.2:3306 (allowed by fw-inside policy)"
