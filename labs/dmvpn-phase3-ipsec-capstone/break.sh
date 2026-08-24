#!/usr/bin/env bash
# Arm the opaque live-only confidentiality fault transactionally.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3-ipsec-capstone/break.sh' \
        '' \
        'Require exact health, arm one opaque live-only pair-protection fault,' \
        'and prove its causal privacy, routing, isolation, and persistence bounds.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3-ipsec-capstone
lab_dir=$(cd "$(dirname "$0")" && pwd)
rollback_armed=false
active_child_pid=
declare -A saved_before

stop_active_child() {
    local pid=${active_child_pid:-} attempt
    [[ -n "$pid" ]] || return 0
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill -TERM -- "-$pid" >/dev/null 2>&1 || true
        for attempt in $(seq 1 20); do kill -0 "$pid" >/dev/null 2>&1 || break; sleep 0.1; done
        kill -KILL -- "-$pid" >/dev/null 2>&1 || true
    fi
    wait "$pid" >/dev/null 2>&1 || true
    active_child_pid=
}
run_interruptible() {
    local status=0
    setsid --wait "$@" &
    active_child_pid=$!
    wait "$active_child_pid" || status=$?
    active_child_pid=
    return "$status"
}
saved_sha() { docker exec "$prefix-$1" sha256sum /config/config.boot 2>/dev/null | awk '{print $1}'; }
live_config() {
    docker exec "$prefix-$1" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true
}
shortcut_rows() {
    awk '
        {
            row=$0
            sub(/^[[:space:]]+/,"",row)
            sub(/[[:space:]]+$/,"",row)
            gsub(/[[:space:]]+/," ",row)
        }
        row=="" { next }
        tolower(row) ~ /^(type|prefix)([[:space:]]+(type|prefix|state|via|identity|nbma|interface))+$/ { next }
        row ~ /^[-=]+([[:space:]]+[-=]+)*$/ { next }
        tolower(row) ~ /^%?[[:space:]]*no[[:space:]]+/ { next }
        { print row }
    '
}
restore_pair() {
    local deadline=$((SECONDS + 75)) complete=false attempt=0 status1=1 status2=1
    while (( SECONDS < deadline )); do
        ((attempt += 1))
        timeout 25 docker exec "$prefix-spoke2" su - admin -c \
            '/bin/vbash /opt/dmvpn-capstone/restore-pair.sh' >/dev/null 2>&1
        status2=$?
        timeout 25 docker exec "$prefix-spoke1" su - admin -c \
            '/bin/vbash /opt/dmvpn-capstone/restore-pair.sh' >/dev/null 2>&1
        status1=$?
        c1=$(live_config spoke1); c2=$(live_config spoke2)
        if (( status1 == 0 && status2 == 0 )) \
            && grep -q '^set vpn ipsec site-to-site peer spoke2 remote-address ' <<<"$c1" \
            && grep -q '^set vpn ipsec site-to-site peer spoke1 remote-address ' <<<"$c2"; then
            complete=true; break
        fi
        sleep 2
    done
    [[ "$complete" == true ]] || {
        echo "ERROR: rollback could not restore the exact live definition after $attempt attempts" >&2
        return 1
    }
    docker exec "$prefix-spoke1" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'reset vpn ipsec site-to-site peer spoke2 tunnel 1'\"" \
        >/dev/null 2>&1 || true
    timeout 90 "$lab_dir/seed-shortcuts.sh" >/dev/null
    for router in hub spoke1 spoke2 spoke3; do
        [[ "$(saved_sha "$router")" == "${saved_before[$router]}" ]] || {
            echo 'ERROR: rollback changed saved learner state' >&2; return 1;
        }
    done
    timeout 240 "$lab_dir/check.sh" >/dev/null || {
        echo 'ERROR: rollback restored the pair but not complete checked health' >&2; return 1;
    }
    echo 'Transactional rollback restored exact health and unchanged saved state.' >&2
}
rollback_and_exit() {
    local reason=$1 requested=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    trap '' INT TERM
    set +e
    stop_active_child
    if [[ "$rollback_armed" == true ]]; then restore_pair || rollback_status=$?; fi
    (( rollback_status == 0 )) || echo "ERROR: rollback failed after $reason" >&2
    (( requested == 0 )) && requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

for node in br-wan ca hub spoke1 spoke2 spoke3; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo 'ERROR: the capstone is not fully deployed' >&2; exit 1;
    }
done
for router in hub spoke1 spoke2 spoke3; do saved_before[$router]=$(saved_sha "$router"); done
if ! run_interruptible timeout 240 "$lab_dir/check.sh"; then
    echo 'ERROR: complete healthy state must pass before arming the scenario' >&2
    exit 1
fi

# Arm rollback before either live-only mutation.
rollback_armed=true
run_interruptible timeout 30 docker exec "$prefix-spoke2" su - admin -c \
    '/bin/vbash /opt/dmvpn-capstone/remove-pair.sh' >/dev/null
run_interruptible timeout 30 docker exec "$prefix-spoke1" su - admin -c \
    '/bin/vbash /opt/dmvpn-capstone/remove-pair.sh' >/dev/null
run_interruptible timeout 10 docker exec "$prefix-spoke1" vtysh \
    -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null

fault_ready=false
for _attempt in $(seq 1 45); do
    # Drive the target shortcut while leaving every control-plane feature intact.
    timeout 5 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 2 -W 1 \
        192.168.2.1 >/dev/null 2>&1 || true
    c1=$(live_config spoke1); c2=$(live_config spoke2)
    s1=$(docker exec "$prefix-spoke1" /usr/bin/vyos-config-to-commands /config/config.boot 2>/dev/null || true)
    s2=$(docker exec "$prefix-spoke2" /usr/bin/vyos-config-to-commands /config/config.boot 2>/dev/null || true)
    hub_neighbors=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    shortcut=$(docker exec "$prefix-spoke1" vtysh -c 'show ip nhrp shortcut' 2>/dev/null || true)
    # Without a live x509 peer, current VyOS retains the exact routing row but
    # has no peer identity with which to decorate a fourth field.
    fault_shortcuts=$(shortcut_rows <<<"$shortcut")
    fib=$(docker exec "$prefix-spoke1" ip -4 route get 192.168.2.1 from 192.168.1.1 2>/dev/null || true)
    pair_policy_1=$(docker exec "$prefix-spoke1" ip -s xfrm policy 2>/dev/null | \
        grep -Ec '^src 10\.0\.0\.(11|12)/32 dst 10\.0\.0\.(11|12)/32 proto gre' || true)
    pair_policy_2=$(docker exec "$prefix-spoke2" ip -s xfrm policy 2>/dev/null | \
        grep -Ec '^src 10\.0\.0\.(11|12)/32 dst 10\.0\.0\.(11|12)/32 proto gre' || true)
    saved_ok=true
    for router in hub spoke1 spoke2 spoke3; do
        [[ "$(saved_sha "$router")" == "${saved_before[$router]}" ]] || saved_ok=false
    done
    if ! grep -q '^set vpn ipsec site-to-site peer spoke2 ' <<<"$c1" \
        && ! grep -q '^set vpn ipsec site-to-site peer spoke1 ' <<<"$c2" \
        && grep -q '^set vpn ipsec site-to-site peer spoke2 ' <<<"$s1" \
        && grep -q '^set vpn ipsec site-to-site peer spoke1 ' <<<"$s2" \
        && [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_neighbors" || true)" == 3 ]] \
        && [[ "$(grep -Ec '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.1[123][[:space:]]' <<<"$hub_nhrp" || true)" == 3 ]] \
        && [[ "$fault_shortcuts" == 'dynamic 192.168.2.0/24 172.16.0.12' ]] \
        && grep -qE '^192\.168\.2\.1 from 192\.168\.1\.1 (via 172\.16\.0\.12 )?dev tun0([[:space:]]|$)' <<<"$fib" \
        && [[ "$pair_policy_1" == 0 && "$pair_policy_2" == 0 ]] \
        && [[ "$saved_ok" == true ]] \
        && timeout 5 docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 1 -W 1 192.168.2.1 >/dev/null 2>&1 \
        && timeout 5 docker exec "$prefix-spoke2" ping -I 192.168.2.1 -c 1 -W 1 192.168.3.1 >/dev/null 2>&1 \
        && timeout 20 docker exec "$prefix-ca" /opt/dmvpn-pki/validate-pki.sh spoke1 >/dev/null 2>&1; then
        fault_ready=true; break
    fi
    sleep 1
done
[[ "$fault_ready" == true ]] || {
    echo 'ERROR: the scenario did not reach every bounded causal postcondition' >&2
    exit 1
}
if run_interruptible timeout 240 "$lab_dir/check.sh" >/dev/null 2>&1; then
    echo 'ERROR: the exact healthy checker accepted the armed fault' >&2
    exit 1
fi
run_interruptible timeout 30 "$lab_dir/capture-leak.sh" >/dev/null
run_interruptible timeout 30 "$lab_dir/capture-unrelated-protected.sh" >/dev/null

rollback_armed=false
trap - ERR EXIT INT TERM
echo 'Scenario armed: target reachability and all routing/PKI state survive, one direct path loses confidentiality, and an unrelated direct path remains protected.'
echo 'The fault is live-only and opaque; preserve evidence before diagnosing it.'
