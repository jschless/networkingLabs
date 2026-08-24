#!/usr/bin/env bash
# Prove one seeded service flow uses direct outer GRE rather than the hub.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3/capture-shortcut.sh' \
        '' \
        'Seed shortcuts, observe one bounded spoke1-to-spoke2 flow bridge-wide,' \
        'and require direct outer GRE with no hub-facing leg.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3
lab_dir=$(cd "$(dirname "$0")" && pwd)
capture_file=$(mktemp -t dmvpn-phase3-capture.XXXXXX)
capture_pid=
stop_capture() {
    local pid=${capture_pid:-} _attempt
    [[ -n "$pid" ]] || return 0
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill -TERM -- "-$pid" >/dev/null 2>&1 || true
        for _attempt in $(seq 1 20); do
            kill -0 "$pid" >/dev/null 2>&1 || break
            sleep 0.1
        done
        kill -KILL -- "-$pid" >/dev/null 2>&1 || true
    fi
    wait "$pid" >/dev/null 2>&1 || true
    capture_pid=
}
cleanup() {
    stop_capture
    rm -f "$capture_file"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$lab_dir/seed-shortcuts.sh" >/dev/null

# With a 20-byte outer IPv4 header, ordinary unkeyed GRE stores its payload
# protocol at bytes 22-23; require 0x0800 (inner IPv4) before treating outer
# byte 33 as the inner IPv4 protocol. This excludes NHRP/control GRE whose byte
# 33 can otherwise alias ICMP. `any` duplicates records across bridge ingress
# and egress, so capture a complete bounded window instead of a fixed count.
setsid --wait timeout --signal=INT --kill-after=2 8 \
    docker exec "$prefix-br-wan" tcpdump -l -nn -i any \
    'ip proto 47 and ip[22:2] = 0x0800 and ip[33] = 1' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
timeout 8 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 3 -W 1 \
    192.168.2.1 >/dev/null 2>&1 || {
    echo "ERROR: source-specific service traffic failed" >&2
    exit 1
}
capture_status=0
wait "$capture_pid" || capture_status=$?
capture_pid=
if (( capture_status != 0 && capture_status != 124 )); then
    echo "ERROR: bounded bridge-wide GRE capture exited with status $capture_status" >&2
    exit 1
fi

capture=$(<"$capture_file")
grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: GRE' <<<"$capture" || {
    echo "ERROR: capture lacks direct spoke1-to-spoke2 outer GRE" >&2
    exit 1
}
grep -qE '10\.0\.0\.12 > 10\.0\.0\.11: GRE' <<<"$capture" || {
    echo "ERROR: capture lacks direct spoke2-to-spoke1 outer GRE" >&2
    exit 1
}
if grep -qE '10\.0\.0\.(11|12) > 10\.0\.0\.1: GRE|10\.0\.0\.1 > 10\.0\.0\.(11|12): GRE' \
        <<<"$capture"; then
    echo "ERROR: seeded service traffic still traversed the hub" >&2
    exit 1
fi

printf '%s\n' "$capture"
echo "PASS: bridge-wide evidence shows direct spoke GRE and no hub-facing leg."
