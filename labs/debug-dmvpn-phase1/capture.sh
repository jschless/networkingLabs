#!/usr/bin/env bash
# Capture bounded incident ARP evidence or healthy Phase 1 hub transit.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: labs/debug-dmvpn-phase1/capture.sh fault|healthy

fault: correlate failed spoke1 unicast with unanswered WAN resolution while
       NHRP registration stays exact, spoke1 stalls in ExStart, and the
       unaffected spokes retain Full OSPF and their routes.
healthy: prove both hub-facing GRE legs and reject direct spoke-to-spoke GRE.
EOF
}
case ${1:-} in
    fault) mode=fault; state_mode=incident ;;
    healthy) mode=healthy; state_mode=healthy ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 1 )) || { usage >&2; exit 2; }

LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=state-lib.sh
source "$LAB_DIR/state-lib.sh"

capture=$(mktemp -t debug-dmvpn-phase1.XXXXXX)
capture_pid=
if [[ "$mode" == fault ]]; then
    capture_filter='arp and (host 10.0.0.11 or host 10.0.0.254)'
    capture_limit=0
else
    capture_filter='ip proto 47 and ip[33] = 1'
    capture_limit=8
fi

capture_filter_active() {
    debug_dmvpn_node br-wan 'pgrep -af tcpdump' 2>/dev/null | \
        grep -F -- "$capture_filter" >/dev/null
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
    # The inner shell owns and reaps its exact tcpdump and timer children.
    # shellcheck disable=SC2016
    setsid --wait docker exec "$(debug_dmvpn_container br-wan)" \
        sh -c 'tcpdump_pid=
            timer_pid=
            cleanup_inner() {
                inner_status=$?
                trap - 0 1 2 15
                if [ -n "$timer_pid" ]; then kill -TERM "$timer_pid" 2>/dev/null || :; fi
                if [ -n "$tcpdump_pid" ]; then kill -INT "$tcpdump_pid" 2>/dev/null || :; fi
                if [ -n "$timer_pid" ]; then wait "$timer_pid" 2>/dev/null || :; fi
                if [ -n "$tcpdump_pid" ]; then wait "$tcpdump_pid" 2>/dev/null || :; fi
                exit "$inner_status"
            }
            trap cleanup_inner 0
            trap "exit 129" 1
            trap "exit 130" 2
            trap "exit 143" 15
            if [ "$1" -eq 0 ]; then
                tcpdump -l -nn -e -i any "$2" &
            else
                tcpdump -l -nn -e -i any -c "$1" "$2" &
            fi
            tcpdump_pid=$!
            sleep 8 &
            timer_pid=$!
            wait "$timer_pid"
            timer_status=$?
            timer_pid=
            if [ "$timer_status" -ne 0 ]; then exit "$timer_status"; fi
            kill -INT "$tcpdump_pid" 2>/dev/null || :
            wait "$tcpdump_pid"
            capture_status=$?
            tcpdump_pid=
            trap - 0 1 2 15
            exit "$capture_status"' capture "$capture_limit" "$capture_filter" \
        >"$capture" 2>&1 &
    capture_pid=$!
}

finish_capture() {
    local status=0
    wait "$capture_pid" || status=$?
    capture_pid=
    wait_filter_absent || {
        echo 'ERROR: capture left its exact tcpdump process active' >&2
        return 1
    }
    (( status == 0 )) || {
        echo "ERROR: bounded packet capture exited with status $status" >&2
        return 1
    }
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

if ! debug_dmvpn_verify_state "$state_mode"; then
    echo "ERROR: topology is not in exact $state_mode state" >&2
    exit 1
fi

if [[ "$mode" == fault ]]; then
    # Removing only this failed ephemeral neighbor entry makes the evidence
    # deterministic without changing live or saved VyOS configuration.
    debug_dmvpn_node spoke1 \
        'ip neigh del 10.0.0.254 dev eth1 2>/dev/null || true' >/dev/null
fi
start_capture
sleep 1

if [[ "$mode" == fault ]]; then
    if debug_dmvpn_ping spoke1 172.16.0.11 172.16.0.1; then
        echo 'ERROR: fault traffic unexpectedly crossed the overlay' >&2
        exit 1
    fi
else
    debug_dmvpn_ping spoke1 192.168.1.1 192.168.2.1 || {
        echo 'ERROR: healthy source-specific service traffic failed' >&2
        exit 1
    }
fi
finish_capture

sed -n '1,28p' "$capture"
if [[ "$mode" == fault ]]; then
    requests=$(grep -cE 'ethertype ARP \(0x0806\), length [0-9]+: Request who-has 10\.0\.0\.254 tell 10\.0\.0\.11([,[:space:]]|$)' \
        "$capture" || true)
    replies=$(grep -cE 'ethertype ARP \(0x0806\), length [0-9]+: Reply 10\.0\.0\.254 is-at ([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}([,[:space:]]|$)' \
        "$capture" || true)
    (( requests >= 1 )) || {
        echo 'ERROR: incident capture lacks the failed WAN resolution request' >&2
        exit 1
    }
    [[ "$replies" == 0 ]] || {
        echo 'ERROR: the unused WAN target unexpectedly answered ARP' >&2
        exit 1
    }
    debug_dmvpn_nhrp_exact hub incident \
        && debug_dmvpn_ospf_exact hub incident \
        && debug_dmvpn_routes_exact hub incident \
        && debug_dmvpn_routes_exact spoke1 incident || {
        echo 'ERROR: exact incident protocol/route proof changed during capture' >&2
        exit 1
    }
    echo "PASS: $requests unanswered ARP request(s) correlate the failed unicast path while NHRP stays exact, spoke1 stalls in ExStart, and unaffected routes remain healthy."
else
    grep -qE '10\.0\.0\.11 > 10\.0\.0\.1: GRE' "$capture" || {
        echo 'ERROR: healthy capture lacks spoke1-to-hub outer GRE' >&2
        exit 1
    }
    grep -qE '10\.0\.0\.1 > 10\.0\.0\.12: GRE' "$capture" || {
        echo 'ERROR: healthy capture lacks hub-to-spoke2 outer GRE' >&2
        exit 1
    }
    grep -qE '10\.0\.0\.12 > 10\.0\.0\.1: GRE' "$capture" || {
        echo 'ERROR: healthy capture lacks spoke2-to-hub return GRE' >&2
        exit 1
    }
    grep -qE '10\.0\.0\.1 > 10\.0\.0\.11: GRE' "$capture" || {
        echo 'ERROR: healthy capture lacks hub-to-spoke1 return GRE' >&2
        exit 1
    }
    if grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: GRE|10\.0\.0\.12 > 10\.0\.0\.11: GRE' \
        "$capture"; then
        echo 'ERROR: direct spoke-to-spoke GRE bypassed the Phase 1 hub' >&2
        exit 1
    fi
    echo 'PASS: healthy packet evidence shows both hub-facing GRE legs and no direct spoke leg.'
fi
