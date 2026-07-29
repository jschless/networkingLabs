#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
campus="$prefix-campus-edge"
client="$prefix-managed-client"
pidfile=/run/range-t1-ipv6-radvd.pid
probe=(docker exec "$client" python3 /opt/range/http_probe.py)

[[ "$(docker exec "$client" sysctl -n net.ipv6.conf.eth1.accept_ra)" == 1 ]]
docker exec "$campus" sh -c \
    "test -s '$pidfile' && kill -0 \"\$(cat '$pidfile')\""

ra="$(
    docker exec "$client" timeout 10 tcpdump -ni eth1 -c 1 -vv \
        'icmp6 and ip6[40] == 134' 2>&1
)"
grep -q 'router lifetime 60s' <<<"$ra"
grep -q 'rdnss option' <<<"$ra"
grep -q '2001:db8:70:53::53' <<<"$ra"

for _ in $(seq 1 12); do
    if docker exec "$client" ip -6 route show default |
        grep -Eq '^default via fe80::[0-9a-f:]+ dev eth1 proto ra .*expires'; then
        break
    fi
    sleep 1
done

routes="$(docker exec "$client" ip -6 route show default)"
[[ "$(wc -l <<<"$routes")" -eq 1 ]]
grep -Eq '^default via fe80::[0-9a-f:]+ dev eth1 proto ra .*expires' <<<"$routes"

nameservers="$(
    docker exec "$client" awk '$1 == "nameserver" { print $2 }' /etc/resolv.conf
)"
[[ "$nameservers" == 2001:db8:70:53::53 ]]
docker exec "$client" sh -c "! grep -q 'hybrid\\.test' /etc/hosts"

docker exec "$client" dig +time=2 +tries=2 +short \
    analytics.hybrid.test AAAA | grep -qx 2001:db8:70:41::40
"${probe[@]}" 2001:db8:70:41::40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" --expect-denied 2001:db8:70:41::40 8443 >/dev/null

docker exec "$prefix-cloud-edge" sh -c \
    "ip6tables -S FORWARD | grep -qx -- '-P FORWARD DROP'"

echo "PASS: the client accepts the live router advertisement, learns its sole IPv6 default as proto ra, uses the advertised IPv6 DNS service for the AAAA answer, reaches the application over IPv6, and retains protected-origin denial; IPv4-only and static-route workarounds do not satisfy this verifier."
