#!/usr/bin/env bash
# Prove encrypted WireGuard transport at the developer's public interface.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-remote-access-concentrator/lab-lib.sh
source "$lab_dir/lab-lib.sh"
capture_file=$(mktemp -t opnsense-ra-capture.XXXXXX)
capture_pid=

kill_exact_capture() {
    docker exec "$RA_PREFIX-developer" bash -c '
        for command_file in /proc/[0-9]*/cmdline; do
            command=$(tr "\0" " " <"$command_file" 2>/dev/null || true)
            if [[ "$command" == "tcpdump -lnni eth1 -c 4 udp port 51820 "* ]]; then
                pid=${command_file#/proc/}
                pid=${pid%%/*}
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
    ' >/dev/null 2>&1 || true
}

cleanup() {
    if [[ -n "$capture_pid" ]]; then
        kill "$capture_pid" 2>/dev/null || true
    fi
    kill_exact_capture
    rm -f "$capture_file"
}
on_signal() {
    local status=$1
    trap - INT TERM
    exit "$status"
}
trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

ra_require_tools
ra_require_containers
ra_ssh_ready || { echo "ERROR: OPNsense SSH is not ready" >&2; exit 1; }
"$lab_dir/check.sh" >/dev/null \
    || { echo "ERROR: exact healthy state is required before capture" >&2; exit 1; }

timeout 15 docker exec "$RA_PREFIX-developer" \
    timeout 12 tcpdump -lnni eth1 -c 4 'udp port 51820' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 1
for _attempt in 1 2 3; do
    ra_tcp_expect developer 10.70.10.10 8443 corp-application || true
    ra_tcp_expect developer 10.70.10.20 22 jump-host || true
done
if ! wait "$capture_pid"; then
    sed -n '1,12p' "$capture_file"
    echo "ERROR: bounded capture did not collect the required WireGuard packets" >&2
    exit 1
fi
capture_pid=

sed -n '1,12p' "$capture_file"
client_to_server=$(grep -Ec '203\.0\.113\.10\.[0-9]+ > 203\.0\.113\.2\.51820: UDP' "$capture_file" || true)
server_to_client=$(grep -Ec '203\.0\.113\.2\.51820 > 203\.0\.113\.10\.[0-9]+: UDP' "$capture_file" || true)
inner_leaks=$(grep -Ec '10\.(250\.0|70\.10)\.' "$capture_file" || true)
if (( client_to_server > 0 && server_to_client > 0 && inner_leaks == 0 )); then
    echo "PASS: bounded public capture proves bidirectional UDP/51820 with no readable inner addresses."
else
    echo "ERROR: public capture did not prove the required encrypted flow" >&2
    exit 1
fi
