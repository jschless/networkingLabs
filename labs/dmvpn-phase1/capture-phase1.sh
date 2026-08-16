#!/usr/bin/env bash
# Observe one bounded service flow across the shared WAN and prove hub transit.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase1/capture-phase1.sh' \
        '' \
        'Observe a bounded spoke1-to-spoke2 service flow across the WAN bridge' \
        'and prove both hub legs while rejecting a direct spoke-to-spoke leg.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase1
capture_file=$(mktemp -t dmvpn-phase1-capture.XXXXXX)
capture_pid=
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" >/dev/null 2>&1 || true
    rm -f "$capture_file"
}
trap cleanup EXIT INT TERM

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase1 is not fully deployed" >&2
        exit 1
    }
done

# The validated tunnels use ordinary 20-byte outer IPv4 plus four-byte
# unkeyed GRE headers, so byte 33 is the inner IPv4 protocol field. Requiring
# ICMP excludes background OSPF-over-GRE. Bridge-wide `any` capture sees each
# packet once on ingress and once on egress, so one request/reply needs eight
# records to cover the two hub-facing GRE legs in each direction.
timeout 10 docker exec "$prefix-br-wan" tcpdump -l -nn -i any -c 8 \
    'ip proto 47 and ip[33] = 1' \
    >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 2 -W 1 \
    192.168.2.1 >/dev/null 2>&1 || {
    echo "ERROR: source-specific service traffic failed" >&2
    exit 1
}
wait "$capture_pid" || {
    echo "ERROR: bounded bridge-wide GRE capture did not collect eight records" >&2
    exit 1
}
capture_pid=

capture=$(cat "$capture_file")
grep -qE '10\.0\.0\.11 > 10\.0\.0\.1: GRE' <<<"$capture" || {
    echo "ERROR: capture lacks spoke1-to-hub outer GRE" >&2
    exit 1
}
grep -qE '10\.0\.0\.1 > 10\.0\.0\.12: GRE' <<<"$capture" || {
    echo "ERROR: capture lacks hub-to-spoke2 outer GRE" >&2
    exit 1
}
if grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: GRE' <<<"$capture"; then
    echo "ERROR: direct spoke1-to-spoke2 outer GRE bypassed the Phase 1 hub" >&2
    exit 1
fi

printf '%s\n' "$capture"
echo "PASS: bridge-wide evidence shows both hub GRE legs and no direct spoke leg."
