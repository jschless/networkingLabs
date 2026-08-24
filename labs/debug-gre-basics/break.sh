#!/usr/bin/env bash
# Re-arm the live incident transactionally, preserving the saved startup fault.
set -Eeuo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=state-lib.sh
source "$LAB_DIR/state-lib.sh"

rollback_armed=false
before_a=
before_b=

saved_hash() {
    debug_gre_node "$1" "sha256sum /mnt/flash/startup-config | cut -d ' ' -f 1"
}

set_destination() {
    local destination=$1
    docker exec -i "$(debug_gre_container gw-b)" Cli -p 15 >/dev/null <<EOS
enable
configure
interface Tunnel0
   tunnel destination $destination
end
EOS
}

ping_eos() {
    local node=$1 destination=$2 output
    output=$(debug_gre_eos "$node" "ping $destination repeat 1 timeout 1" || true)
    grep -qE '(^|, )0% packet loss([[:space:]]|$)|^[[:space:]]*[0-9]+ bytes from ' \
        <<<"$output"
}

healthy_forwarding() {
    debug_gre_verify_state healthy >/dev/null 2>&1 \
        && docker exec "$(debug_gre_container host-a)" \
            ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$(debug_gre_container host-b)" \
            ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1
}

rollback_fault() {
    local converged=false
    set_destination 203.0.113.1 || return 1
    for _attempt in $(seq 1 45); do
        if healthy_forwarding; then
            converged=true
            break
        fi
        sleep 1
    done
    [[ "$converged" == true ]] || return 1
    [[ "$(saved_hash gw-a)" == "$before_a" && "$(saved_hash gw-b)" == "$before_b" ]] \
        || return 1
    "$LAB_DIR/check.sh" >/dev/null
}

rollback_and_exit() {
    local reason=$1 requested_status=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        rollback_fault || rollback_status=$?
        if (( rollback_status == 0 )); then
            echo "Transactional rollback restored the healthy state after $reason." >&2
        else
            echo "ERROR: transactional rollback failed after $reason" >&2
        fi
    fi
    (( requested_status == 0 )) && requested_status=1
    exit "$requested_status"
}

on_exit() {
    local status=$1
    if (( status != 0 )); then
        rollback_and_exit EXIT "$status"
    fi
}

trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

if ! "$LAB_DIR/check.sh" >/dev/null; then
    echo 'ERROR: reach the exact healthy state before re-arming the incident' >&2
    exit 1
fi

before_a=$(saved_hash gw-a)
before_b=$(saved_hash gw-b)
rollback_armed=true
set_destination 192.168.1.1

fault_ready=false
for _attempt in $(seq 1 30); do
    if debug_gre_verify_state incident >/dev/null 2>&1 \
        && ping_eos gw-a 203.0.113.6 \
        && ping_eos gw-b 203.0.113.1 \
        && ! ping_eos gw-a 172.16.0.2 \
        && ! ping_eos gw-b 172.16.0.1 \
        && ! docker exec "$(debug_gre_container host-a)" \
            ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && ! docker exec "$(debug_gre_container host-b)" \
            ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1; then
        fault_ready=true
        break
    fi
    sleep 1
done

[[ "$fault_ready" == true ]] || {
    echo 'ERROR: the incident did not reach its exact bounded failure boundary' >&2
    exit 1
}
[[ "$(saved_hash gw-a)" == "$before_a" && "$(saved_hash gw-b)" == "$before_b" ]] || {
    echo 'ERROR: a saved startup configuration changed while re-arming' >&2
    exit 1
}

rollback_armed=false
trap - ERR EXIT INT TERM
echo 'Incident re-armed: preserve endpoint, interface-detail, and packet evidence before repair.'
