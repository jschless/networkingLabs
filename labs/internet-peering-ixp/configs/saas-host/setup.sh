#!/usr/bin/env bash
set -euo pipefail
ip addr add 192.0.2.10/24 dev eth1
ip route replace default via 192.0.2.1
printf 'saas service\n' >/tmp/index.html
python3 -m http.server 8080 --directory /tmp >/var/log/saas-http.log 2>&1 &
