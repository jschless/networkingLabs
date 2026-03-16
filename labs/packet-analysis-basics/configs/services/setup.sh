#!/bin/bash
set -e

ip link set eth1 up
ip addr replace 10.2.0.2/30 dev eth1
ip route replace default via 10.2.0.1

mkdir -p /srv/www
cat > /srv/www/index.html << 'EOF'
packet-analysis-basics
EOF
cat > /srv/www/healthz << 'EOF'
ok
EOF
python3 -m http.server 8080 --directory /srv/www >/tmp/http.log 2>&1 &

echo "[services] Ready: 10.2.0.2/30, HTTP on 8080"
