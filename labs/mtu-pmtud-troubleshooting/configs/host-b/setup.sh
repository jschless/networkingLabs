#!/bin/bash
set -e

ip link set eth1 up
ip addr replace 192.168.2.10/24 dev eth1
ip route replace default via 192.168.2.1

mkdir -p /srv/www
cat > /srv/www/index.html << 'EOF'
mtu-pmtud-troubleshooting
EOF
python3 -m http.server 8080 --directory /srv/www >/tmp/http.log 2>&1 &
python3 /udp-echo.py >/tmp/udp-echo.log 2>&1 &

echo "[host-b] Ready: 192.168.2.10/24, HTTP on 8080, UDP echo on 9999"
