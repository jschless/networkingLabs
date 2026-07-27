#!/usr/bin/env bash
set -euo pipefail

P="clab-global-application-delivery"

for site in a b; do
    node="$P-site-$site-lb"
    docker exec "$node" sh -c '
      cp /opt/gad/haproxy.cfg /etc/haproxy/haproxy.cfg
      haproxy -c -f /etc/haproxy/haproxy.cfg
      if [ -f /run/haproxy.pid ]; then kill "$(cat /run/haproxy.pid)" 2>/dev/null || true; fi
      nohup haproxy -f /etc/haproxy/haproxy.cfg -db >>/var/log/gad/haproxy.log 2>&1 &
      echo $! >/run/haproxy.pid
    '
done

docker exec "$P-gslb" sh -c '
  if [ -f /run/gslb/controller.pid ]; then kill "$(cat /run/gslb/controller.pid)" 2>/dev/null || true; fi
  nohup sh /opt/gad/health-controller.sh >>/var/log/gad/controller.stderr 2>&1 &
  echo $! >/run/gslb/controller.pid
'

docker exec "$P-edge-cache" sh -c '
  cp /opt/gad/nginx.conf /etc/nginx/nginx.conf
  nginx -t
  if [ -s /run/nginx.pid ] && kill -0 "$(cat /run/nginx.pid)" 2>/dev/null; then
    nginx -s reload
  else
    rm -f /run/nginx.pid
    nginx
  fi
'

echo "Applied site-local LB, TLS/SNI, GSLB health policy, persistence, cache, and WAF policy."
