#!/usr/bin/env bash
# Prove spoke-to-spoke traffic enters and exits two distinct hub VTIs.
set -euo pipefail
prefix=clab-flexvpn-basics
capture_one=$(mktemp -t flexvpn-hairpin-vti1.XXXXXX)
capture_two=$(mktemp -t flexvpn-hairpin-vti2.XXXXXX)
pid_one=
pid_two=
cleanup() {
    [[ -z "$pid_one" ]] || kill "$pid_one" 2>/dev/null || true
    [[ -z "$pid_two" ]] || kill "$pid_two" 2>/dev/null || true
    rm -f "$capture_one" "$capture_two"
}
trap cleanup EXIT INT TERM
for node in gw-a host-b; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: flexvpn-basics is not fully deployed" >&2; exit 1;
    }
done
timeout 12 docker exec "$prefix-gw-a" tcpdump -lnni vti1 -c 2 icmp >"$capture_one" 2>&1 & pid_one=$!
timeout 12 docker exec "$prefix-gw-a" tcpdump -lnni vti2 -c 2 icmp >"$capture_two" 2>&1 & pid_two=$!
sleep 1
docker exec "$prefix-host-b" ping -c 2 -W 2 192.168.3.10 >/dev/null
wait "$pid_one"; pid_one=
wait "$pid_two"; pid_two=
sed -n '1,10p' "$capture_one"
sed -n '1,10p' "$capture_two"
for capture in "$capture_one" "$capture_two"; do
    if ! grep -qE '192\.168\.2\.10 > 192\.168\.3\.10: ICMP echo request' "$capture" \
        || ! grep -qE '192\.168\.3\.10 > 192\.168\.2\.10: ICMP echo reply' "$capture"; then
        echo "ERROR: both private directions were not visible on both hub VTIs" >&2
        exit 1
    fi
done
echo "PASS: one private flow traverses hub vti1 and vti2, proving decrypt-and-re-encrypt hairpinning."
