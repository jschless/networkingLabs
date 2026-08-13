#!/usr/bin/env bash
# Generate and validate a bounded inner-flow observation on gw-a tun0.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: labs/gre-ipsec/capture-tunnel.sh' '' \
        'Capture the healthy host flow on gw-a tun0 and require readable private ICMP.'
}

case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-gre-ipsec
capture_file=$(mktemp -t gre-ipsec-tunnel.XXXXXX)
capture_pid=
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    rm -f "$capture_file"
}
trap cleanup EXIT

for node in gw-a host-a; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: gre-ipsec is not fully deployed" >&2
        exit 1
    }
done

timeout 12 docker exec "$prefix-gw-a" \
    tcpdump -lnni tun0 -c 2 icmp >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-host-a" ping -c 2 -W 2 192.168.2.10 >/dev/null
if ! wait "$capture_pid"; then
    capture_pid=
    sed -n '1,12p' "$capture_file"
    echo "ERROR: bounded tunnel capture ended before collecting the required packets" >&2
    exit 1
fi
capture_pid=

sed -n '1,12p' "$capture_file"
if grep -qE '192\.168\.1\.10 > 192\.168\.2\.10: ICMP echo request' "$capture_file" \
    && grep -qE '192\.168\.2\.10 > 192\.168\.1\.10: ICMP echo reply' "$capture_file"; then
    echo "PASS: tun0 exposes the readable private flow above the encryption layer."
    exit 0
fi

echo "ERROR: the capture did not prove the required inner tunnel flow" >&2
exit 1
