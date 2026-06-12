#!/bin/bash
# web2 — backend web server
#
# IP:  172.16.0.12/24 (eth1, DMZ)
# GW:  172.16.0.1     (edge)
#
# Identical to web1 except for its name and address — interchangeable
# backends are the precondition for load balancing.

ip link set eth1 up
ip addr add 172.16.0.12/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 172.16.0.1 2>/dev/null || true

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/lab.conf << 'EOF'
server {
    listen 80 default_server;
    location / {
        default_type text/plain;
        return 200 "server: web2\nclient-ip-seen-by-backend: $remote_addr\nx-forwarded-for: '$http_x_forwarded_for'\npath: $request_uri\n";
    }
}
EOF
nginx

echo "[web2] Ready — 172.16.0.12/24, gw 172.16.0.1, nginx on :80"
