#!/usr/bin/env bash
set -euo pipefail
N="clab-global-application-delivery-site-a-lb"

docker exec "$N" sh -c '
  cp /opt/gad/haproxy.break.cfg /etc/haproxy/haproxy.cfg
  haproxy -c -f /etc/haproxy/haproxy.cfg
  kill "$(cat /run/haproxy.pid)" 2>/dev/null || true
  nohup haproxy -f /etc/haproxy/haproxy.cfg -db >>/var/log/gad/haproxy.log 2>&1 &
  echo $! >/run/haproxy.pid
'
echo "Injected: site A denies the GSLB source only on /health. Allow about 4 seconds for withdrawal."
