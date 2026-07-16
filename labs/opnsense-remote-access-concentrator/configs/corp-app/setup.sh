#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.70.10.10/24 dev eth1
ip route replace default via 10.70.10.1
ip link set eth1 up
cat >/tmp/app-response.sh <<'EOF'
#!/bin/bash
printf 'corp application\n'
EOF
chmod +x /tmp/app-response.sh
nohup socat TCP-LISTEN:8443,reuseaddr,fork EXEC:/tmp/app-response.sh >/tmp/app.log 2>&1 &
