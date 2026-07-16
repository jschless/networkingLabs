#!/bin/bash
set -e

ip link set eth1 up
ip addr add 198.51.100.10/24 dev eth1
ip route replace default via 198.51.100.1

cat >/tmp/dnsmasq.conf <<'EOF'
port=53
interface=eth1
bind-interfaces
listen-address=198.51.100.10
address=/public.lab/198.51.100.10
EOF
nohup dnsmasq --keep-in-foreground --conf-file=/tmp/dnsmasq.conf >/tmp/dnsmasq.log 2>&1 &

cat >/tmp/http-response.sh <<'EOF'
#!/bin/bash
printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 32\r\nConnection: close\r\n\r\nHello from the public internet!\n'
EOF
chmod +x /tmp/http-response.sh
nohup socat TCP-LISTEN:80,reuseaddr,fork EXEC:/tmp/http-response.sh >/tmp/http.log 2>&1 &

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout /tmp/public.key -out /tmp/public.crt \
  -subj "/CN=public.lab" -days 365 >/dev/null 2>&1
nohup openssl s_server -accept 443 -www -key /tmp/public.key -cert /tmp/public.crt >/tmp/https.log 2>&1 &

echo "[internet-client] Ready"
echo "  IP:       198.51.100.10/24"
echo "  Gateway:  198.51.100.1"
echo "  Services: DNS, HTTP, HTTPS"
