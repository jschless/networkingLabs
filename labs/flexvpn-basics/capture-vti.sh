#!/usr/bin/env bash
# Prove the same protected flow is readable above XFRM on spoke1 vti0.
set -euo pipefail
prefix=clab-flexvpn-basics
capture_file=$(mktemp -t flexvpn-vti.XXXXXX)
capture_pid=
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    rm -f "$capture_file"
}
trap cleanup EXIT INT TERM
for node in gw-b host-b; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: flexvpn-basics is not fully deployed" >&2; exit 1;
    }
done
timeout 12 docker exec "$prefix-gw-b" tcpdump -lnni vti0 -c 2 icmp >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-host-b" ping -c 2 -W 2 192.168.1.10 >/dev/null
if ! wait "$capture_pid"; then
    capture_pid=; sed -n '1,12p' "$capture_file"
    echo "ERROR: VTI capture did not collect the private request/reply" >&2; exit 1
fi
capture_pid=
sed -n '1,12p' "$capture_file"
if grep -qE '192\.168\.2\.10 > 192\.168\.1\.10: ICMP echo request' "$capture_file" \
    && grep -qE '192\.168\.1\.10 > 192\.168\.2\.10: ICMP echo reply' "$capture_file"; then
    echo "PASS: vti0 exposes the readable inner flow above the ESP layer."
else
    echo "ERROR: VTI evidence did not prove the expected inner flow" >&2; exit 1
fi
