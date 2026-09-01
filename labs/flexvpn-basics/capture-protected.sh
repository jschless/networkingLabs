#!/usr/bin/env bash
# Prove the spoke1 WAN branch carries public ESP and no readable private flow.
set -euo pipefail
prefix=clab-flexvpn-basics
capture_file=$(mktemp -t flexvpn-protected.XXXXXX)
capture_pid=
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    rm -f "$capture_file"
}
trap cleanup EXIT INT TERM
for node in internet host-b; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: flexvpn-basics is not fully deployed" >&2; exit 1;
    }
done
timeout 12 docker exec "$prefix-internet" tcpdump -lnni eth2 -c 4 \
    'ip proto 50 or net 192.168.0.0/16' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-host-b" ping -c 3 -W 2 192.168.1.10 >/dev/null
if ! wait "$capture_pid"; then
    capture_pid=; sed -n '1,14p' "$capture_file"
    echo "ERROR: protected capture did not collect four packets" >&2; exit 1
fi
capture_pid=
sed -n '1,14p' "$capture_file"
if grep -qE '203\.0\.113\.6 > 203\.0\.113\.1: ESP' "$capture_file" \
    && grep -qE '203\.0\.113\.1 > 203\.0\.113\.6: ESP' "$capture_file" \
    && ! grep -qE '192\.168\.|ICMP echo' "$capture_file"; then
    echo "PASS: the spoke1 WAN branch exposes bidirectional public ESP only."
else
    echo "ERROR: WAN evidence did not prove protected bidirectional traffic" >&2; exit 1
fi
