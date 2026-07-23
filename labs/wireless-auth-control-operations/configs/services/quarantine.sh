#!/usr/bin/env bash
set -euo pipefail
ip link set eth1 up
ip addr add 10.130.0.1/24 dev eth1
echo 'quarantine remediation fixture' >/srv/index.html
nohup python3 -m http.server 8080 --directory /srv --bind 10.130.0.1 >/var/log/service.log 2>&1 &
