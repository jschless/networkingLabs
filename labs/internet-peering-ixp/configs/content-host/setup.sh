#!/usr/bin/env bash
set -euo pipefail
ip addr add 198.51.100.10/24 dev eth1
ip route replace default via 198.51.100.1
printf 'content service\n' >/tmp/index.html
python3 -m http.server 8080 --directory /tmp >/var/log/content-http.log 2>&1 &
