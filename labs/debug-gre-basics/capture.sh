#!/usr/bin/env bash
# Prove the incident's one-way GRE boundary or healthy bidirectional GRE.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/debug-gre-basics/capture.sh fault|healthy' '' \
        'fault: require six duplicated forward GRE requests and no reverse/reply' \
        'healthy: require six duplicated packets in each direction with replies'
}

case ${1:-} in
    fault) mode=fault; state_mode=incident ;;
    healthy) mode=healthy; state_mode=healthy ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 1 )) || { usage >&2; exit 2; }

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=state-lib.sh
source "$LAB_DIR/state-lib.sh"

capture=$(mktemp -t debug-gre-basics.XXXXXX)
capture_pid=
capture_filter='host 203.0.113.1 and host 203.0.113.6 and ip proto 47'

capture_filter_active() {
    debug_gre_node internet 'pgrep -af tcpdump' 2>/dev/null \
        | grep -F -- "$capture_filter" >/dev/null
}

wait_filter_absent() {
    local _attempt
    for _attempt in $(seq 1 20); do
        capture_filter_active || return 0
        sleep 0.1
    done
    return 1
}

start_capture() {
    capture_filter_active && {
        echo 'ERROR: an identical lab-local capture is already active' >&2
        return 1
    }
    # The inner shell owns and reaps its exact tcpdump and sleep children.
    # shellcheck disable=SC2016
    setsid --wait docker exec "$(debug_gre_container internet)" \
        sh -c 'tcpdump_pid=
            sleep_pid=
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
            tcpdump -l -nn -i any "$1" &
            tcpdump_pid=$!
            sleep 7 &
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
            exit "$capture_status"' capture "$capture_filter" \
        >"$capture" 2>&1 &
    capture_pid=$!
}

finish_capture() {
    local status=0
    wait "$capture_pid" || status=$?
    capture_pid=
    if ! wait_filter_absent; then
        echo 'ERROR: packet evidence left its exact tcpdump process active' >&2
        return 1
    fi
    if (( status != 0 )); then
        echo "ERROR: packet evidence capture exited with status $status" >&2
        return 1
    fi
}

cleanup() {
    local status=$? cleanup_status=0
    trap - EXIT
    set +e
    if [[ -n "$capture_pid" ]]; then
        wait "$capture_pid" >/dev/null 2>&1 || true
        capture_pid=
        wait_filter_absent || cleanup_status=1
    fi
    rm -f "$capture"
    (( status == 0 && cleanup_status != 0 )) && status=1
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! debug_gre_verify_state "$state_mode"; then
    echo "ERROR: the topology is not in the exact $mode state" >&2
    exit 1
fi

start_capture
sleep 1
ping_output=$(debug_gre_eos gw-a 'ping 172.16.0.2 repeat 3 timeout 1' || true)
if [[ "$mode" == healthy ]]; then
    grep -qE '(^|, )0% packet loss([[:space:]]|$)|^[[:space:]]*[0-9]+ bytes from ' \
        <<<"$ping_output" || {
        echo 'ERROR: healthy tunnel traffic did not succeed' >&2
        exit 1
    }
else
    if grep -qE '(^|, )0% packet loss([[:space:]]|$)|^[[:space:]]*[0-9]+ bytes from ' \
        <<<"$ping_output"; then
        echo 'ERROR: the fault unexpectedly forwarded reciprocal tunnel traffic' >&2
        exit 1
    fi
fi
finish_capture

forward=$(grep -cE '203\.0\.113\.1 > 203\.0\.113\.6: GREv0' "$capture" || true)
reverse=$(grep -cE '203\.0\.113\.6 > 203\.0\.113\.1: GREv0' "$capture" || true)
requests=$(grep -cE '172\.16\.0\.1 > 172\.16\.0\.2: ICMP echo request' "$capture" || true)
replies=$(grep -cE '172\.16\.0\.2 > 172\.16\.0\.1: ICMP echo reply' "$capture" || true)

sed -n '1,24p' "$capture"
if [[ "$mode" == fault ]]; then
    [[ "$forward:$reverse:$requests:$replies" == '6:0:6:0' ]] || {
        echo "ERROR: expected fault counts 6:0:6:0, observed $forward:$reverse:$requests:$replies" >&2
        exit 1
    }
    echo 'PASS: fault capture proved forward GRE/readable requests with no reverse GRE or replies.'
else
    [[ "$forward:$reverse:$requests:$replies" == '6:6:6:6' ]] || {
        echo "ERROR: expected healthy counts 6:6:6:6, observed $forward:$reverse:$requests:$replies" >&2
        exit 1
    }
    echo 'PASS: healthy capture proved bidirectional GRE with readable requests and replies.'
fi
