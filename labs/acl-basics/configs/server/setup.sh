#!/bin/bash
set -e

ip link set eth1 up
ip addr replace 192.168.30.10/24 dev eth1
ip route replace default via 192.168.30.1

mkdir -p /srv/www8080 /srv/www2222
printf '%s\n' 'acl-basics-http-8080' > /srv/www8080/index.html
printf '%s\n' 'acl-basics-app-2222' > /srv/www2222/index.html
nohup python3 -m http.server 8080 --bind 0.0.0.0 \
  --directory /srv/www8080 >/tmp/http8080.log 2>&1 &
nohup python3 -m http.server 2222 --bind 0.0.0.0 \
  --directory /srv/www2222 >/tmp/http2222.log 2>&1 &

echo "[server] Ready: 192.168.30.10/24; TCP/8080 and TCP/2222 listening"
