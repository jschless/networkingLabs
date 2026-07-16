#!/bin/bash
set -e

ip link set eth1 up
ip addr add 172.16.10.10/24 dev eth1
ip route replace default via 172.16.10.1

cat >/tmp/http-response.sh <<'EOF'
#!/bin/bash
printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 29\r\nConnection: close\r\n\r\nHello from the DMZ web tier!\n'
EOF
chmod +x /tmp/http-response.sh
nohup socat TCP-LISTEN:80,reuseaddr,fork EXEC:/tmp/http-response.sh >/tmp/http.log 2>&1 &

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout /tmp/dmz.key -out /tmp/dmz.crt \
  -subj "/CN=dmz-web.lab" -days 365 >/dev/null 2>&1
nohup openssl s_server -accept 443 -www -key /tmp/dmz.key -cert /tmp/dmz.crt >/tmp/https.log 2>&1 &

echo "[dmz-web] Ready"
echo "  IP:       172.16.10.10/24"
echo "  Gateway:  172.16.10.1"
echo "  Services: HTTP, HTTPS"
