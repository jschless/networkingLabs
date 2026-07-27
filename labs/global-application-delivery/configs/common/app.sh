#!/bin/sh
set -eu
SITE="$1"
BACKEND="$2"
ADDRESS="$3"
ip addr flush dev eth1
ip addr add "$ADDRESS/24" dev eth1
ip link set eth1 up
mkdir -p /run/nginx /var/lib/nginx/html
cat >/etc/nginx/http.d/default.conf <<EOF
log_format gad '\$time_iso8601 site=$SITE backend=$BACKEND host=\$host request_id=\$http_x_request_id client=\$http_x_forwarded_for path=\$uri status=\$status';
access_log /var/log/nginx/access.log gad;
server {
  listen 8080;
  add_header X-Site "$SITE" always;
  add_header X-Backend "$BACKEND" always;
  location = /health {
    default_type text/plain;
    return 200 "healthy site=$SITE backend=$BACKEND\n";
  }
  location = /assets/version.txt {
    default_type text/plain;
    add_header Cache-Control "public, max-age=5" always;
    add_header X-Site "$SITE" always;
    add_header X-Backend "$BACKEND" always;
    return 200 "asset-version=1 site=$SITE backend=$BACKEND\n";
  }
  location / {
    default_type text/plain;
    return 200 "site=$SITE backend=$BACKEND host=\$host request_id=\$http_x_request_id client=\$http_x_forwarded_for\n";
  }
}
EOF
nginx
