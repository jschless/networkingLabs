#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.70.10.20/24 dev eth1
ip route replace default via 10.70.10.1
ip link set eth1 up
cat >/tmp/jump-response.sh <<'EOF'
#!/bin/bash
printf 'jump host\n'
EOF
chmod +x /tmp/jump-response.sh
nohup socat TCP-LISTEN:22,reuseaddr,fork EXEC:/tmp/jump-response.sh >/tmp/jump.log 2>&1 &
