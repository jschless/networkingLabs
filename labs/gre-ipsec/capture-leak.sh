#!/usr/bin/env bash
# Generate and validate bounded raw-GRE leakage during the Task 5 fault.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: labs/gre-ipsec/capture-leak.sh' '' \
        'During the armed fault, capture the host flow and require raw GRE/private ICMP without ESP.'
}

case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-gre-ipsec
capture_file=$(mktemp -t gre-ipsec-leak.XXXXXX)
capture_pid=
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    rm -f "$capture_file"
}
trap cleanup EXIT

for node in internet host-a; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: gre-ipsec is not fully deployed" >&2
        exit 1
    }
done

timeout 12 docker exec "$prefix-internet" \
    tcpdump -lnni eth1 -c 4 'ip proto 47 or ip proto 50' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-host-a" ping -c 3 -W 2 192.168.2.10 >/dev/null
if ! wait "$capture_pid"; then
    capture_pid=
    sed -n '1,14p' "$capture_file"
    echo "ERROR: bounded leak capture ended before collecting the required packets" >&2
    exit 1
fi
capture_pid=

sed -n '1,14p' "$capture_file"
if grep -qE '203\.0\.113\.1 > 203\.0\.113\.6: GREv0' "$capture_file" \
    && grep -qE '203\.0\.113\.6 > 203\.0\.113\.1: GREv0' "$capture_file" \
    && grep -qE '192\.168\.1\.10 > 192\.168\.2\.10: ICMP echo request' "$capture_file" \
    && ! grep -q 'ESP' "$capture_file"; then
    echo "PASS: connectivity survives, but the WAN exposes raw GRE and readable private ICMP."
    exit 0
fi

echo "ERROR: the capture did not prove the required clear-text fallback" >&2
exit 1
