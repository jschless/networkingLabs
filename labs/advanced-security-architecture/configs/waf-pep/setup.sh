#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.114.30.10/24 dev eth1
ip link set eth1 up
ip route replace default via 10.114.30.1
mkdir -p /run/asa /var/log/modsecurity
cat >/etc/nginx/modsecurity-lab.conf <<'EOF'
SecRuleEngine DetectionOnly
SecRequestBodyAccess On
SecAuditEngine RelevantOnly
SecAuditLogType Serial
SecAuditLog /var/log/modsecurity/audit.log
EOF
nginx -c /opt/lab/nginx.conf
nohup python3 /opt/lab/pep.py >/tmp/pep.log 2>&1 &
