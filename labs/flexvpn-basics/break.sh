#!/usr/bin/env bash
# Transactionally arm a live-only spoke1 VTI-key/XFRM-mark mismatch.
set -Eeuo pipefail
prefix=clab-flexvpn-basics
lab_dir=$(cd "$(dirname "$0")" && pwd)
rollback_armed=false
b_conf_before=

healthy_basic() {
    docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.3.10 >/dev/null 2>&1
}
restore_fault() {
    docker exec "$prefix-gw-b" bash /opt/flexvpn-basics/set-vti-key.sh healthy
    for _attempt in $(seq 1 20); do
        if healthy_basic \
            && [[ "$(docker exec "$prefix-gw-b" sha256sum /etc/ipsec.conf /etc/ipsec.secrets)" == "$b_conf_before" ]] \
            && "$lab_dir/check.sh" >/dev/null; then
            echo "Rollback restored key 1, unchanged IKE files, and exact health." >&2
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
    [[ "$rollback_armed" != true ]] || restore_fault || rollback_status=$?
    (( rollback_status == 0 )) || echo "ERROR: transactional rollback failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

for node in gw-a gw-b gw-c host-a host-b host-c internet; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: flexvpn-basics is not fully deployed" >&2; exit 1;
    }
done
"$lab_dir/check.sh" >/dev/null || { echo "ERROR: exact healthy state must pass before arming the scenario" >&2; exit 1; }
b_conf_before=$(docker exec "$prefix-gw-b" sha256sum /etc/ipsec.conf /etc/ipsec.secrets)
rollback_armed=true
docker exec "$prefix-gw-b" bash /opt/flexvpn-basics/set-vti-key.sh fault

# Optional bounded hold lets engineering tests signal the mutation window.
hold=${FLEXVPN_BREAK_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo "ERROR: test hold must be an integer" >&2; exit 2; }
(( hold == 0 )) || sleep "$hold"

faulted=false
for _attempt in $(seq 1 20); do
    b_status=$(docker exec "$prefix-gw-b" ipsec status 2>/dev/null || true)
    c_status=$(docker exec "$prefix-gw-c" ipsec status 2>/dev/null || true)
    b_tunnel=$(docker exec "$prefix-gw-b" ip -d tunnel show vti0 2>/dev/null || true)
    b_state=$(docker exec "$prefix-gw-b" ip -s xfrm state 2>/dev/null || true)
    if [[ "$(grep -c 'ESTABLISHED' <<<"$b_status" || true)" == 1 ]] \
        && [[ "$(grep -c 'INSTALLED, TUNNEL' <<<"$b_status" || true)" == 1 ]] \
        && [[ "$(grep -c 'ESTABLISHED' <<<"$c_status" || true)" == 1 ]] \
        && grep -qE 'key 9$' <<<"$b_tunnel" \
        && [[ "$(grep -Ec 'mark 0x1/0xffffffff' <<<"$b_state" || true)" == 1 ]] \
        && ! docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && ! docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.3.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-c" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && docker exec "$prefix-gw-b" ping -c 1 -W 1 203.0.113.1 >/dev/null 2>&1 \
        && [[ "$(docker exec "$prefix-gw-b" sha256sum /etc/ipsec.conf /etc/ipsec.secrets)" == "$b_conf_before" ]]; then
        faulted=true; break
    fi
    sleep 1
done
[[ "$faulted" == true ]] || { echo "ERROR: scenario did not reach every bounded postcondition" >&2; exit 1; }
rollback_armed=false
trap - ERR EXIT INT TERM
echo "Scenario armed: spoke1 IKE/CHILD stay up with XFRM mark 1, but VTI key 9 breaks only spoke1 forwarding."
