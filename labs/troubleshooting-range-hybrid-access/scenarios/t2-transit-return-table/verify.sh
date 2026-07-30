#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
campus="$prefix-campus-edge"
cloud="$prefix-cloud-edge"
client="$prefix-managed-client"
probe=(docker exec "$client" python3 /opt/range/http_probe.py)

ipv4_returns="$(docker exec "$cloud" ip route show exact 10.70.10.0/24)"
grep -Eq \
    '^10\.70\.10\.0/24 via 10\.70\.24\.1 dev eth1 metric 10[[:space:]]*$' \
    <<<"$ipv4_returns"
grep -Eq \
    '^10\.70\.10\.0/24 via 10\.70\.25\.1 dev eth2 metric 100[[:space:]]*$' \
    <<<"$ipv4_returns"
[[ "$(wc -l <<<"$ipv4_returns")" -eq 2 ]]

ipv6_returns="$(
    docker exec "$cloud" ip -6 route show exact 2001:db8:70:10::/64
)"
grep -qx \
    '2001:db8:70:10::/64 via 2001:db8:70:24::1 dev eth1 metric 10 pref medium' \
    <<<"$ipv6_returns"
grep -qx \
    '2001:db8:70:10::/64 via 2001:db8:70:25::1 dev eth2 metric 100 pref medium' \
    <<<"$ipv6_returns"
[[ "$(wc -l <<<"$ipv6_returns")" -eq 2 ]]

[[ -z "$(docker exec "$cloud" ip route show exact 10.70.10.10/32)" ]]
[[ -z "$(
    docker exec "$cloud" ip -6 route show exact 2001:db8:70:10::10/128
)" ]]
docker exec "$cloud" sh -c \
    "ip route get 10.70.10.10 | grep -q 'via 10.70.24.1 dev eth1'"
docker exec "$cloud" sh -c \
    "ip -6 route get 2001:db8:70:10::10 |
         grep -q 'via 2001:db8:70:24::1 dev eth1'"
docker exec "$campus" sh -c \
    "ip route get 10.70.41.40 | grep -q 'via 10.70.12.2'"
docker exec "$campus" sh -c \
    "ip -6 route get 2001:db8:70:41::40 |
         grep -q 'via 2001:db8:70:12::2'"

"${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 2001:db8:70:41::40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 10.70.42.40 8080 cloud-app-b-ok >/dev/null
"${probe[@]}" 10.70.30.30 9443 protected-app-ok \
    X-Client-Cert=managed-valid >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied \
    X-Client-Cert=invalid >/dev/null
"${probe[@]}" --expect-denied 10.70.41.40 8443 >/dev/null
"${probe[@]}" --expect-denied 2001:db8:70:41::40 8443 >/dev/null

docker exec "$client" sh -c \
    "dig +short @10.70.53.53 analytics.hybrid.test A |
         grep -qx 10.70.41.40"
docker exec "$client" sh -c \
    "dig +short @2001:db8:70:53::53 analytics.hybrid.test AAAA |
         grep -qx 2001:db8:70:41::40"
docker exec "$cloud" sh -c \
    "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
docker exec "$cloud" sh -c \
    "ip6tables -S FORWARD | grep -qx -- '-P FORWARD DROP'"

echo "PASS: both preferred and standby transit return routes are intact, IPv4/IPv6 services work end to end, identity and origin policy remain enforced, and no client host-route workaround exists."
