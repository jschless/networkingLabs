#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
campus="$prefix-campus-edge"
client="$prefix-managed-client"
dir="$(cd "$(dirname "$0")" && pwd)"
config=/run/range-t1-ipv6-radvd.conf
pidfile=/run/range-t1-ipv6-radvd.pid
resolver_backup=/run/range-t1-ipv6-resolv.conf.golden

"$dir/clear.sh"

docker exec "$client" cp /etc/resolv.conf "$resolver_backup"
docker exec "$campus" sh -c "umask 077; {
    echo 'interface eth1 {'
    echo '  AdvSendAdvert on;'
    echo '  MinRtrAdvInterval 3;'
    echo '  MaxRtrAdvInterval 4;'
    echo '  AdvDefaultLifetime 60;'
    echo '  prefix 2001:db8:70:10::/64 {'
    echo '    AdvOnLink on;'
    echo '    AdvAutonomous on;'
    echo '  };'
    echo '  RDNSS 2001:db8:70:53::53 {'
    echo '    AdvRDNSSLifetime 60;'
    echo '  };'
    echo '};'
} > '$config'"
docker exec -d "$campus" python3 -c "
import ctypes
import os
import subprocess

ctypes.CDLL(None).prctl(36, 1, 0, 0, 0)
subprocess.run(
    ['radvd', '-n', '-C', '$config', '-p', '$pidfile'],
    check=False,
)
while True:
    try:
        os.waitpid(-1, 0)
    except ChildProcessError:
        break
"

for _ in $(seq 1 20); do
    if docker exec "$campus" sh -c \
        "test -s '$pidfile' && kill -0 \"\$(cat '$pidfile')\"" >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done
docker exec "$campus" sh -c \
    "test -s '$pidfile' && kill -0 \"\$(cat '$pidfile')\""

docker exec "$client" sh -c \
    "printf 'nameserver 2001:db8:70:53::53\n' > /etc/resolv.conf"
docker exec "$client" sysctl -w net.ipv6.conf.eth1.accept_ra=0 >/dev/null
while docker exec "$client" ip -6 route del default >/dev/null 2>&1; do :; done

ra="$(
    docker exec "$client" timeout 10 tcpdump -ni eth1 -c 1 -vv \
        'icmp6 and ip6[40] == 134' 2>&1
)"
grep -q 'router lifetime 60s' <<<"$ra"
grep -q 'rdnss option' <<<"$ra"
grep -q '2001:db8:70:53::53' <<<"$ra"

if docker exec "$client" ip -6 route show default | grep -q .; then
    echo "ERROR: IPv6 default-path symptom was not established" >&2
    exit 1
fi
if docker exec "$client" dig +time=1 +tries=1 +short \
    analytics.hybrid.test AAAA 2>/dev/null | grep -q .; then
    echo "ERROR: IPv6 DNS symptom was not established" >&2
    exit 1
fi
if docker exec "$client" python3 /opt/range/http_probe.py \
    2001:db8:70:41::40 8080 cloud-app-a-ok >/dev/null 2>&1; then
    echo "ERROR: IPv6 application symptom was not established" >&2
    exit 1
fi
docker exec "$client" python3 /opt/range/http_probe.py \
    10.70.41.40 8080 cloud-app-a-ok >/dev/null
docker exec "$client" ip route get 10.70.41.40 |
    grep -q 'via 10.70.10.1'

echo "Ticket symptom is active: IPv6 DNS and the default path are absent while the advertised IPv6 settings remain visible and IPv4 application access stays healthy."
