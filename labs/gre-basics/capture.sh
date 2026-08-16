#!/usr/bin/env bash
# Generate and validate a bounded clear-text GRE observation for Task 3.
set -euo pipefail

prefix=clab-gre-basics
capture_file=$(mktemp)
capture_pid=
# shellcheck disable=SC2329  # Invoked by the EXIT trap below.
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    rm -f "$capture_file"
}
trap cleanup EXIT

for node in internet host-a; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: gre-basics is not fully deployed" >&2
        exit 1
    }
done

timeout 12 docker exec "$prefix-internet" \
    tcpdump -lni eth1 -c 2 'ip proto 47' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-host-a" ping -c 2 -W 2 192.168.2.10 >/dev/null
wait "$capture_pid"
capture_pid=

sed -n '1,12p' "$capture_file"
if grep -q 'GREv0' "$capture_file" \
    && grep -qE '192\.168\.1\.10 > 192\.168\.2\.10: ICMP echo request' "$capture_file"; then
    echo "PASS: the bounded WAN capture exposes both GRE and the inner ICMP request."
    exit 0
fi

echo "ERROR: the bounded capture did not show the required encapsulated flow" >&2
exit 1
