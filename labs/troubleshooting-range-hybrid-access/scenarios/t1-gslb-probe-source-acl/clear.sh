#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
cloud="$prefix-cloud-edge"
dns="$prefix-dns"

docker exec "$dns" sh -c "
    if test -s /run/range-t1-gslb-controller.pid; then
        scenario_pid=\"\$(cat /run/range-t1-gslb-controller.pid)\"
        kill \"\$scenario_pid\" 2>/dev/null || true
        wait_count=0
        while kill -0 \"\$scenario_pid\" 2>/dev/null && test \"\$wait_count\" -lt 20; do
            sleep 0.1
            wait_count=\$((wait_count + 1))
        done
    fi
    rm -f \
        /run/range-t1-gslb-controller.pid \
        /run/range-t1-gslb-controller.py \
        /run/range-t1-gslb-dnsmasq.conf \
        /run/range-t1-gslb-hosts \
        /run/range-t1-gslb-hosts.new \
        /run/range-t1-gslb-state.env \
        /run/range-t1-gslb-state.env.new
    sh /opt/range/golden/reset.sh
"

delete_rule() {
    while docker exec "$cloud" iptables -C FORWARD "$@" >/dev/null 2>&1; do
        docker exec "$cloud" iptables -D FORWARD "$@"
    done
}

delete_rule \
    -s 10.70.53.53 -d 10.70.42.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-deny -j REJECT
delete_rule \
    -s 10.70.53.53 -d 10.70.41.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
delete_rule \
    -s 10.70.53.53 -d 10.70.42.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
