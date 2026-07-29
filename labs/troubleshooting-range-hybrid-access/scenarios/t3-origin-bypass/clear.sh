#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access

while docker exec "$prefix-cloud-edge" iptables -C FORWARD \
    -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8443 \
    -m comment --comment range-t3-origin-bypass -j ACCEPT >/dev/null 2>&1; do
    docker exec "$prefix-cloud-edge" iptables -D FORWARD \
        -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8443 \
        -m comment --comment range-t3-origin-bypass -j ACCEPT
done
while docker exec "$prefix-cloud-edge" ip6tables -C FORWARD \
    -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8443 \
    -m comment --comment range-t3-origin-bypass -j ACCEPT >/dev/null 2>&1; do
    docker exec "$prefix-cloud-edge" ip6tables -D FORWARD \
        -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8443 \
        -m comment --comment range-t3-origin-bypass -j ACCEPT
done
