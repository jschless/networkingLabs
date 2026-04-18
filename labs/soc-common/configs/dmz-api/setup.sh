#!/bin/bash
set -e

ip link set eth1 up
ip addr add 172.16.20.10/24 dev eth1
ip route replace default via 172.16.20.1

mkdir -p /srv/api
cat > /srv/api/index.html << 'EOF'
dmz-api online
EOF
cat > /srv/api/healthz << 'EOF'
ok
EOF

python3 -m http.server 8080 --directory /srv/api >/tmp/dmz-api-http.log 2>&1 &

echo "[dmz-api] HTTP on 172.16.20.10:8080 ready"
