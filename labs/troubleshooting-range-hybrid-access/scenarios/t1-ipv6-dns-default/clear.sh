#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
campus="$prefix-campus-edge"
client="$prefix-managed-client"
config=/run/range-t1-ipv6-radvd.conf
pidfile=/run/range-t1-ipv6-radvd.pid
resolver_backup=/run/range-t1-ipv6-resolv.conf.golden

docker exec "$campus" sh -c "
    if test -s '$pidfile'; then
        scenario_pid=\"\$(cat '$pidfile')\"
        kill \"\$scenario_pid\" 2>/dev/null || true
        wait_count=0
        while kill -0 \"\$scenario_pid\" 2>/dev/null && test \"\$wait_count\" -lt 20; do
            sleep 0.1
            wait_count=\$((wait_count + 1))
        done
    fi
    rm -f '$pidfile' '$config'
"

docker exec "$client" sysctl -w net.ipv6.conf.eth1.accept_ra=1 >/dev/null
while docker exec "$client" ip -6 route del default >/dev/null 2>&1; do :; done
docker exec "$client" ip -6 route replace default \
    via 2001:db8:70:10::1 dev eth1
docker exec "$client" sh -c "
    if test -f '$resolver_backup'; then
        if sed -n 'p' '$resolver_backup' > /etc/resolv.conf; then
            rm -f '$resolver_backup'
        else
            exit 1
        fi
    fi
"
