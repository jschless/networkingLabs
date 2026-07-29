#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
cloud="$prefix-cloud-edge"
client="$prefix-managed-client"
dns="$prefix-dns"
controller=/run/range-t1-gslb-controller.py
state=/run/range-t1-gslb-state.env
probe=(docker exec "$client" python3 /opt/range/http_probe.py)

docker exec "$dns" sh -c \
    "test -s /run/range-t1-gslb-controller.pid &&
     kill -0 \"\$(cat /run/range-t1-gslb-controller.pid)\" &&
     tr '\\000' ' ' < /proc/\$(cat /run/range-t1-gslb-controller.pid)/cmdline |
         grep -q '$controller'"
docker exec "$dns" sh -c \
    "test -s /run/range-dnsmasq.pid &&
     kill -0 \"\$(cat /run/range-dnsmasq.pid)\" &&
     tr '\\000' ' ' < /proc/\$(cat /run/range-dnsmasq.pid)/cmdline |
         grep -q -- '--conf-file=/run/range-t1-gslb-dnsmasq.conf'"

fresh_probe="$(docker exec "$dns" python3 "$controller" --probe-only)"
grep -qx 'generation_mode=health-probe' <<<"$fresh_probe"
grep -qx 'probe_source=10.70.53.53' <<<"$fresh_probe"
grep -qx 'probe_port=8081' <<<"$fresh_probe"
grep -qx 'site_a=healthy' <<<"$fresh_probe"
grep -qx 'site_b=healthy' <<<"$fresh_probe"

for _ in $(seq 1 20); do
    if docker exec "$dns" sh -c \
        "grep -qx 'site_a=healthy' '$state' &&
         grep -qx 'site_b=healthy' '$state'"; then
        break
    fi
    sleep 0.25
done
record="$(docker exec "$dns" cat "$state")"
field() {
    local key=$1
    awk -F= -v key="$key" '$1 == key { print $2 }' <<<"$record"
}
[[ "$(field generation_mode)" == health-probe ]]
[[ "$(field probe_source)" == 10.70.53.53 ]]
[[ "$(field probe_port)" == 8081 ]]
[[ "$(field site_a_endpoint)" == 10.70.41.40:8081 ]]
[[ "$(field site_a)" == healthy ]]
[[ "$(field site_b_endpoint)" == 10.70.42.40:8081 ]]
[[ "$(field site_b)" == healthy ]]
checked_epoch="$(field checked_epoch)"
[[ "$checked_epoch" =~ ^[0-9]+$ ]]
age=$(( $(date +%s) - checked_epoch ))
(( age >= -5 && age <= 8 ))

mapfile -t a_answers < <(
    docker exec "$client" dig +short @10.70.53.53 global.hybrid.test A | sort
)
mapfile -t aaaa_answers < <(
    docker exec "$client" dig +short @2001:db8:70:53::53 \
        global.hybrid.test AAAA | sort
)
[[ "${a_answers[*]}" == "10.70.41.40 10.70.42.40" ]]
[[ "${aaaa_answers[*]}" == \
    "2001:db8:70:41::40 2001:db8:70:42::40" ]]

expected_hosts="$(
    printf '%s\n' \
        '10.70.41.40 global.hybrid.test' \
        '10.70.42.40 global.hybrid.test' \
        '2001:db8:70:41::40 global.hybrid.test' \
        '2001:db8:70:42::40 global.hybrid.test' |
        sort
)"
actual_hosts="$(docker exec "$dns" sort /run/range-t1-gslb-hosts)"
[[ "$actual_hosts" == "$expected_hosts" ]]
docker exec "$dns" sh -c \
    "grep -qx 'addn-hosts=/run/range-t1-gslb-hosts' \
         /run/range-t1-gslb-dnsmasq.conf &&
     ! grep -q 'address=/global\\.hybrid\\.test' \
         /run/range-t1-gslb-dnsmasq.conf"
docker exec "$client" sh -c "! grep -q 'global\\.hybrid\\.test' /etc/hosts"

docker exec "$cloud" iptables -C FORWARD \
    -s 10.70.53.53 -d 10.70.41.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
docker exec "$cloud" iptables -C FORWARD \
    -s 10.70.53.53 -d 10.70.42.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
docker exec "$cloud" sh -c \
    "! iptables -S FORWARD | grep -q range-t1-gslb-probe-deny"
docker exec "$cloud" sh -c \
    "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"

dns_source_accepts="$(
    docker exec "$cloud" iptables -S FORWARD |
        grep -E -- '-s 10\.70\.53\.[0-9]+/[0-9]+' |
        grep -- '-j ACCEPT$' || true
)"
[[ "$(wc -l <<<"$dns_source_accepts")" -eq 2 ]]
site_b_accepts="$(
    docker exec "$cloud" iptables -S FORWARD |
        grep -- '-d 10.70.42.40/32' |
        grep -- '-j ACCEPT$' || true
)"
[[ "$(wc -l <<<"$site_b_accepts")" -eq 2 ]]

"${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 10.70.42.40 8080 cloud-app-b-ok >/dev/null
"${probe[@]}" 10.70.42.40 8081 cloud-health-b-ok >/dev/null
"${probe[@]}" --expect-denied 10.70.41.40 8443 >/dev/null

echo "PASS: fresh source-bound health probes mark both sites healthy, health-driven A/AAAA results contain both sites, narrow probe policy and default deny remain intact, and forced static answers or host overrides do not satisfy this verifier."
