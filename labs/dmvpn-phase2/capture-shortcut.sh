#!/usr/bin/env bash
# Prove one seeded spoke flow uses direct outer GRE rather than the hub.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase2/capture-shortcut.sh' \
        '' \
        'Seed the shortcuts, observe one bounded spoke1-to-spoke2 service' \
        'flow bridge-wide, and require direct outer GRE with no hub leg.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase2
lab_dir=$(cd "$(dirname "$0")" && pwd)
capture_file=$(mktemp -t dmvpn-phase2-capture.XXXXXX)
capture_pid=
cleanup() {
    [[ -z "$capture_pid" ]] || kill "$capture_pid" >/dev/null 2>&1 || true
    rm -f "$capture_file"
}
trap cleanup EXIT INT TERM

"$lab_dir/seed-shortcuts.sh" >/dev/null

# Ordinary unkeyed GRE has a four-byte header, making outer byte 33 the
# inner IPv4 protocol. Bridge-wide `any` observes the request and reply at
# both ingress and egress, so four records prove one direct exchange.
timeout 10 docker exec "$prefix-br-wan" tcpdump -l -nn -i any -c 4 \
    'ip proto 47 and ip[33] = 1' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 2 -W 1 \
    192.168.2.1 >/dev/null 2>&1 || {
    echo "ERROR: source-specific service traffic failed" >&2
    exit 1
}
wait "$capture_pid" || {
    echo "ERROR: bounded bridge-wide GRE capture did not collect four records" >&2
    exit 1
}
capture_pid=

capture=$(cat "$capture_file")
grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: GRE' <<<"$capture" || {
    echo "ERROR: capture lacks direct spoke1-to-spoke2 outer GRE" >&2
    exit 1
}
grep -qE '10\.0\.0\.12 > 10\.0\.0\.11: GRE' <<<"$capture" || {
    echo "ERROR: capture lacks direct spoke2-to-spoke1 outer GRE" >&2
    exit 1
}
if grep -qE '10\.0\.0\.11 > 10\.0\.0\.1: GRE|10\.0\.0\.1 > 10\.0\.0\.12: GRE' \
        <<<"$capture"; then
    echo "ERROR: seeded traffic still traversed the hub" >&2
    exit 1
fi

printf '%s\n' "$capture"
echo "PASS: bridge-wide evidence shows direct spoke GRE and no hub-facing leg."
