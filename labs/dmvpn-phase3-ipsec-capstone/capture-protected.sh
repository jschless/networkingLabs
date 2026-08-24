#!/usr/bin/env bash
# Prove the hub-first and direct shortcut phases both use ESP, never raw GRE.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: labs/dmvpn-phase3-ipsec-capstone/capture-protected.sh' '' \
        'Observe a bounded spoke1-to-spoke2 transition bridge-wide: protected' \
        'hub-first forwarding, then protected direct forwarding, with no raw GRE.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3-ipsec-capstone
first=$(mktemp -t dmvpn-capstone-first.XXXXXX)
direct=$(mktemp -t dmvpn-capstone-direct.XXXXXX)
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
    local label=$1 pid=$capture_pid filter=$capture_filter status=0
    wait "$pid" || status=$?
    capture_pid=
    capture_filter=
    if ! wait_filter_absent "$filter"; then
        echo "ERROR: $label capture left its exact tcpdump process active" >&2
        return 1
    fi
    if (( status == 0 )); then return 0; fi
    echo "ERROR: $label capture exited with status $status" >&2
    return 1
}
stop_capture() {
    local pid=${capture_pid:-} filter=${capture_filter:-}
    [[ -n "$pid" ]] || return 0
    # The inner shell owns and reaps its exact tcpdump/sleep children. Waiting
    # here lets ERR/INT/TERM cleanup finish without touching any other process.
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
    rm -f "$first" "$direct"
    (( status == 0 && cleanup_status != 0 )) && status=1
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for node in br-wan spoke1 spoke2 hub; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo 'ERROR: the capstone is not fully deployed' >&2; exit 1;
    }
done
timeout 10 docker exec "$prefix-spoke1" vtysh \
    -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null
sleep 2
initial_fib=$(docker exec "$prefix-spoke1" ip -4 route get 192.168.2.1 \
    from 192.168.1.1 2>/dev/null || true)
grep -qE '^192\.168\.2\.1 from 192\.168\.1\.1 via 172\.16\.0\.1 dev tun0([[:space:]]|$)' \
    <<<"$initial_fib" || {
    echo 'ERROR: the deterministic hub-first FIB was not ready' >&2; exit 1;
}

hub_filter='((host 10.0.0.11 and host 10.0.0.1) or (host 10.0.0.1 and host 10.0.0.12)) and (ip proto 47 or ip proto 50)'
start_capture "$first" 7 "$hub_filter"
sleep 1
timeout 6 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 1 -W 2 \
    192.168.2.1 >/dev/null
finish_capture 'hub-first'
grep -qE '10\.0\.0\.11 > 10\.0\.0\.1: ESP' "$first" || {
    echo 'ERROR: hub-first request did not appear as ESP' >&2; exit 1;
}
if grep -qE '10\.0\.0\.(1|11|12) > 10\.0\.0\.(1|11|12): GRE' "$first"; then
    echo 'ERROR: raw GRE leaked during hub-first forwarding' >&2; exit 1;
fi

direct_ready=false
for _attempt in $(seq 1 35); do
    timeout 5 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 1 -W 1 \
        192.168.2.1 >/dev/null 2>&1 || true
    fib=$(docker exec "$prefix-spoke1" ip -4 route get 192.168.2.1 \
        from 192.168.1.1 2>/dev/null || true)
    if grep -qE '^192\.168\.2\.1 from 192\.168\.1\.1 (via 172\.16\.0\.12 )?dev tun0([[:space:]]|$)' <<<"$fib"; then
        direct_ready=true; break
    fi
    sleep 1
done
[[ "$direct_ready" == true ]] || {
    echo 'ERROR: direct shortcut did not become ready' >&2; exit 1;
}

direct_filter='host 10.0.0.11 and host 10.0.0.12 and (ip proto 47 or ip proto 50)'
start_capture "$direct" 7 "$direct_filter"
sleep 1
timeout 6 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 3 -W 1 \
    192.168.2.1 >/dev/null
finish_capture direct
grep -qE '10\.0\.0\.11 > 10\.0\.0\.12: ESP' "$direct" || {
    echo 'ERROR: direct request did not appear as ESP' >&2; exit 1;
}
grep -qE '10\.0\.0\.12 > 10\.0\.0\.11: ESP' "$direct" || {
    echo 'ERROR: direct reply did not appear as ESP' >&2; exit 1;
}
if grep -qE '10\.0\.0\.(11|12) > 10\.0\.0\.(11|12): GRE' "$direct"; then
    echo 'ERROR: raw GRE leaked during direct forwarding' >&2; exit 1;
fi
echo 'PASS: hub-first and direct Phase 3 forwarding used ESP with zero raw GRE.'
