#!/usr/bin/env bash
set -euo pipefail
N="clab-global-application-delivery-site-a-lb"

docker exec "$N" sh -c '
  cp /opt/gad/haproxy.cfg /etc/haproxy/haproxy.cfg
  haproxy -c -f /etc/haproxy/haproxy.cfg
  kill "$(cat /run/haproxy.pid)" 2>/dev/null || true
  nohup haproxy -f /etc/haproxy/haproxy.cfg -db >>/var/log/gad/haproxy.log 2>&1 &
  echo $! >/run/haproxy.pid
'
echo "Repaired: removed the source-specific /health deny while retaining normal WAF policy."
