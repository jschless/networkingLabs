#!/usr/bin/env bash
# Prove bidirectional ESP-in-UDP at the public side of the NAT boundary.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-ipsec-nat-t/lab-lib.sh
source "$lab_dir/lab-lib.sh"
capture_file=$(mktemp -t opnsense-natt-capture.XXXXXX)
capture_pid=

cleanup() {
    if [[ -n "$capture_pid" ]]; then
        kill "$capture_pid" 2>/dev/null || true
        docker exec "$NATT_PREFIX-nat-cpe" pkill -TERM -f \
            '^tcpdump -lnni eth1 -c 4 udp port 4500$' 2>/dev/null || true
    fi
    rm -f "$capture_file"
}
on_signal() {
    local status=$1
    trap - INT TERM
    exit "$status"
}
trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

natt_require_tools
natt_require_containers
[[ "$(natt_fault_count)" == 0 ]] \
    || { echo "ERROR: repair the boundary fault before capturing healthy traffic" >&2; exit 1; }

timeout 15 docker exec "$NATT_PREFIX-nat-cpe" \
    timeout 12 tcpdump -lnni eth1 -c 4 'udp port 4500' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$NATT_PREFIX-hq-host" ping -c 3 -W 2 10.20.1.10 >/dev/null
docker exec "$NATT_PREFIX-branch-host" ping -c 3 -W 2 10.10.1.10 >/dev/null
if ! wait "$capture_pid"; then
    capture_pid=
    sed -n '1,12p' "$capture_file"
    echo "ERROR: bounded capture did not collect the required NAT-T packets" >&2
    exit 1
fi
capture_pid=

sed -n '1,12p' "$capture_file"
if grep -qE '198\.51\.100\.2\.4500 > 198\.51\.100\.1\.4500: UDP-encap: ESP' "$capture_file" \
    && grep -qE '198\.51\.100\.1\.4500 > 198\.51\.100\.2\.4500: UDP-encap: ESP' "$capture_file" \
    && ! grep -qE '10\.(10|20)\.1\.|ICMP echo' "$capture_file"; then
    echo "PASS: bounded public capture proves bidirectional ESP-in-UDP with no readable protected addresses."
else
    echo "ERROR: outer capture did not prove the required protected NAT-T flow" >&2
    exit 1
fi
