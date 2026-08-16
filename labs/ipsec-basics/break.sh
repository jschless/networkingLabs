#!/usr/bin/env bash
# Arm the opaque Task 4 IKE negotiation fault transactionally.
set -Eeuo pipefail

prefix=clab-ipsec-basics
lab_dir=$(cd "$(dirname "$0")" && pwd)
gateway="$prefix-gw-a"
peer="$prefix-gw-b"
rollback_armed=false
saved_before=

ike_output() {
    docker exec "$1" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ike sa'\"" 2>/dev/null || true
}

child_output() {
    docker exec "$1" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ipsec sa'\"" 2>/dev/null || true
}

live_peer_config() {
    docker exec "$peer" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true
}

reset_initiator() {
    docker exec "$gateway" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'reset vpn ipsec site-to-site peer GW-B'\"" \
        >/dev/null 2>&1 || true
}

public_ping() {
    local device=$1 destination=$2 output
    output=$(docker exec "$device" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'ping $destination count 1'\"" \
        2>/dev/null || true)
    grep -qE '0% packet loss|bytes from' <<<"$output"
}

healthy() {
    local a_ike b_ike a_child b_child
    a_ike=$(ike_output "$gateway")
    b_ike=$(ike_output "$peer")
    a_child=$(child_output "$gateway")
    b_child=$(child_output "$peer")
    grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$a_ike" \
        && grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$b_ike" \
        && grep -qE '^GW-B-tunnel-1[[:space:]]+up[[:space:]]' <<<"$a_child" \
        && grep -qE '^GW-A-tunnel-1[[:space:]]+up[[:space:]]' <<<"$b_child" \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1
}

restore_fault() {
    local _attempt current_saved converged=false
    if ! docker exec "$peer" su - admin -c \
        '/bin/vbash /opt/ipsec-basics/restore-hash.sh' >/dev/null; then
        echo "ERROR: rollback could not restore the live IKE hash" >&2
        return 1
    fi
    reset_initiator
    for _attempt in $(seq 1 45); do
        current_saved=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')
        if healthy && [[ "$current_saved" == "$saved_before" ]]; then
            converged=true
            break
        fi
        sleep 1
    done
    if [[ "$converged" != true ]]; then
        echo "ERROR: rollback did not restore local service and the saved checksum within the bounded wait" >&2
        return 1
    fi
    if ! "$lab_dir/check.sh"; then
        echo "ERROR: rollback restored basic service, but the full healthy-state checker failed" >&2
        return 1
    fi
    echo "Rollback restored the live IKE hash, unchanged saved state, and full checked service." >&2
    return 0
}

rollback_and_exit() {
    local reason=$1 requested_status=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        restore_fault || rollback_status=$?
        if (( rollback_status != 0 )); then
            echo "ERROR: transactional rollback failed after $reason" >&2
        else
            echo "Transactional rollback completed after $reason" >&2
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

for device in "$gateway" "$peer" "$prefix-host-a" "$prefix-host-b"; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$device" 2>/dev/null)" == true ]] || {
        echo "ERROR: ipsec-basics is not fully deployed" >&2
        exit 1
    }
done

saved_before=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')
peer_config=$(live_peer_config)
if ! grep -qE "^set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash '?sha256'?$" \
    <<<"$peer_config" \
    || grep -qE "^set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash '?sha512'?$" \
        <<<"$peer_config"; then
    echo "ERROR: the scenario fault already exists or the expected healthy hash is absent" >&2
    exit 1
fi
if ! healthy; then
    echo "ERROR: apply and verify the healthy Task 3 state before arming the scenario" >&2
    exit 1
fi
if ! "$lab_dir/check.sh"; then
    echo "ERROR: the complete live and saved healthy state must pass check.sh before arming the scenario" >&2
    exit 1
fi

fault_started=$(date +%s)
rollback_armed=true
docker exec "$peer" su - admin -c \
    '/bin/vbash /opt/ipsec-basics/inject-fault.sh' >/dev/null
reset_initiator

for _attempt in $(seq 1 45); do
    a_ike=$(ike_output "$gateway")
    b_ike=$(ike_output "$peer")
    a_child=$(child_output "$gateway")
    b_child=$(child_output "$peer")
    peer_config=$(live_peer_config)
    current_saved=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')
    fault_logs=$(docker exec "$gateway" journalctl --no-pager \
        --since "@$fault_started" 2>/dev/null || true)
    if ! grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$a_ike" \
        && ! grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$b_ike" \
        && ! grep -qE '^GW-B-tunnel-1[[:space:]]+up[[:space:]]' <<<"$a_child" \
        && ! grep -qE '^GW-A-tunnel-1[[:space:]]+up[[:space:]]' <<<"$b_child" \
        && ! docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && ! docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && public_ping "$gateway" 203.0.113.6 \
        && public_ping "$peer" 203.0.113.1 \
        && grep -qE "^set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash '?sha512'?$" \
            <<<"$peer_config" \
        && grep -q 'NO_PROPOSAL_CHOSEN' <<<"$fault_logs" \
        && [[ "$current_saved" == "$saved_before" ]]; then
        rollback_armed=false
        trap - ERR EXIT INT TERM
        echo "Scenario armed. Preserve SA, underlay, and log evidence before diagnosing."
        exit 0
    fi
    sleep 1
done

echo "ERROR: scenario did not reach its bounded failure postcondition" >&2
exit 1
