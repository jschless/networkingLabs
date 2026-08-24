#!/usr/bin/env bash
# During the armed pair fault, require direct raw GRE with readable inner ICMP.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: labs/dmvpn-phase3-ipsec-capstone/capture-leak.sh' '' \
        'Capture the armed spoke1-to-spoke2 fault bridge-wide and require raw' \
        'direct GRE/readable inner ICMP with no direct ESP.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3-ipsec-capstone
capture=$(mktemp -t dmvpn-capstone-leak.XXXXXX)
capture_pid=
capture_filter=
capture_filter_active() {
    docker exec "$prefix-br-wan" pgrep -af tcpdump 2>/dev/null | grep -F -- "$1" >/dev/null
}
wait_filter_absent() {
    local filter=$1 attempt
    for ((attempt = 0; attempt < 20; attempt++)); do
        capture_filter_active "$filter" || return 0
        sleep 0.1
    done
    return 1
}
start_capture() {
    local output=$1 duration=$2 filter=$3
    if capture_filter_active "$filter"; then
        echo 'ERROR: an identical lab-local capture is already active' >&2
        return 1
    fi
    capture_filter=$filter
    # Positional expansion is intentionally deferred to the inner POSIX shell,
    # which owns and reaps both of its exact children.
    # shellcheck disable=SC2016
    setsid --wait docker exec "$prefix-br-wan" \
        sh -c 'tcpdump_pid=
            sleep_pid=
            # cleanup_inner is invoked indirectly by the EXIT trap.
            # shellcheck disable=SC2329
            cleanup_inner() {
                inner_status=$?
                trap - 0 1 2 15
                if [ -n "$sleep_pid" ]; then kill -TERM "$sleep_pid" 2>/dev/null || :; fi
                if [ -n "$tcpdump_pid" ]; then kill -INT "$tcpdump_pid" 2>/dev/null || :; fi
                if [ -n "$sleep_pid" ]; then wait "$sleep_pid" 2>/dev/null || :; fi
                if [ -n "$tcpdump_pid" ]; then wait "$tcpdump_pid" 2>/dev/null || :; fi
                exit "$inner_status"
            }
            trap cleanup_inner 0
            trap "exit 129" 1
            trap "exit 130" 2
            trap "exit 143" 15
            tcpdump -l -nn -i any "$2" &
            tcpdump_pid=$!
            sleep "$1" &
            sleep_pid=$!
            wait "$sleep_pid"
            sleep_status=$?
            sleep_pid=
            if [ "$sleep_status" -ne 0 ]; then exit "$sleep_status"; fi
            kill -INT "$tcpdump_pid" 2>/dev/null || :
            wait "$tcpdump_pid"
            capture_status=$?
            tcpdump_pid=
            trap - 0 1 2 15
            exit "$capture_status"' capture "$duration" "$filter" \
        >"$output" 2>&1 &
    capture_pid=$!
}
finish_capture() {
    local pid=$capture_pid filter=$capture_filter status=0
    wait "$pid" || status=$?
    capture_pid=
    capture_filter=
    if ! wait_filter_absent "$filter"; then
        echo 'ERROR: leak capture left its exact tcpdump process active' >&2
        return 1
    fi
    if (( status == 0 )); then return 0; fi
    echo "ERROR: leak capture exited with status $status" >&2
    return 1
}
stop_capture() {
    local pid=${capture_pid:-} filter=${capture_filter:-}
    [[ -n "$pid" ]] || return 0
    # The inner shell owns and reaps its exact tcpdump/sleep children.
    wait "$pid" >/dev/null 2>&1 || true
    capture_pid=
    capture_filter=
    if ! wait_filter_absent "$filter"; then
        echo 'ERROR: cleanup found the exact lab-local tcpdump still active' >&2
        return 1
    fi
}
cleanup() {
    local status=$? cleanup_status=0
    trap - EXIT
    set +e
    stop_capture || cleanup_status=1
    rm -f "$capture"
    (( status == 0 && cleanup_status != 0 )) && status=1
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

leak_filter='host 10.0.0.11 and host 10.0.0.12 and (ip proto 47 or ip proto 50)'
start_capture "$capture" 8 "$leak_filter"
sleep 1
timeout 6 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 3 -W 1 \
    192.168.2.1 >/dev/null
finish_capture
grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: GRE' "$capture" || {
    echo 'ERROR: direct raw GRE request was not observed' >&2; exit 1;
}
grep -qE '192\.168\.1\.1 > 192\.168\.2\.1: ICMP echo request' "$capture" || {
    echo 'ERROR: readable inner service ICMP was not observed' >&2; exit 1;
}
if grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: ESP|10\.0\.0\.12 > 10\.0\.0\.11: ESP' "$capture"; then
    echo 'ERROR: direct ESP unexpectedly remains during the pair fault' >&2; exit 1;
fi
echo 'PASS: the armed direct path leaks raw GRE and readable inner ICMP.'
