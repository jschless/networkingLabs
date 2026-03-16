#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up

ip addr replace 192.168.10.1/24 dev eth1
ip addr replace 192.168.20.1/24 dev eth2

iptables-legacy -F INPUT
iptables-legacy -P INPUT ACCEPT

mkdir -p /srv/www8080 /srv/www2222
cat > /srv/www8080/index.html << 'EOF'
acl-basics-http
EOF
cat > /srv/www2222/index.html << 'EOF'
acl-basics-app
EOF
python3 -m http.server 8080 --directory /srv/www8080 >/tmp/http8080.log 2>&1 &
python3 -m http.server 2222 --directory /srv/www2222 >/tmp/http2222.log 2>&1 &

echo "[router] Ready: router-local services on 8080 and 2222, no ACLs applied yet"
