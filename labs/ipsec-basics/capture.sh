#!/usr/bin/env bash
# Generate and validate a bounded outer-only ESP observation for Task 3.
set -euo pipefail

prefix=clab-ipsec-basics
capture_file=$(mktemp -t ipsec-basics-capture.XXXXXX)
capture_pid=

# shellcheck disable=SC2329  # Invoked by the EXIT trap below.
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    rm -f "$capture_file"
}
trap cleanup EXIT

for node in internet host-a; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: ipsec-basics is not fully deployed" >&2
        exit 1
    }
done

timeout 12 docker exec "$prefix-internet" \
    tcpdump -lni eth1 -c 4 'esp or icmp' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-host-a" ping -c 3 -W 2 192.168.2.10 >/dev/null
wait "$capture_pid"
capture_pid=

sed -n '1,12p' "$capture_file"
if grep -qE '203\.0\.113\.1 > 203\.0\.113\.6: ESP' "$capture_file" \
    && grep -qE '203\.0\.113\.6 > 203\.0\.113\.1: ESP' "$capture_file" \
    && ! grep -qE '192\.168\.[12]\.|ICMP echo' "$capture_file"; then
    echo "PASS: the bounded WAN capture shows bidirectional outer ESP only."
    exit 0
fi

echo "ERROR: the capture did not prove the required outer-only ESP flow" >&2
exit 1
