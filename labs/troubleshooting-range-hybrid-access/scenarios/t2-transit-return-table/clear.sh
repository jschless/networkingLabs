#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
cloud="$prefix-cloud-edge"

while docker exec "$cloud" ip route del blackhole \
    10.70.10.0/24 metric 5 >/dev/null 2>&1; do
    :
done
while docker exec "$cloud" ip -6 route del blackhole \
    2001:db8:70:10::/64 metric 5 >/dev/null 2>&1; do
    :
done
