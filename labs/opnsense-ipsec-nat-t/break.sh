#!/usr/bin/env bash
# Transactionally arm an opaque UDP/4500 forwarding fault at the NAT boundary.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-ipsec-nat-t/lab-lib.sh
source "$lab_dir/lab-lib.sh"
rollback_armed=false
hold_pid=

restore_healthy() {
    natt_delete_fault_rules
    natt_restart_ipsec
    for _attempt in $(seq 1 45); do
        if natt_protected_ready && "$lab_dir/check.sh" >/dev/null; then
            echo "Rollback removed the boundary fault and restored exact health." >&2
            return 0
        fi
        sleep 1
    done
    echo "ERROR: rollback did not restore exact healthy state" >&2
    return 1
}

rollback_and_exit() {
    local reason=$1 requested=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then
        kill "$hold_pid" 2>/dev/null || true
        wait "$hold_pid" 2>/dev/null || true
        hold_pid=
    fi
    [[ "$rollback_armed" != true ]] || restore_healthy || rollback_status=1
    (( rollback_status == 0 )) || echo "ERROR: transactional rollback failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

natt_require_tools
natt_require_containers
natt_ssh_ready "$NATT_HQ_PORT" && natt_ssh_ready "$NATT_BRANCH_PORT" \
    || { echo "ERROR: both OPNsense VMs must be ready" >&2; exit 1; }

# A repeated invocation first returns the exact two-rule fault to known healthy
# state, then re-arms it. This prevents duplicates even after a long DPD cycle.
if (( $(natt_fault_count) > 0 )); then
    rollback_armed=true
    natt_delete_fault_rules
    natt_restart_ipsec
    normalized=false
    for _attempt in $(seq 1 45); do
        if natt_protected_ready && "$lab_dir/check.sh" >/dev/null; then
            normalized=true
            break
        fi
        sleep 1
    done
    [[ "$normalized" == true ]] \
        || { echo "ERROR: existing fault could not be normalized safely" >&2; exit 1; }
else
    "$lab_dir/check.sh" >/dev/null \
        || { echo "ERROR: exact healthy state must pass before arming the scenario" >&2; exit 1; }
    rollback_armed=true
fi

nat_node="$NATT_PREFIX-nat-cpe"
docker exec "$nat_node" iptables -I FORWARD 1 -p udp --sport 4500 \
    -m comment --comment natt-lab-fault -j DROP
docker exec "$nat_node" iptables -I FORWARD 1 -p udp --dport 4500 \
    -m comment --comment natt-lab-fault -j DROP

hold=${NATT_BREAK_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo "ERROR: test hold must be an integer" >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi

faulted=false
for _attempt in $(seq 1 12); do
    hq_status=$(natt_ssh "$NATT_HQ_PORT" 'configctl ipsec list status' 2>/dev/null || true)
    branch_status=$(natt_ssh "$NATT_BRANCH_PORT" 'configctl ipsec list status' 2>/dev/null || true)
    if [[ "$(natt_fault_count)" == 2 ]] \
        && grep -qE '"state"[[:space:]]*:[[:space:]]*"ESTABLISHED"' <<<"$hq_status" \
        && grep -qE '"state"[[:space:]]*:[[:space:]]*"ESTABLISHED"' <<<"$branch_status" \
        && ! docker exec "$NATT_PREFIX-hq-host" ping -c 1 -W 1 10.20.1.10 >/dev/null 2>&1 \
        && ! docker exec "$NATT_PREFIX-branch-host" ping -c 1 -W 1 10.10.1.10 >/dev/null 2>&1 \
        && natt_ssh "$NATT_BRANCH_PORT" 'ping -c 1 -W 2000 198.51.100.2' >/dev/null 2>&1; then
        faulted=true
        break
    fi
    sleep 1
done
[[ "$faulted" == true ]] \
    || { echo "ERROR: scenario did not reach every bounded postcondition" >&2; exit 1; }

rollback_armed=false
trap - ERR EXIT INT TERM
echo "Scenario armed: protected traffic is down while peer SAs and remote public underlay reachability remain available."
