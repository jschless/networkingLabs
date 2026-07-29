#!/usr/bin/env bash
set -eu
ip addr add 10.112.20.10/24 dev eth1
ip route replace default via 10.112.20.1 dev eth1
mkdir -p /srv/gitops-app
printf 'approved-service-path\n' > /srv/gitops-app/index.html
nohup python3 -m http.server 8080 --bind 10.112.20.10 \
  --directory /srv/gitops-app >/tmp/gitops-app.log 2>&1 &
