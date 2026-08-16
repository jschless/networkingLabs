#!/usr/bin/env bash
# Arm the opaque Task 5 endpoint-resolution fault transactionally.
set -Eeuo pipefail

prefix=clab-gre-basics
gateway="$prefix-gw-a"
peer="$prefix-gw-b"
rollback_armed=false

neighbor_full() {
    local device=$1 router_id=$2 state
    state=$(docker exec "$device" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    grep -qE "${router_id}.*[Ff][Uu][Ll][Ll]" <<<"$state"
}

healthy_forwarding() {
    neighbor_full "$gateway" '10\.0\.0\.2' \
        && neighbor_full "$peer" '10\.0\.0\.1' \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 \
            192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 \
            192.168.1.10 >/dev/null 2>&1
}

remove_fault_route() {
    docker exec -i "$gateway" Cli -p 15 >/dev/null <<'EOS'
enable
configure
no ip route 203.0.113.6/32 172.16.0.2
end
EOS
}

rollback_fault() {
    local _attempt

    if ! remove_fault_route; then
        echo "ERROR: rollback could not remove the injected route" >&2
        return 1
    fi

    for _attempt in $(seq 1 75); do
        if healthy_forwarding; then
            echo "Rollback removed the injected route and restored full service." >&2
            return 0
        fi
        sleep 1
    done

    echo "ERROR: rollback removed the route but full service did not recover within the bounded wait" >&2
    return 1
}

rollback_and_exit() {
    local reason=$1 requested_status=$2 rollback_status=0

    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        rollback_fault || rollback_status=$?
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
        echo "ERROR: gre-basics is not fully deployed" >&2
        exit 1
    }
done

# Snapshot and reject a pre-existing fault before this helper owns any change.
route_snapshot=$(docker exec "$gateway" Cli -p 15 -c enable \
    -c 'show running-config section ip route' 2>/dev/null)
if grep -qE '^[[:space:]]*ip route 203\.0\.113\.6/32 172\.16\.0\.2[[:space:]]*$' \
    <<<"$route_snapshot"; then
    echo "ERROR: the scenario route is already present; repair before re-arming" >&2
    exit 1
fi
if ! healthy_forwarding; then
    echo "ERROR: apply and verify the healthy Task 4 state before arming the scenario" >&2
    exit 1
fi

# Arm rollback before mutation so an interruption cannot land in an uncovered
# interval. The rollback removes only the route verified absent above.
rollback_armed=true
docker exec -i "$gateway" Cli -p 15 >/dev/null <<'EOS'
enable
configure
ip route 203.0.113.6/32 172.16.0.2
end
EOS

for _attempt in $(seq 1 60); do
    tunnel_state=$(docker exec "$gateway" Cli -p 15 -c enable \
        -c 'show interfaces Tunnel0' 2>/dev/null || true)
    a_neighbor=$(docker exec "$gateway" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    b_neighbor=$(docker exec "$peer" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    if grep -qiE 'recursive resolution loop|resolved over another tunnel' <<<"$tunnel_state" \
        && ! grep -qE '[Ff][Uu][Ll][Ll]' <<<"$a_neighbor" \
        && ! grep -qE '[Ff][Uu][Ll][Ll]' <<<"$b_neighbor" \
        && ! docker exec "$prefix-host-a" ping -c 1 -W 1 \
            192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$gateway" Cli -p 15 -c enable \
            -c 'ping 203.0.113.2 repeat 1 timeout 1' 2>/dev/null \
            | grep -qE '0% packet loss|bytes from'; then
        rollback_armed=false
        trap - ERR EXIT INT TERM
        echo "Scenario armed. Preserve the symptom and control-plane evidence before diagnosing."
        exit 0
    fi
    sleep 1
done

echo "ERROR: scenario did not reach its bounded failure postcondition" >&2
exit 1
