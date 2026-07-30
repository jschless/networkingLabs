#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
cloud="$prefix-cloud-edge"
client="$prefix-managed-client"
dns="$prefix-dns"
dir="$(cd "$(dirname "$0")" && pwd)"
controller=/run/range-t1-gslb-controller.py
runtime_config=/run/range-t1-gslb-dnsmasq.conf
state=/run/range-t1-gslb-state.env

"$dir/clear.sh"

docker exec "$cloud" iptables -I FORWARD 1 \
    -s 10.70.53.53 -d 10.70.41.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
docker exec "$cloud" iptables -I FORWARD 1 \
    -s 10.70.53.53 -d 10.70.42.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
docker exec "$cloud" iptables -I FORWARD 1 \
    -s 10.70.53.53 -d 10.70.42.40 -p tcp --dport 8081 \
    -m comment --comment range-t1-gslb-probe-deny -j REJECT

docker cp "$dir/gslb_controller.py" "$dns:$controller" >/dev/null
docker exec "$dns" sh -c "
    cp /opt/range/golden/dnsmasq.conf '$runtime_config'
    printf '\\naddn-hosts=/run/range-t1-gslb-hosts\\n' >> '$runtime_config'
    if test -s /run/range-dnsmasq.pid; then
        kill \"\$(cat /run/range-dnsmasq.pid)\" 2>/dev/null || true
    fi
    rm -f /run/range-dnsmasq.pid
    dnsmasq --conf-file='$runtime_config'
"
docker exec -d "$dns" python3 "$controller"

for _ in $(seq 1 40); do
    if docker exec "$dns" sh -c \
        "test -s '$state' &&
         grep -qx 'site_a=healthy' '$state' &&
         grep -qx 'site_b=down' '$state'"; then
        break
    fi
    sleep 0.25
done
docker exec "$dns" sh -c \
    "test -s '$state' &&
     grep -qx 'generation_mode=health-probe' '$state' &&
     grep -qx 'probe_source=10.70.53.53' '$state' &&
     grep -qx 'site_a=healthy' '$state' &&
     grep -qx 'site_b=down' '$state'"

mapfile -t a_answers < <(
    docker exec "$client" dig +short @10.70.53.53 global.hybrid.test A | sort
)
mapfile -t aaaa_answers < <(
    docker exec "$client" dig +short @10.70.53.53 global.hybrid.test AAAA | sort
)
[[ "${a_answers[*]}" == "10.70.41.40" ]]
[[ "${aaaa_answers[*]}" == "2001:db8:70:41::40" ]]

docker exec "$client" python3 /opt/range/http_probe.py \
    10.70.42.40 8080 cloud-app-b-ok >/dev/null
docker exec "$client" python3 /opt/range/http_probe.py \
    10.70.42.40 8081 cloud-health-b-ok >/dev/null

echo "Ticket symptom is active: health-driven service results omit site B even though its regional application and health endpoint remain healthy."
