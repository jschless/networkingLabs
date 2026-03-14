#!/bin/bash
# mail-server — DMZ host accepting SMTP connections on port 25
#
# IP:    172.16.0.6/30  (eth1, DMZ-mail segment)
# GW:    172.16.0.5     (fw-outside)
#
# Simulates a public-facing mail server (MX) in the DMZ.
# A stub SMTP listener on port 25 accepts connections and returns a banner.

ip link set eth1 up
ip addr add 172.16.0.6/30 dev eth1 2>/dev/null || true

# Default route via fw-outside
ip route del default 2>/dev/null || true
ip route add default via 172.16.0.5 2>/dev/null || true

# ── Stub SMTP listener on port 25 ─────────────────────────────────────────
# Returns a minimal SMTP banner. Demonstrates the port is open and fw-outside
# permits TCP 25 from the internet.
cat > /tmp/serve-smtp.sh << 'SMTPEOF'
#!/bin/bash
BANNER="220 mail-server.dmz ESMTP Stub (DMZ lab)\r\n"
while true; do
    printf "$BANNER" | nc -l -p 25 -q 2 2>/dev/null || true
done
SMTPEOF
chmod +x /tmp/serve-smtp.sh
nohup bash /tmp/serve-smtp.sh > /tmp/smtp.log 2>&1 &

echo "[mail-server] Ready"
echo "  IP:       172.16.0.6/30"
echo "  Gateway:  172.16.0.5 (fw-outside)"
echo "  SMTP:     listening on port 25 (nc stub)"
