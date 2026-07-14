#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
for _ in $(seq 1 30); do
    access="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show lacp peer' || true)"
    dist="$(docker exec "$P-dist1" Cli -p 15 -c enable -c 'show lacp peer' || true)"
    if grep -Eq 'Et1[[:space:]]+Bundled' <<<"$access" && grep -Eq 'Et2[[:space:]]+Bundled' <<<"$access" && grep -Eq 'Et1[[:space:]]+Bundled' <<<"$dist" && grep -Eq 'Et2[[:space:]]+Bundled' <<<"$dist"; then break; fi
    sleep 1
done
grep -Eq 'Et1[[:space:]]+Bundled' <<<"$access" && grep -Eq 'Et2[[:space:]]+Bundled' <<<"$access"
grep -Eq 'Et1[[:space:]]+Bundled' <<<"$dist" && grep -Eq 'Et2[[:space:]]+Bundled' <<<"$dist"
docker exec "$P-campus1" ping -c 3 -W 1 10.252.20.10 >/dev/null
echo 'PASS: both LACP members are forwarding again and campus service remains healthy.'
