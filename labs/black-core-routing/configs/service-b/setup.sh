#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.20.20.10/24 dev eth1
ip route replace default via 10.20.20.1

cat >/tmp/dnsmasq.conf <<'EOF'
port=53
interface=eth1
bind-interfaces
listen-address=10.20.20.10
address=/red-service.lab/10.20.20.10
EOF
nohup dnsmasq --keep-in-foreground --conf-file=/tmp/dnsmasq.conf >/tmp/dnsmasq.log 2>&1 &

cat >/tmp/serve-http.sh <<'EOF'
#!/bin/bash
RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 43\r\nConnection: close\r\n\r\nHello from the red service network in Site B\n"
while true; do
    printf "$RESPONSE" | nc -l -p 80 -q 1 2>/dev/null || true
done
EOF
chmod +x /tmp/serve-http.sh
nohup bash /tmp/serve-http.sh >/tmp/http.log 2>&1 &

echo "[service-b] Ready"
echo "  IP:       10.20.20.10/24"
echo "  Gateway:  10.20.20.1"
echo "  Services: HTTP, DNS"
